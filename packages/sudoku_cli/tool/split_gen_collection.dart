/// 把一个技巧的标注大集合切成「每关 6 候选」的子集合（T-CNT-03 用）。
///
/// 背景：同一技巧的多关若各自独立 generate，由于有效盘面在种子空间稀疏，
/// 相邻 seed 的运行会扫到相同「有效种子」→ 跨关产出相同盘面。
/// 本工具改为**每技巧一次大集合**（count = 关数×6），随后按序切成各关子集合，
/// 子集合内天然指纹去重、子集合之间绝不重叠。
///
/// 用法: `dart run tool/split_gen_collection.dart <input.json> <outDir> <spec>...`
/// 其中 `<spec>` 形如 `ch0_l01=6,ch0_l03=6`（支持逗号分隔多个，按序分配）。
library;

import 'dart:io';

import 'package:sudoku_cli/sudoku_cli.dart';

void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln(
      '用法: dart run tool/split_gen_collection.dart <input.json> <outDir> '
      '<levelId=count[,levelId=count...]> ...',
    );
    exit(2);
  }
  final String input = args[0];
  final String outDir = args[1];
  final List<(String, int)> specs = <(String, int)>[];
  for (final String chunk in args.sublist(2)) {
    for (final String spec in chunk.split(',')) {
      if (spec.isEmpty) {
        continue;
      }
      final List<String> parts = spec.split('=');
      if (parts.length != 2) {
        stderr.writeln('非法 spec「$spec」（应为 levelId=count）');
        exit(2);
      }
      final int? count = int.tryParse(parts[1]);
      if (count == null || count < 1) {
        stderr.writeln('非法 count「$spec」');
        exit(2);
      }
      specs.add((parts[0], count));
    }
  }

  final Map<String, Object?> root = JsonWriter.readJsonMap(input);
  final List<Object?> rawPuzzles = root['puzzles'] as List<Object?>? ?? const <Object?>[];
  final List<AnnotatedPuzzle> puzzles = <AnnotatedPuzzle>[
    for (final Object? item in rawPuzzles)
      AnnotatedPuzzle.fromJson(item! as Map<String, Object?>),
  ];

  Directory(outDir).createSync(recursive: true);
  int offset = 0;
  final Map<String, String> fileByLevel = <String, String>{};
  for (final (String level, int count) in specs) {
    final int end = offset + count;
    if (end > puzzles.length) {
      stderr.writeln('素材不足：$level 需要 $count 道，剩余 ${puzzles.length - offset}');
      exit(1);
    }
    final List<AnnotatedPuzzle> slice =
        puzzles.sublist(offset, end).toList();
    final String target = Directory(outDir).isAbsolute
        ? '$outDir${Platform.pathSeparator}$level.gen.json'
        : joinPath(outDir, '$level.gen.json');
    JsonWriter.writeJsonAuto(
      target,
      json: PuzzleCollection.encode(
        kind: CollectionKind.annotated,
        profile: (root['profile'] as String?) ?? 't2',
        seed: (root['seed'] as int?) ?? 0,
        concurrency: (root['concurrency'] as int?) ?? 1,
        puzzles: slice,
      ),
    );
    fileByLevel[level] = target;
    stdout.writeln('  $level ← ${slice.length} 道（seed=${slice.map((p) => p.seed).join(',')}）');
    offset = end;
  }
  if (offset != puzzles.length) {
    stdout.writeln('提示：集合共 ${puzzles.length} 道，已用 $offset，剩余 ${puzzles.length - offset} 道未分配。');
  }
  stdout.writeln('已写出 ${specs.length} 个子集合 → $outDir');
}

String joinPath(String a, String b) {
  final String sep = Platform.pathSeparator;
  return '${Directory.current.path}$sep$a$sep$b';
}
