/// 候选回放校验 + 池扫描（F-5 精选前置，非交付物）。
///
/// 1. 对 dataset/level_candidates/ch{0..3} 全部候选做 ScriptReplayer 回放，
///    输出每关通过/失败列表（失败原因摘要）；
/// 2. 读 app/assets/pools/ch{1,2,3}.json.gz，列出最高技巧 == 目标技巧的题。
// ignore_for_file: avoid_print

library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

import 'project_paths.dart';

final String _root = findProjectRoot();
const Set<String> _base = <String>{'nakedSingle', 'hiddenSingle'};

void main() {
  final ScriptReplayer replayer = ScriptReplayer();
  for (final int ch in <int>[0, 1, 2, 3]) {
    final Directory dir = Directory('$_root/dataset/level_candidates/ch$ch');
    if (!dir.existsSync()) {
      continue;
    }
    print('===== ch$ch =====');
    final Map<String, List<File>> byLevel = <String, List<File>>{};
    for (final File f in dir.listSync().whereType<File>()) {
      final RegExpMatch? m = RegExp(r'^(ch\d+_l\d+)_candidate_(\d+)\.json$')
          .firstMatch(f.uri.pathSegments.last);
      if (m != null) {
        byLevel.putIfAbsent(m.group(1)!, () => <File>[]).add(f);
      }
    }
    final List<String> keys = byLevel.keys.toList()..sort();
    for (final String levelId in keys) {
      final List<File> files = byLevel[levelId]!;
      files.sort((a, b) {
        final int an = int.parse(RegExp(r'candidate_(\d+)')
            .firstMatch(a.uri.pathSegments.last)!
            .group(1)!);
        final int bn = int.parse(RegExp(r'candidate_(\d+)')
            .firstMatch(b.uri.pathSegments.last)!
            .group(1)!);
        return an.compareTo(bn);
      });
      for (final File f in files) {
        final String name = f.uri.pathSegments.last;
        final Map<String, Object?> json =
            (jsonDecode(f.readAsStringSync()) as Map<String, Object?>);
        final LessonLevel level;
        try {
          level = LevelCodec.decode(json);
        } on Object catch (e) {
          print('  $name | DECODE-FAIL: $e');
          continue;
        }
        if (level.script == null) {
          print('  $name | 无脚本');
          continue;
        }
        final ScriptReplayOutcome outcome = replayer.replayLevel(level);
        final String? hardest = _hardest(level.techniqueTags);
        print('  $name | 最高=$hardest | 步数=${level.script!.stepCount} | '
            '回放=${outcome.passed ? "PASS" : "FAIL(${outcome.mismatchCount})"}'
            '${outcome.mismatches.isEmpty ? "" : " 例:${outcome.mismatches.take(1).map((m) => m.toString()).join(";")}"}');
      }
    }
  }

  // ---- 池扫描 ----
  print('\n===== POOLS =====');
  final Map<int, List<String>> targets = <int, List<String>>{
    1: <String>['xWing'],
    2: <String>['finnedXWing', 'swordfish'],
    3: <String>['xyWing', 'xyzWing'],
  };
  for (final int ch in <int>[1, 2, 3]) {
    final String path = '$_root/app/assets/pools/ch$ch.json.gz';
    if (!File(path).existsSync()) {
      print('池 ch$ch 不存在：$path');
      continue;
    }
    final String text = utf8.decode(gzip.decode(File(path).readAsBytesSync()));
    final Map<String, Object?> root =
        (jsonDecode(text) as Map<String, Object?>);
    final List<Object?> puzzles =
        (root['puzzles'] as List<Object?>?) ?? const <Object?>[];
    print('--- ch$ch 池（共 ${puzzles.length} 题，target=${targets[ch]!}）---');
    for (final Object? item in puzzles) {
      final Map<String, Object?> p = item! as Map<String, Object?>;
      final String? hardest = p['hardestTechnique'] as String?;
      if (hardest != null && targets[ch]!.contains(hardest)) {
        final int steps = (p['stepCount'] as int?) ?? 0;
        final int scriptSteps = _scriptLen(p['script']);
        print('  命中 hardest=$hardest | seed=${p['seed']} | '
            'givenCount=${p['givenCount']} | 标注步数=$steps | script步数=$scriptSteps | '
            'puzzle81=${p['puzzle81']}');
      }
    }
  }
}

String? _hardest(Set<TechniqueId> tags) {
  int best = -1;
  String? bestId;
  for (final TechniqueId t in tags) {
    if (_base.contains(t.id)) {
      continue;
    }
    if (t.index > best) {
      best = t.index;
      bestId = t.id;
    }
  }
  return bestId;
}

int _scriptLen(Object? script) {
  if (script is! List<Object?>) {
    return 0;
  }
  return script.length;
}
