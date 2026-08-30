/// 合并多份 `export-pool` 产出的题池为单章题池（T-CNT-02 用）。
///
/// 背景：`export-pool --target` 语义是「命中任意一个即收录」，为保证
/// ch1/ch2/ch3 池**覆盖本章全部目标技巧**，按技巧分别出池后在此合并，
/// 按 `fingerprint` 去重（跨池可能同构）。
///
/// 用法:
/// ```bash
/// dart run tool/merge_pools.dart <chapter> <difficulty> <out.json.gz> \
///   <in1.json.gz> [in2.json.gz ...]
/// ```
/// `difficulty` 仅用于合并后的元数据标注（真实难度以每题 difficulty 为准）。
library;

import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';
import 'package:sudoku_cli/sudoku_cli.dart';

Future<void> main(List<String> args) async {
  if (args.length < 4) {
    stderr.writeln(
      '用法: dart run tool/merge_pools.dart <chapter> <difficulty> '
      '<out.json.gz> <in1.json.gz> [in2.json.gz ...]',
    );
    exit(2);
  }

  final int? chapter = int.tryParse(args[0]);
  if (chapter == null || chapter < 0) {
    stderr.writeln('chapter 必须是 ≥0 的整数');
    exit(2);
  }
  final Difficulty? difficulty = Difficulty.tryParse(args[1]);
  if (difficulty == null) {
    stderr.writeln('difficulty 非法：${args[1]}');
    exit(2);
  }
  final String outPath = args[2];
  final List<String> inputs = args.sublist(3);
  if (inputs.isEmpty) {
    stderr.writeln('至少提供一个输入池');
    exit(2);
  }

  final Dedup dedup = Dedup();
  final List<Map<String, Object?>> puzzles = <Map<String, Object?>>[];
  final Set<String> targetTechniques = <String>{};
  int sourceCount = 0;

  for (final String input in inputs) {
    if (!File(input).existsSync()) {
      stderr.writeln('输入池不存在：$input');
      exit(2);
    }
    final Map<String, Object?> root = JsonWriter.readJsonMap(input);
    final Object? rawTargets = root['targetTechniques'];
    if (rawTargets is List<Object?>) {
      for (final Object? id in rawTargets) {
        targetTechniques.add(id! as String);
      }
    }
    final List<Object?> rawPuzzles = root['puzzles'] as List<Object?>? ?? const <Object?>[];
    sourceCount += rawPuzzles.length;
    for (final Object? item in rawPuzzles) {
      final Map<String, Object?> puzzle = item! as Map<String, Object?>;
      final AnnotatedPuzzle parsed = AnnotatedPuzzle.fromJson(puzzle);
      if (dedup.add(parsed.fingerprint)) {
        puzzles.add(puzzle);
      }
    }
    stdout.writeln('  读取 $input：${rawPuzzles.length} 道');
  }

  final Map<String, Object?> pool = <String, Object?>{
    'schemaVersion': kPoolSchemaVersion,
    'chapter': chapter,
    'targetTechniques': targetTechniques.toList()..sort(),
    'difficulty': difficulty.id,
    'profile': 't2',
    'seed': null,
    'concurrency': null,
    'sourcePoolCount': sourceCount,
    'dedupRemoved': sourceCount - puzzles.length,
    'count': puzzles.length,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'puzzles': puzzles,
  };
  JsonWriter.writeJsonAuto(outPath, json: pool);
  stdout.writeln(
    '已写出合并题池：$outPath（${puzzles.length} 道，'
    '来源 $sourceCount 道，去重 ${sourceCount - puzzles.length}）',
  );
}
