/// T-QA-05 关卡 JSON 校验器（共享逻辑，供 `verify_levels_test.dart` 编排断言）。
///
/// 职责来源：从 F-5 一次性脚本 `tool/verify_curriculum.dart` **移植核心校验逻辑**，
/// 重构为可复用 API——无 `main` / 无 `exit` / 无控制台输出，只返回结构化结果：
/// - 1. `LevelIndex.fromJson` 解析 `index.json`，34 关登记齐全（id ↔ 文件一一对应、
///   章内 order 连续唯一、无幽灵文件）；
/// - 2. `LevelCodec.decode` 逐关解析（字段完整性 + 题面 givens ⊆ 终局解）；
/// - 3. `ScriptReplayer` 逐步回放（P0-QA-05：**任意一步不一致即失败**，
///   错误含关卡 id + 步骤号 + 期望 vs 实际）；
/// - 4. 试炼关专项（`kind == 'trial'`）：题面唯一解 + 最高技巧 == 目标技巧 +
///   poolRef 指向来源池。
///
/// 运行说明：由 `dart test tool/ci/verify_levels_test.dart` 驱动（package:test）；
/// 目录解析 = `SUDOKU_CURRICULUM_DIR` 环境变量 → cwd 下 `assets/curriculum` →
/// cwd 下 `app/assets/curriculum`。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

/// PRD P0-LVL 表的 34 关 id 全集（供 index 登记核对）。
const List<String> kKnownLevelIds = <String>[
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

/// 试炼关 id 全集（`kind == 'trial'`，doc 07 §6 明确 3 关）。
const List<String> kTrialLevelIds = <String>[
  'ch1_l07',
  'ch2_l07',
  'ch3_l10',
];

/// 基础技巧（不计入"最高技巧"；试炼关目标必须高于基础档）。
const Set<String> kBaseTechniques = <String>{'nakedSingle', 'hiddenSingle'};

/// 一关的校验结果（`errors` 为空即通过）。
class LevelVerification {
  const LevelVerification({
    required this.id,
    required this.level,
    this.errors = const <String>[],
  });

  /// 关卡 id。
  final String id;

  /// 解码后的关卡（解码失败时为 `null`）。
  final LessonLevel? level;

  /// 校验失败明细（空 = 通过）。
  final List<String> errors;

  /// 是否通过。
  bool get passed => errors.isEmpty;
}

/// 全量校验产出（index 级 + 逐关级）。
class CurriculumVerification {
  CurriculumVerification({
    this.indexErrors = const <String>[],
    List<LevelVerification> levels = const <LevelVerification>[],
  }) : levels = List<LevelVerification>.unmodifiable(levels);

  /// index.json 登记/解析类错误（空 = 通过）。
  final List<String> indexErrors;

  /// 逐关校验结果（顺序同 index 登记）。
  final List<LevelVerification> levels;

  /// index 级是否通过。
  bool get indexPassed => indexErrors.isEmpty;

  /// 全部关卡是否通过。
  bool get allLevelsPassed => levels.every((LevelVerification lv) => lv.passed);

  /// 汇总是否通过（index + 全部关卡）。
  bool get allPassed => indexPassed && allLevelsPassed;

  /// 按 id 查关卡结果；未登记返回 `null`。
  LevelVerification? byId(String id) {
    for (final LevelVerification lv in levels) {
      if (lv.id == id) {
        return lv;
      }
    }
    return null;
  }

  /// 试炼关结果列表（按 `level.kind == trial` 识别）。
  List<LevelVerification> get trialLevels => <LevelVerification>[
        for (final LevelVerification lv in levels)
          if (lv.level?.kind == LevelKind.trial) lv,
      ];
}

/// 关卡校验器（无全局可变状态）。
class LevelVerifier {
  /// 构造校验器；[curriculumDir] 省略时按
  /// `SUDOKU_CURRICULUM_DIR` 环境变量 → cwd 相对路径解析。
  LevelVerifier({String? curriculumDir})
      : curriculumDir = curriculumDir ?? _resolveCurriculumDir();

  /// curriculum 目录（`index.json` 所在目录）。
  final String curriculumDir;

  /// 环境变量名（CI 可用它指定 assets 绝对路径）。
  static const String kCurriculumEnv = 'SUDOKU_CURRICULUM_DIR';

  final ScriptReplayer _replayer = ScriptReplayer();

  /// 解析 curriculum 目录：
  /// 环境变量 `SUDOKU_CURRICULUM_DIR` → cwd 下 `assets/curriculum` → cwd 下 `app/assets/curriculum`。
  static String _resolveCurriculumDir() {
    final String? env = Platform.environment[kCurriculumEnv];
    if (env != null && env.trim().isNotEmpty) {
      return env;
    }
    final String cwd = Directory.current.path;
    final List<String> candidates = <String>[
      '$cwd/assets/curriculum',
      '$cwd/app/assets/curriculum',
    ];
    for (final String candidate in candidates) {
      if (Directory(candidate).existsSync()) {
        return candidate;
      }
    }
    throw StateError('无法定位 curriculum 目录（尝试 $candidates；'
        '可设置环境变量 $kCurriculumEnv 指定绝对路径）');
  }

  // ------------------------------------------------------------ 全量校验

  /// 全量校验：index 登记 + 逐关解码/回放 + 试炼关专项。
  CurriculumVerification verifyAll() {
    final List<String> indexErrors = <String>[];
    final List<LevelVerification> levelResults = <LevelVerification>[];

    // ---- 1. index.json 解析 ----
    final LevelIndex index;
    try {
      index = LevelIndex.fromJson(_readJson('$curriculumDir/index.json'));
    } on Object catch (e) {
      indexErrors.add('LevelIndex.fromJson 失败: $e');
      return CurriculumVerification(indexErrors: indexErrors);
    }

    // 1a. 34 关登记齐全且无多余。
    final Set<String> indexedIds = <String>{
      for (final LevelEntry e in index.allLevels) e.id,
    };
    if (index.allLevels.length != kKnownLevelIds.length) {
      indexErrors.add('index 登记条数应为 ${kKnownLevelIds.length}，'
          '实际 ${index.allLevels.length}');
    }
    final List<String> missing = <String>[
      for (final String id in kKnownLevelIds)
        if (!indexedIds.contains(id)) id,
    ];
    if (missing.isNotEmpty) {
      indexErrors.add('index 缺少登记: $missing');
    }
    final List<String> extra = <String>[
      for (final String id in indexedIds)
        if (!kKnownLevelIds.contains(id)) id,
    ];
    if (extra.isNotEmpty) {
      indexErrors.add('index 多余登记: $extra');
    }

    // 1b. id ↔ 文件一一对应（file == '<id>.json' 且文件存在）；无幽灵文件。
    final Set<String> filesOnDisk = <String>{
      for (final File f
          in Directory(curriculumDir).listSync().whereType<File>())
        if (f.path.endsWith('.json')) f.uri.pathSegments.last,
    };
    for (final LevelEntry e in index.allLevels) {
      final String expectedFile = '${e.id}.json';
      if (e.file != expectedFile) {
        indexErrors.add('${e.id} 登记 file 应为 $expectedFile，实际 ${e.file}');
      }
      if (!filesOnDisk.contains(expectedFile)) {
        indexErrors.add('${e.id} 文件 $expectedFile 不存在于 assets/curriculum');
      }
    }
    final Set<String> registeredFiles = <String>{
      for (final LevelEntry e in index.allLevels) e.file,
    };
    for (final String f in filesOnDisk) {
      // index 本身与测试关残留（index 不引用它）不计入幽灵。
      if (f == 'index.json' || f == 'ch0_l01_test.json') {
        continue;
      }
      if (!registeredFiles.contains(f)) {
        indexErrors.add('未登记关卡文件 $f（应只保留 index.json 与 ch0_l01_test.json）');
      }
    }

    // 1c. 每章 order 连续唯一（1..N）、chapter 一致。
    for (final ChapterEntry chapter in index.chapters) {
      final List<int> orders = <int>[
        for (final LevelEntry e in chapter.levels) e.order,
      ]..sort();
      for (int i = 0; i < orders.length; i++) {
        if (orders[i] != i + 1) {
          indexErrors.add('第 ${chapter.chapter} 章 order 应为 1..${orders.length} '
              '连续唯一，实际 $orders');
          break;
        }
      }
      for (final LevelEntry e in chapter.levels) {
        if (e.chapter != chapter.chapter) {
          indexErrors
              .add('${e.id} 登记 chapter=${e.chapter}，应=${chapter.chapter}');
        }
      }
    }

    // ---- 2/3. 逐关解码 + 回放；试炼关追加专项 ----
    for (final LevelEntry entry in index.allLevels) {
      LessonLevel? level;
      final List<String> errors = <String>[];
      try {
        level = LevelCodec.decode(_readJson('$curriculumDir/${entry.file}'));
        errors.addAll(verifyLevel(level));
        if (level.kind == LevelKind.trial) {
          errors.addAll(verifyTrial(level));
        }
      } on Object catch (e) {
        errors.add('${entry.id}: 解码/校验异常 $e');
      }
      levelResults
          .add(LevelVerification(id: entry.id, level: level, errors: errors));
    }

    return CurriculumVerification(
        indexErrors: indexErrors, levels: levelResults);
  }

  // ------------------------------------------------------------ 单关校验

  /// 校验单关（字段完整性 + 题面 givens ⊆ 终局解 + ScriptReplayer 回放零不一致）。
  ///
  /// 返回错误明细；回放不一致时逐条含 `[第 N 步]` + 期望 vs 实际。
  List<String> verifyLevel(LessonLevel level) {
    final String id = level.id;
    final List<String> errors = <String>[];
    void bad(String message) => errors.add('$id: $message');

    // 字段完整性。
    if (level.puzzle81.length != 81) {
      bad('puzzle81 长度应为 81，实际 ${level.puzzle81.length}');
    }
    if (level.solution81.length != 81) {
      bad('solution81 长度应为 81，实际 ${level.solution81.length}');
    }
    if (!_isValidSolution81(level.solution81)) {
      bad('solution81 含非法字符');
    }
    if (level.techniqueTags.isEmpty) {
      bad('techniqueTags 不应为空');
    }
    if (!level.hasScript) {
      bad('script 不应为空');
    }
    final int givenCount = level.givenCount;
    if (givenCount <= 0 || givenCount >= 81) {
      bad('givenCount 应为 1..80，实际 $givenCount');
    }

    // 题面 givens ⊆ 终局解。
    final String puzzle = level.puzzle81;
    final String solution = level.solution81;
    for (int i = 0; i < 81; i++) {
      if (puzzle[i] != '.' && puzzle[i] != '0' && puzzle[i] != solution[i]) {
        bad('题面 givens 与终局解冲突于 index $i');
        break;
      }
    }

    // ScriptReplayer 逐步回放：任意一步不一致即失败（含步骤号 + 期望 vs 实际）。
    final SolutionScript? script = level.script;
    if (script != null && script.isNotEmpty) {
      try {
        final ScriptReplayOutcome outcome = _replayer.replayLevel(level);
        if (!outcome.passed) {
          for (final ReplayMismatch m in outcome.mismatches) {
            bad('回放不一致：$m');
          }
        } else if (outcome.verifiedSteps != script.stepCount) {
          bad('回放步数 ${outcome.verifiedSteps} 应等于脚本步数 ${script.stepCount}');
        }
      } on Object catch (e) {
        bad('回放异常 $e');
      }
    }
    return errors;
  }

  /// 校验试炼关专项（`kind == trial`）：唯一解 + 最高技巧 == 目标技巧 + poolRef。
  List<String> verifyTrial(LessonLevel level) {
    final String id = level.id;
    final List<String> errors = <String>[];
    void bad(String message) => errors.add('$id: $message');

    if (level.kind != LevelKind.trial) {
      bad('试炼关 kind 应为 trial，实际 ${level.kind.id}');
    }
    if (level.poolRef == null || level.poolRef!.isEmpty) {
      bad('poolRef 不应为空');
    } else if (level.poolRef != 'pools/ch${level.chapter}.json.gz') {
      bad('poolRef 应为 pools/ch${level.chapter}.json.gz，实际 ${level.poolRef}');
    }
    if (level.techniqueTags.length != 1) {
      bad('techniqueTags 应恰为 1 个目标技巧，实际 '
          '${<String>[for (final TechniqueId t in level.techniqueTags) t.id]}');
      return errors;
    }
    final String target = level.techniqueTags.single.id;

    // 唯一解。
    try {
      final Board board = level.toLevelPuzzle().toCore().toGivenBoard();
      if (!const UniquenessChecker().isUnique(board)) {
        bad('题面应唯一解');
      }
    } on Object catch (e) {
      bad('唯一解判定异常 $e');
    }

    // 最高技巧 == 目标技巧（非基础最高阶）。
    final String? hardest = _hardest(level.techniqueTags);
    if (hardest != target) {
      bad('最高技巧应为 $target，实际 $hardest');
    }

    // 脚本实际用到的最高技巧也应含目标技巧（脚本可能先做基础铺垫）。
    final SolutionScript? script = level.script;
    if (script == null) {
      bad('试炼关脚本不应为空');
    } else {
      final String? hardestInScript = _hardestOfScript(script);
      if (hardestInScript != target) {
        bad('脚本最高技巧应为 $target，实际 $hardestInScript');
      }
    }
    return errors;
  }

  // ------------------------------------------------------------ 工具

  /// 最高技巧（跳过基础档；返回其 id，全为基础或无技巧返回 `null`）。
  static String? _hardest(Set<TechniqueId> tags) {
    int best = -1;
    String? bestId;
    for (final TechniqueId t in tags) {
      if (kBaseTechniques.contains(t.id)) {
        continue;
      }
      if (t.index > best) {
        best = t.index;
        bestId = t.id;
      }
    }
    return bestId;
  }

  /// 脚本各步用到的最难技巧 id（跳过基础档）。
  static String? _hardestOfScript(SolutionScript script) {
    int best = -1;
    String? bestId;
    for (final ScriptStep step in script.steps) {
      if (kBaseTechniques.contains(step.techniqueId.id)) {
        continue;
      }
      if (step.techniqueId.index > best) {
        best = step.techniqueId.index;
        bestId = step.techniqueId.id;
      }
    }
    return bestId;
  }

  static bool _isValidSolution81(String s) {
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

  static Map<String, Object?> _readJson(String path) {
    try {
      return jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    } on Object catch (e) {
      throw StateError('读取/解析 $path 失败: $e');
    }
  }
}
