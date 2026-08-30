/// `annotate` 子命令：对已有题面集合做逐级求解标注。
///
/// 输入：`generate`（或 `annotate`）产出的集合 JSON（题面 + 终局解）。
/// 输出：标注集合 JSON（难度 + 技巧序列 + 完整解题脚本 + 可视化数据）。
/// 标注算法 100% 复用 `sudoku_core`（[annotateOne] 编排）。
library;

import 'dart:isolate';

import 'package:sudoku_core/sudoku_core.dart';

import '../config/cli_config.dart';
import '../io/json_writer.dart';
import '../model/annotated_puzzle.dart';
import '../model/puzzle_collection.dart';
import '../pipeline/generation_pipeline.dart';
import 'command_base.dart';

/// 标注命令。
class AnnotateCommand extends SudokuCommand {
  /// 构造命令。
  AnnotateCommand(super.reporter) {
    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help: '输入集合 JSON 路径（generate 产物，必填）',
      )
      ..addOption(
        'max-attempts',
        help: '未使用；保留以对齐命令家族（标注无尝试预算概念）',
        hide: true,
      );
  }

  @override
  String get name => 'annotate';

  @override
  String get description =>
      '逐级求解标注：难度 + 技巧序列 + 解题脚本 + 可视化数据';

  @override
  Future<Object?> run() async {
    final String? rawInput = argResults!['input'] as String?;
    if (rawInput == null || rawInput.isEmpty) {
      throw UsageException('--input 必填（generate 产出的集合 JSON）', usage);
    }
    final String inputPath = resolvePath(rawInput);
    final ProfileSpec profile = profileValue();
    final int concurrency = concurrencyValue();

    final Map<String, Object?> root = JsonWriter.readJsonMap(inputPath);
    final ParsedCollection collection = PuzzleCollection.decode(root);
    reporter.section(
      'annotate：${collection.puzzles.length} 道，profile=${profile.name}'
      '（规则集 ${profile.ruleSet.length} 项），并发 $concurrency',
    );

    final Stopwatch stopwatch = Stopwatch()..start();
    final List<AnnotatedPuzzle> annotated = await _annotateAll(
      collection.puzzles,
      ruleSet: profile.ruleSet,
      concurrency: concurrency,
    );
    final int skipped = collection.puzzles.length - annotated.length;
    final int elapsedMs = stopwatch.elapsedMilliseconds;

    reporter.info('标注完成：${annotated.length}/${collection.puzzles.length} 道'
        '（跳过 $skipped 道：规则集内不可解）'
        '，耗时 $elapsedMs ms');

    if (skipped > 0) {
      reporter.warn('存在规则集内不可解的题（超出 ${profile.name} 能力），'
          '如需发布建议改用 t2 或调低提示数。');
    }

    final String out = outValue() ?? '';
    if (out.isNotEmpty) {
      final String target = resolvePath(out);
      JsonWriter.writeJsonAuto(
        target,
        json: PuzzleCollection.encode(
          kind: CollectionKind.annotated,
          profile: profile.name,
          seed: collection.seed,
          concurrency: concurrency,
          puzzles: annotated,
        ),
      );
      reporter.info('已写出：$target（${annotated.length} 道）');
    } else {
      reporter.info('提示：加 --out <file.json> 落盘供 filter/export-level 复用。');
    }
    return 0;
  }

  /// 分片并行标注；返回标注成功（规则集内可解）的题目列表。
  Future<List<AnnotatedPuzzle>> _annotateAll(
    List<AnnotatedPuzzle> puzzles, {
    required RuleSet ruleSet,
    required int concurrency,
  }) async {
    if (puzzles.isEmpty) {
      return <AnnotatedPuzzle>[];
    }
    final int slices =
        concurrency <= 1 ? 1 : (concurrency < puzzles.length ? concurrency : puzzles.length);
    final int perSlice = (puzzles.length / slices).ceil();
    final List<Map<String, Object?>> requests = <Map<String, Object?>>[
      for (int i = 0; i < slices; i++)
        <String, Object?>{
          'ruleSetMode': _modeIdOf(ruleSet),
          'customIds': ruleSet.toIdList(),
          'puzzles': <Map<String, Object?>>[
            for (final AnnotatedPuzzle puzzle
                in puzzles.sublist(i * perSlice, _end(puzzles.length, i, perSlice)))
              puzzle.toJson(),
          ],
        },
    ];

    final List<List<Map<String, Object?>>> rawResults;
    if (slices == 1) {
      rawResults = <List<Map<String, Object?>>>[runAnnotateSlice(requests.single)];
    } else {
      rawResults = await Future.wait(<Future<List<Map<String, Object?>>>>[
        for (final Map<String, Object?> request in requests)
          Isolate.run<List<Map<String, Object?>>>(
              () => runAnnotateSlice(request)),
      ]);
    }

    return <AnnotatedPuzzle>[
      for (final List<Map<String, Object?>> slice in rawResults)
        for (final Map<String, Object?> json in slice)
          AnnotatedPuzzle.fromJson(json),
    ];
  }

  static int _end(int total, int slice, int perSlice) {
    final int end = (slice + 1) * perSlice;
    return end < total ? end : total;
  }

  static String _modeIdOf(RuleSet ruleSet) {
    if (ruleSet == RuleSet.t1()) {
      return 't1';
    }
    if (ruleSet == RuleSet.t2()) {
      return 't2';
    }
    return 'custom';
  }
}

/// 标注片入口（Isolate）：逐题 [annotateOne]，返回标注成功题的 JSON 列表。
List<Map<String, Object?>> runAnnotateSlice(Map<String, Object?> request) {
  final String modeId = request['ruleSetMode']! as String;
  final List<String> customIds = <String>[
    for (final Object? v in (request['customIds'] as List<Object?>?) ??
        const <Object?>[])
      v! as String,
  ];
  final RuleSet ruleSet = switch (modeId) {
    't1' => RuleSet.t1(),
    't2' => RuleSet.t2(),
    _ => RuleSet.fromIdList(customIds),
  };

  final List<Map<String, Object?>> result = <Map<String, Object?>>[];
  for (final Object? item
      in (request['puzzles'] as List<Object?>?) ?? const <Object?>[]) {
    final AnnotatedPuzzle input =
        AnnotatedPuzzle.fromJson(item! as Map<String, Object?>);
    final Puzzle puzzle = Puzzle(
      given: BoardCodec.decodeValues(input.puzzle81),
      solution: BoardCodec.decodeValues(input.solution81),
    );
    final AnnotatedPuzzle? annotated =
        annotateOne(puzzle: puzzle, seed: input.seed, ruleSet: ruleSet);
    if (annotated != null) {
      result.add(annotated.toJson());
    }
  }
  return result;
}
