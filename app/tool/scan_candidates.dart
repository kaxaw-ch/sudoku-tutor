/// 候选盘面扫描（F-5 探索用，非交付物）。
///
/// 扫描 dataset/level_candidates/ch{0..3} 全部候选，输出每关每候选的
/// kind / techniqueTags / 最高技巧（非基础）/ 脚本步数 / 旁白空缺数。
// ignore_for_file: avoid_print

library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

import 'project_paths.dart';

/// 基础技巧（不计入"最高技巧"）。
const Set<String> _base = <String>{'nakedSingle', 'hiddenSingle'};

void main() {
  final String rootPath = findProjectRoot();
  final Directory root = Directory('$rootPath/dataset/level_candidates');
  final List<int> chapters = <int>[0, 1, 2, 3];
  for (final int ch in chapters) {
    final Directory dir = Directory('${root.path}/ch$ch');
    if (!dir.existsSync()) {
      continue;
    }
    print('===== ch$ch =====');
    // 按关卡聚合：ch{l01..lNN}
    final Map<String, List<File>> byLevel = <String, List<File>>{};
    for (final File f in dir.listSync().whereType<File>()) {
      final String name = f.uri.pathSegments.last;
      final RegExpMatch? m =
          RegExp(r'^(ch\d+_l\d+)_candidate_(\d+)\.json$').firstMatch(name);
      if (m == null) {
        continue;
      }
      byLevel.putIfAbsent(m.group(1)!, () => <File>[]).add(f);
    }
    final List<String> levelKeys = byLevel.keys.toList()..sort();
    for (final String levelId in levelKeys) {
      final List<File> files = byLevel[levelId]!
        ..sort((a, b) {
          final int an = int.parse(RegExp(r'candidate_(\d+)')
              .firstMatch(a.uri.pathSegments.last)!
              .group(1)!);
          final int bn = int.parse(RegExp(r'candidate_(\d+)')
              .firstMatch(b.uri.pathSegments.last)!
              .group(1)!);
          return an.compareTo(bn);
        });
      print('--- $levelId (${files.length} 候选) ---');
      for (final File f in files) {
        final String name = f.uri.pathSegments.last;
        final Map<String, Object?> json =
            (jsonDecode(f.readAsStringSync()) as Map<String, Object?>);
        final String kind = (json['kind'] as String?) ?? '?';
        final List<Object?> tags =
            (json['techniqueTags'] as List<Object?>?) ?? const <Object?>[];
        final String? hardest = _hardest(tags);
        final int steps = _scriptSteps(json['script']);
        final int emptyNarration = _emptyNarration(json['script']);
        final String title = (json['title'] as String?) ?? '';
        print('  $name | kind=$kind | tags=$tags | 最高=$hardest | '
            '步数=$steps | 旁白空=$emptyNarration | title=$title');
      }
    }
  }
}

/// 最高阶技巧：techniqueTags 中非基础技巧中 rank 最高者。
String? _hardest(List<Object?> tags) {
  int best = -1;
  String? bestId;
  for (final Object? v in tags) {
    final String id = v! as String;
    if (_base.contains(id)) {
      continue;
    }
    final TechniqueId? t = TechniqueId.tryParse(id);
    if (t == null) {
      continue;
    }
    if (t.index > best) {
      best = t.index;
      bestId = id;
    }
  }
  return bestId;
}

int _scriptSteps(Object? script) {
  if (script is! Map<String, Object?>) {
    return 0;
  }
  final Object? steps = script['steps'];
  return steps is List<Object?> ? steps.length : 0;
}

int _emptyNarration(Object? script) {
  if (script is! Map<String, Object?>) {
    return 0;
  }
  final Object? steps = script['steps'];
  if (steps is! List<Object?>) {
    return 0;
  }
  int count = 0;
  for (final Object? s in steps) {
    final Map<String, Object?> step = s! as Map<String, Object?>;
    final Object? n = step['narration'];
    if (n == null || (n as String).trim().isEmpty) {
      count++;
    }
  }
  return count;
}
