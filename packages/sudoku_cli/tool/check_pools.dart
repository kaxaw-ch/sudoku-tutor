/// 核验综合试炼题池：题数 / 指纹去重 / 目标技巧覆盖（T-CNT-02 验收）。
/// 用法: `dart run tool/check_pools.dart <pool1.json.gz> ...`
library;

import 'dart:io';

import 'package:sudoku_cli/sudoku_cli.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('用法: dart run tool/check_pools.dart <pool.json.gz> ...');
    exit(2);
  }
  for (final String path in args) {
    final Map<String, Object?> root = JsonWriter.readJsonMap(path);
    final List<Object?> raw = root['puzzles'] as List<Object?>? ?? const <Object?>[];
    final Set<String> fingerprints = <String>{};
    final Map<String, int> techUsage = <String, int>{};
    final Set<String> hardest = <String>{};
    int dup = 0;
    for (final Object? item in raw) {
      final Map<String, Object?> p = item! as Map<String, Object?>;
      if (!fingerprints.add(p['fingerprint']! as String)) {
        dup++;
      }
      final Object? rawCounts = p['usageCounts'];
      if (rawCounts is Map<String, Object?>) {
        for (final MapEntry<String, Object?> e in rawCounts.entries) {
          techUsage[e.key] = (techUsage[e.key] ?? 0) + (e.value! as int);
        }
      }
      final Object? h = p['hardestTechnique'];
      if (h is String) {
        hardest.add(h);
      }
    }
    stdout.writeln('== ${path.split(RegExp(r'[/\\]')).last} ==');
    stdout.writeln('  count: ${raw.length}（去重 $dup）');
    stdout.writeln('  targetTechniques: ${root['targetTechniques']}');
    stdout.writeln('  实际使用技巧(次数): $techUsage');
    stdout.writeln('  最高技巧集合: $hardest');
    // 验收口径：ch1/ch2/ch3 目标技巧应全部覆盖。
    final Object? rawTargets = root['targetTechniques'];
    if (rawTargets is List<Object?> && rawTargets.isNotEmpty) {
      final Set<String> missing = <String>{
        for (final Object? id in rawTargets)
          if (!techUsage.containsKey(id! as String)) id as String,
      };
      if (missing.isEmpty) {
        stdout.writeln('  目标技巧覆盖: 全部命中 ✅');
      } else {
        stdout.writeln('  目标技巧覆盖: 缺失 $missing ⚠️');
      }
    }
    stdout.writeln('');
  }
}
