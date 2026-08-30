/// `generate` 子命令：批量生成唯一解盘面（可选顺带标注）。
///
/// 内部走 [GenerationPipeline]（生成 → 标注 → 筛选 → 去重），
/// 全部算法复用 `sudoku_core`；输出命中率报表，可落盘标注集合 JSON。
library;

import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

import '../config/cli_config.dart';
import '../config/default_profiles.dart';
import '../io/json_writer.dart';
import '../model/annotated_puzzle.dart';
import '../model/puzzle_collection.dart';
import '../pipeline/filter_spec.dart';
import '../pipeline/generation_pipeline.dart';
import 'command_base.dart';

/// 批量生成命令。
class GenerateCommand extends SudokuCommand {
  /// 构造命令。
  GenerateCommand(super.reporter) {
    argParser
      ..addOption(
        'count',
        abbr: 'c',
        help: '目标收录数量（必填）',
      )
      ..addOption(
        'target-givens',
        help: '挖洞目标提示数（默认按难度档取 profile 内建默认值）',
      )
      ..addOption(
        'max-attempts',
        help: '全局生成尝试预算上限（默认取 profile 的 maxAttempts）',
      )
      ..addFlag(
        'annotate',
        help: '顺带做逐级求解标注（难度 + 技巧序列 + 脚本）',
        defaultsTo: false,
      );
    addFilterOptions();
  }

  @override
  String get name => 'generate';

  @override
  String get description =>
      '批量生成唯一解盘面（可选逐级标注；输出命中率报表）';

  @override
  Future<Object?> run() async {
    final int? count = int.tryParse(argResults!['count'] as String? ?? '');
    if (count == null || count < 1) {
      throw UsageException('--count 必须是 ≥1 的整数', usage);
    }
    final ProfileSpec profile = profileValue();
    final FilterSpec filter = filterFromArgs();
    final int seed = seedValue();
    final int concurrency = concurrencyValue();
    final bool annotateFlag = argResults!['annotate'] as bool;
    // 有难度/技巧筛选条件时必须标注，否则无从判定（自动启用并提示）。
    final bool annotate = annotateFlag || !filter.isEmpty;
    if (annotate && !annotateFlag) {
      reporter.progress('检测到难度/技巧筛选条件，自动启用 --annotate（筛选需标注数据）');
    }

    final Difficulty targetDifficulty = filter.exactDifficulty ??
        filter.minDifficulty ??
        profile.defaultDifficulty;
    final int targetGivens = _resolveTargetGivens(targetDifficulty);
    final int maxAttempts = _resolveMaxAttempts();

    reporter.section('generate：$count 道'
        '${targetDifficulty.zhName}，profile=${profile.name}'
        '（规则集 ${profile.ruleSet.length} 项），seed=$seed，并发 $concurrency');
    if (annotate) {
      reporter.progress('  标注模式：逐级求解中……');
    }

    final GenerationPipeline pipeline = GenerationPipeline(reporter: reporter);
    final PipelineRunResult result = await pipeline.run(
      targetCount: count,
      baseSeed: seed,
      profile: profile,
      filter: filter,
      maxAttempts: maxAttempts,
      targetGivens: targetGivens,
      concurrency: concurrency,
      annotate: annotate,
    );

    reporter.section('生成结果');
    reporter.reportStats(result.stats);

    final String out = outValue() ?? '';
    if (out.isNotEmpty) {
      final String target = resolvePath(out);
      final CollectionKind kind = annotate ? CollectionKind.annotated : CollectionKind.generated;
      JsonWriter.writeJsonAuto(
        target,
        json: PuzzleCollection.encode(
          kind: kind,
          profile: profile.name,
          seed: seed,
          concurrency: concurrency,
          puzzles: result.puzzles,
        ),
      );
      reporter.info('已写出：$target（${result.puzzles.length} 道，'
          '${_sizeOf(target)}）');
    } else {
      _printSamples(result.puzzles);
    }
    return result.isComplete ? 0 : 1;
  }

  /// 目标提示数：`--target-givens` 优先，否则按难度档内建默认。
  int _resolveTargetGivens(Difficulty difficulty) {
    final String? raw = argResults!['target-givens'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final int? value = int.tryParse(raw);
      if (value == null || value < PuzzleGenerator.kMinGivens || value > 81) {
        throw UsageException('--target-givens 必须在 17..81', usage);
      }
      return value;
    }
    return kDefaultTargetGivensByDifficulty[difficulty] ?? 30;
  }

  /// 尝试预算：`--max-attempts` 优先，否则 profile.maxAttempts。
  int _resolveMaxAttempts() {
    final String? raw = argResults!['max-attempts'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final int? value = int.tryParse(raw);
      if (value == null || value < 1) {
        throw UsageException('--max-attempts 必须是 ≥1 的整数', usage);
      }
      return value;
    }
    return profileValue().maxAttempts;
  }

  void _printSamples(List<AnnotatedPuzzle> puzzles) {
    if (puzzles.isEmpty) {
      return;
    }
    reporter.info('样例（前 ${puzzles.length < 3 ? puzzles.length : 3} 道）：');
    for (final AnnotatedPuzzle puzzle in puzzles.take(3)) {
      reporter.info('  ${puzzle.puzzle81}  '
          '难度=${puzzle.difficulty?.id ?? '-'}  seed=${puzzle.seed}');
    }
    reporter.info('提示：加 --out <file.json> 落盘，供 annotate/filter/export-* 复用。');
  }

  static String _sizeOf(String path) {
    try {
      final int bytes = File(path).lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      }
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } on FileSystemException {
      return '?';
    }
  }
}
