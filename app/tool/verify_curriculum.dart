/// F-5 全量校验脚本（T-CNT-04 + T-CNT-05 验收，交付物）。
///
/// 对 `app/assets/curriculum/` 做四重校验：
/// 1. `LevelIndex.fromJson` 解析 `index.json` 成功，34 关登记齐全，
///    `id` 与文件一一对应、章内 `order` 连续唯一；
/// 2. `LevelCodec.decode` 解析每关成功，字段完整（81 题面/终局解/givenMask
///    由题面推导、script 非空、techniqueTags 非空）；
/// 3. `ScriptReplayer` 回放每关脚本：**零不一致**（逐步校验技巧/删数/填数）；
/// 4. 3 个试炼关：题面唯一解 + 最高技巧 == 目标技巧 + poolRef 指向来源池。
///
/// 运行：`dart run tool/verify_curriculum.dart`
/// 退出码：0 = 全部通过；非 0 = 存在失败（stderr 打印明细）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

import 'project_paths.dart';

final String _root = findProjectRoot();
final String _curDir = '$_root/app/assets/curriculum';

/// 34 关 id 全集（按 PRD P0-LVL 表）。
const List<String> _allIds = <String>[
  'ch0_l01',
  'ch0_l02',
  'ch0_l03',
  'ch0_l04',
  'ch0_l05',
  'ch0_l06',
  'ch0_l07',
  'ch0_l08',
  'ch0_l09',
  'ch0_l10',
  'ch1_l01',
  'ch1_l02',
  'ch1_l03',
  'ch1_l04',
  'ch1_l05',
  'ch1_l06',
  'ch1_l07',
  'ch2_l01',
  'ch2_l02',
  'ch2_l03',
  'ch2_l04',
  'ch2_l05',
  'ch2_l06',
  'ch2_l07',
  'ch3_l01',
  'ch3_l02',
  'ch3_l03',
  'ch3_l04',
  'ch3_l05',
  'ch3_l06',
  'ch3_l07',
  'ch3_l08',
  'ch3_l09',
  'ch3_l10',
];

/// 试炼关目标技巧（id → 目标技巧）。
const Map<String, String> _trialTargets = <String, String>{
  'ch1_l07': 'xWing',
  'ch2_l07': 'finnedXWing',
  'ch3_l10': 'xyzWing',
};

/// 基础技巧（不计入"最高技巧"）。
const Set<String> _base = <String>{'nakedSingle', 'hiddenSingle'};

void main() {
  final List<String> errors = <String>[];
  final Map<String, String> levelResults = <String, String>{};
  int passCount = 0;
  int failCount = 0;

  void check(bool ok, String msg) {
    if (ok) {
      passCount++;
    } else {
      failCount++;
      errors.add(msg);
    }
  }

  void checkLevel(String id, void Function() body) {
    final int failuresBefore = failCount;
    try {
      body();
      if (failCount == failuresBefore) {
        levelResults[id] = 'PASS';
        passCount++;
      } else {
        levelResults[id] = 'FAIL';
      }
    } on Object catch (e) {
      levelResults[id] = 'FAIL';
      failCount++;
      errors.add('$id: $e');
    }
  }

  final ScriptReplayer replayer = ScriptReplayer();

  // ---------- 1. index.json 解析与登记 ----------
  final Map<String, Object?> indexJson =
      _readJson('$_curDir/index.json', errors, 'index.json');
  final LevelIndex index;
  try {
    index = LevelIndex.fromJson(indexJson);
    passCount++;
  } on Object catch (e) {
    errors.add('LevelIndex.fromJson 失败: $e');
    stderr.writeln('IS_PASS = false（index 解析失败，后续校验跳过）');
    exit(1);
  }

  // 1a. 34 关登记齐全且无多余（恰好 34 条，无重复）。
  check(index.allLevels.length == 34,
      'index 登记条数应为 34，实际 ${index.allLevels.length}');
  final Set<String> indexedIds = <String>{
    for (final LevelEntry e in index.allLevels) e.id,
  };
  check(
      indexedIds.length == _allIds.length && _allIds.every(indexedIds.contains),
      'index 登记关卡数应为 34 且覆盖全部 id：'
      '实际 ${indexedIds.length}（${_allIds.where((String i) => !indexedIds.contains(i)).toList()}）');

  // 1b. id ↔ 文件一一对应（file == '<id>.json' 且文件存在）。
  final Set<String> filesOnDisk = <String>{
    for (final File f in Directory(_curDir).listSync().whereType<File>())
      if (f.path.endsWith('.json')) f.uri.pathSegments.last,
  };
  for (final LevelEntry e in index.allLevels) {
    final String expectedFile = '${e.id}.json';
    check(e.file == expectedFile,
        '${e.id} 登记 file 应为 $expectedFile，实际 ${e.file}');
    check(filesOnDisk.contains(expectedFile),
        '${e.id} 文件 $expectedFile 不存在于 assets/curriculum');
  }
  // 无幽灵文件（除 ch0_l01_test 外不应有未登记关卡）。
  final Set<String> registeredFiles = <String>{
    for (final LevelEntry e in index.allLevels) e.file,
  };
  for (final String f in filesOnDisk) {
    if (f == 'index.json' || f == 'ch0_l01_test.json') {
      continue;
    }
    check(registeredFiles.contains(f),
        '未登记关卡文件 $f（应只保留 index.json 与 ch0_l01_test.json）');
  }

  // 1c. 每章 order 连续且唯一（1..N）、chapter 正确。
  for (final ChapterEntry chapter in index.chapters) {
    final List<LevelEntry> levels = chapter.levels;
    final List<int> orders = <int>[
      for (final LevelEntry e in levels) e.order,
    ]..sort();
    check(
        orders.length == levels.length &&
            <int>[for (int i = 0; i < orders.length; i++) i + 1]
                .every((int i) => orders[i - 1] == i),
        '第 ${chapter.chapter} 章 order 应为 1..${levels.length} 连续唯一，'
        '实际 $orders');
    for (final LevelEntry e in levels) {
      check(e.chapter == chapter.chapter,
          '${e.id} 登记 chapter=${e.chapter}，应=${chapter.chapter}');
    }
  }

  // ---------- 2/3. 逐关解码 + 回放 ----------
  final Set<String> trialIds = _trialTargets.keys.toSet();
  for (final String id in _allIds) {
    final LevelEntry? entry = index.byId(id);
    if (entry == null) {
      check(false, 'index 未登记 $id');
      continue;
    }
    checkLevel(id, () {
      final Map<String, Object?> json =
          _readJson('$_curDir/${entry.file}', errors, entry.file);
      final LessonLevel level = LevelCodec.decode(json);

      // 字段完整性与一致性。
      check(level.id == id, '关卡 JSON id 应等于登记 id $id，实际 ${level.id}');
      check(level.puzzle81.length == 81, 'puzzle81 长度应为 81');
      check(level.solution81.length == 81, 'solution81 长度应为 81');
      check(_isValidSolution81(level.solution81), 'solution81 含非法字符');
      check(level.techniqueTags.isNotEmpty, 'techniqueTags 不应为空');
      check(level.hasScript, 'script 不应为空');
      check(
        trialIds.contains(id) == (level.kind == LevelKind.trial),
        '$id kind=${level.kind.id}，试炼关集合应与 kind=trial 严格一致',
      );
      check(level.givenCount > 0 && level.givenCount < 81,
          'givenCount 应为 1..80，实际 ${level.givenCount}');
      check(
          _deriveMask(level.puzzle81) ==
              (json['givenMask'] ?? _deriveMask(level.puzzle81)),
          'givenMask 应与题面推导一致');

      // 题面 givens ⊆ 终局解。
      final String p = level.puzzle81;
      final String s = level.solution81;
      for (int i = 0; i < 81; i++) {
        if (p[i] != '.' && p[i] != '0') {
          check(p[i] == s[i], '题面 givens 与终局解冲突于 index $i');
        }
      }

      // ScriptReplayer 回放：零不一致。
      final ScriptReplayOutcome outcome = replayer.replayLevel(level);
      if (!outcome.passed) {
        throw StateError('回放不一致 ${outcome.mismatchCount} 处，'
            '首条：${outcome.mismatches.first}');
      }
      check(outcome.verifiedSteps == level.script!.stepCount, '回放步数应等于脚本步数');
    });
  }

  // ---------- 4. 试炼关专项 ----------
  for (final String id in _trialTargets.keys) {
    final LevelEntry? entry = index.byId(id);
    if (entry == null) {
      check(false, '试炼关 $id 未登记');
      continue;
    }
    checkLevel(id, () {
      final Map<String, Object?> json =
          _readJson('$_curDir/${entry.file}', errors, entry.file);
      final LessonLevel level = LevelCodec.decode(json);
      final String target = _trialTargets[id]!;

      check(level.kind == LevelKind.trial, '试炼关 kind 应为 trial');
      check(level.poolRef != null && level.poolRef!.isNotEmpty,
          '试炼关 poolRef 不应为空');
      check(level.poolRef == 'pools/ch${level.chapter}.json.gz',
          'poolRef 应为 pools/ch${level.chapter}.json.gz，实际 ${level.poolRef}');
      check(
          level.techniqueTags.length == 1 &&
              level.techniqueTags.single.id == target,
          '试炼关 techniqueTags 应恰为 [$target]，实际 ${level.techniqueTags}');

      // 唯一解。
      final Board board = level.toLevelPuzzle().toCore().toGivenBoard();
      check(const UniquenessChecker().isUnique(board), '$id 题面应唯一解');

      // 最高技巧 == 目标技巧（非基础最高阶）。
      final String? hardest = _hardest(level.techniqueTags);
      check(hardest == target, '试炼关最高技巧应为 $target，实际 $hardest');

      // 脚本实际用到的最高技巧也应含目标技巧（脚本可能先做基础铺垫）。
      final String? hardestInScript = _hardestOfScript(level.script!);
      check(
          hardestInScript == target, '试炼关脚本最高技巧应为 $target，实际 $hardestInScript');
    });
  }

  // ---------- 汇总 ----------
  stdout.writeln('===== 全量校验结果 =====');
  stdout.writeln('LevelCodec/回放/试炼专项检查项：${passCount + failCount} 项，'
      '通过 $passCount，失败 $failCount');
  stdout.writeln('--- 逐关摘要（34 关）---');
  for (final String id in _allIds) {
    final String? result = levelResults[id];
    if (result == null) {
      stdout.writeln('  ? $id（未校验：index 未登记）');
    } else if (result == 'PASS') {
      stdout.writeln('  PASS $id');
    } else {
      stdout.writeln('  FAIL $id');
    }
  }
  if (errors.isNotEmpty) {
    stderr.writeln('--- 失败明细 ---');
    for (final String e in errors) {
      stderr.writeln('  ✗ $e');
    }
  }
  final bool pass = failCount == 0 && indexedIds.length == 34;
  stdout.writeln('IS_PASS = ${pass ? 'true' : 'false'}');
  exit(pass ? 0 : 1);
}

// ------------------------------------------------------------ 工具

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

String? _hardestOfScript(SolutionScript script) {
  int best = -1;
  String? bestId;
  for (final ScriptStep step in script.steps) {
    if (_base.contains(step.techniqueId.id)) {
      continue;
    }
    if (step.techniqueId.index > best) {
      best = step.techniqueId.index;
      bestId = step.techniqueId.id;
    }
  }
  return bestId;
}

bool _isValidSolution81(String s) {
  if (s.length != 81) {
    return false;
  }
  for (final int code in s.codeUnits) {
    if (code < '1'.codeUnitAt(0) || code > '9'.codeUnitAt(0)) {
      return false;
    }
  }
  return true;
}

String _deriveMask(String puzzle81) => <String>[
      for (final int code in puzzle81.codeUnits)
        (code == '.'.codeUnitAt(0) || code == '0'.codeUnitAt(0)) ? '0' : '1',
    ].join();

Map<String, Object?> _readJson(String path, List<String> errors, String what) {
  try {
    return (jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>);
  } on Object catch (e) {
    throw StateError('读取/解析 $what 失败: $e');
  }
}
