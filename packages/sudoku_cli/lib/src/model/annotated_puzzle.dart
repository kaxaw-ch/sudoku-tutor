/// CLI 管线的标注题目模型（题面 + 终局解 + 难度 + 技巧标签 + 解题脚本）。
///
/// ⚠️ 归属与铁律（doc 06 §3.2 / doc 07 批次 D）：
/// - 本文件是 **CLI 侧的数据传输模型**，只负责 JSON 编解码与字段透传，
///   **不实现任何算法**；难度/技巧/脚本数据全部由 `sudoku_core` 的
///   `StepwiseSolver` / `DifficultyGrader` / `TechniqueRegistry` 产出后灌入；
/// - `script.steps[].visual` 直接存 `VisualHint.toJson()` 的原始 map，
///   保证 UI 层「零推断」口径在导出关卡 JSON 时不丢字段。
library;

import 'package:sudoku_core/sudoku_core.dart';

/// 题库/标注集合的 JSON schema 版本（对齐 doc 06 §7.2 的 `kPuzzleBankSchemaVersion`）。
const int kAnnotatedSchemaVersion = 1;

/// 解题脚本中的一步（对齐 doc 06 关卡 JSON `script.steps[]` 结构）。
class AnnotatedScriptStep {
  /// 构造一步脚本。
  AnnotatedScriptStep({
    required this.order,
    required this.techniqueId,
    required this.eliminations,
    required this.placements,
    this.involvedCells = const <int>[],
    this.narration,
    Map<String, Object?>? visual,
  }) : visual = visual ?? const <String, Object?>{};

  /// 步序（从 1 开始）。
  final int order;

  /// 本步技巧。
  final TechniqueId techniqueId;

  /// 删数结论（格索引 → 数字）。
  final List<Elimination> eliminations;

  /// 填数结论（格索引 → 数字）。
  final List<Placement> placements;

  /// 本步涉及的全部格索引（升序，便于人工审校）。
  final List<int> involvedCells;

  /// 渲染好的中文讲解句（可空；由 `NarrationParams` + 模板渲染得到）。
  final String? narration;

  /// `VisualHint.toJson()` 的原始 map（UI 零推断的坐标来源）。
  final Map<String, Object?> visual;

  /// 由 `sudoku_core` 的 [SolveStep] 构造（复用其结论与可视化数据）。
  ///
  /// [narration] 未提供时用 `sudoku_core` 的中文模板渲染（零硬编码文案）。
  factory AnnotatedScriptStep.fromCore(SolveStep step, {String? narration}) =>
      AnnotatedScriptStep(
        order: step.order,
        techniqueId: step.techniqueId,
        eliminations: List<Elimination>.of(step.result.eliminations),
        placements: List<Placement>.of(step.result.placements),
        involvedCells: step.result.involvedCells(),
        narration: narration ?? renderNarration(step.techniqueId, step.result),
        visual: step.result.visual.toJson(),
      );

  /// 序列化为 JSON map（对齐 doc 06 关卡 JSON `script.steps[]`）。
  Map<String, Object?> toJson() => <String, Object?>{
        'order': order,
        'techniqueId': techniqueId.id,
        'involvedCells': List<int>.of(involvedCells),
        'eliminations': <Map<String, Object?>>[
          for (final Elimination e in eliminations) e.toJson(),
        ],
        'placements': <Map<String, Object?>>[
          for (final Placement p in placements) p.toJson(),
        ],
        'narration': narration,
        'visual': visual,
      };

  /// 由 JSON map 反序列化。
  static AnnotatedScriptStep fromJson(Map<String, Object?> json) =>
      AnnotatedScriptStep(
        order: json['order']! as int,
        techniqueId: TechniqueId.parse(json['techniqueId']! as String),
        involvedCells: <int>[
          for (final Object? v in (json['involvedCells'] as List<Object?>? ?? const <Object?>[]))
            v! as int,
        ],
        eliminations: <Elimination>[
          for (final Object? item
              in (json['eliminations'] as List<Object?>? ?? const <Object?>[]))
            Elimination.fromJson(item! as Map<String, Object?>),
        ],
        placements: <Placement>[
          for (final Object? item
              in (json['placements'] as List<Object?>? ?? const <Object?>[]))
            Placement.fromJson(item! as Map<String, Object?>),
        ],
        narration: json['narration'] as String?,
        visual: (json['visual'] as Map<String, Object?>?) ?? const <String, Object?>{},
      );

  @override
  String toString() => '#$order ${techniqueId.id}';
}

/// 一道已标注题目（CLI 管线的核心产物）。
class AnnotatedPuzzle {
  /// 构造标注题目。
  AnnotatedPuzzle({
    required this.puzzle81,
    required this.solution81,
    required this.seed,
    required this.fingerprint,
    this.givenMask,
    this.difficulty,
    this.hardestTechnique,
    this.stepCount = 0,
    Set<TechniqueId> techniques = const <TechniqueId>{},
    Map<TechniqueId, int> usageCounts = const <TechniqueId, int>{},
    List<AnnotatedScriptStep> script = const <AnnotatedScriptStep>[],
  })  : techniques = Set<TechniqueId>.unmodifiable(techniques),
        usageCounts = Map<TechniqueId, int>.unmodifiable(usageCounts),
        script = List<AnnotatedScriptStep>.unmodifiable(script);

  /// 题面 81 字符串（空格用 `.`）。
  final String puzzle81;

  /// 终局解 81 字符串。
  final String solution81;

  /// 生成本题的随机种子（可复现）。
  final int seed;

  /// 规范化指纹（同构去重用，来自 `sudoku_core` 的 `Fingerprint`）。
  final String fingerprint;

  /// 原始题面给定掩码（81 字符 '1'/'0'）；为 null 时按题面推导。
  final String? givenMask;

  /// 评定难度档（未标注时为 null）。
  final Difficulty? difficulty;

  /// 用到的最难技巧（未标注时为 null）。
  final TechniqueId? hardestTechnique;

  /// 逐级求解步数。
  final int stepCount;

  /// 用到的全部技巧（rank 升序去重）。
  final Set<TechniqueId> techniques;

  /// 各技巧使用次数（rank 升序）。
  final Map<TechniqueId, int> usageCounts;

  /// 解题脚本（标注后才有；空列表表示未标注）。
  final List<AnnotatedScriptStep> script;

  /// 是否已标注（难度 + 脚本）。
  bool get isAnnotated => difficulty != null && script.isNotEmpty;

  /// 题面提示数。
  int get givenCount {
    int count = 0;
    for (final int code in puzzle81.codeUnits) {
      if (code != kEmptyChar.codeUnitAt(0)) {
        count++;
      }
    }
    return count;
  }

  /// 序列化为 JSON map。
  ///
  /// [includeScript] 为 `false` 时跳过 `script` 字段（自由练习题库
  /// export-bank 使用；单题体积约缩小 30 倍）。教学关/试炼池等仍默认携带。
  Map<String, Object?> toJson({bool includeScript = true}) =>
      <String, Object?>{
        'puzzle81': puzzle81,
        'solution81': solution81,
        if (givenMask != null) 'givenMask': givenMask,
        'seed': seed,
        'fingerprint': fingerprint,
        'givenCount': givenCount,
        'difficulty': difficulty?.id,
        'hardestTechnique': hardestTechnique?.id,
        'stepCount': stepCount,
        'techniques': <String>[
          for (final TechniqueId id in techniques) id.id,
        ],
        'usageCounts': <String, int>{
          for (final MapEntry<TechniqueId, int> e in usageCounts.entries)
            e.key.id: e.value,
        },
        if (script.isNotEmpty && includeScript)
          'script': <Map<String, Object?>>[
            for (final AnnotatedScriptStep step in script) step.toJson(),
          ],
      };

  /// 由 JSON map 反序列化。
  static AnnotatedPuzzle fromJson(Map<String, Object?> json) {
    final List<String> techIds = <String>[
      for (final Object? v in (json['techniques'] as List<Object?>? ?? const <Object?>[]))
        v! as String,
    ];
    final Map<String, Object?> rawCounts =
        (json['usageCounts'] as Map<String, Object?>?) ?? const <String, Object?>{};
    final List<Object?> rawSteps =
        (json['script'] as List<Object?>?) ?? const <Object?>[];
    return AnnotatedPuzzle(
      puzzle81: json['puzzle81']! as String,
      solution81: json['solution81']! as String,
      givenMask: json['givenMask'] as String?,
      seed: json['seed']! as int,
      fingerprint: json['fingerprint']! as String,
      difficulty: json['difficulty'] == null
          ? null
          : Difficulty.tryParse(json['difficulty']! as String),
      hardestTechnique: json['hardestTechnique'] == null
          ? null
          : TechniqueId.tryParse(json['hardestTechnique']! as String),
      stepCount: (json['stepCount'] as int?) ?? 0,
      techniques: <TechniqueId>{
        for (final String id in techIds) TechniqueId.parse(id),
      },
      usageCounts: <TechniqueId, int>{
        for (final MapEntry<String, Object?> e in rawCounts.entries)
          TechniqueId.parse(e.key): e.value! as int,
      },
      script: <AnnotatedScriptStep>[
        for (final Object? item in rawSteps)
          AnnotatedScriptStep.fromJson(item! as Map<String, Object?>),
      ],
    );
  }

  @override
  String toString() =>
      'AnnotatedPuzzle(givens=$givenCount, difficulty=${difficulty?.id ?? "-"}, '
      'steps=$stepCount, seed=$seed)';
}

/// 由 `sudoku_core` 的一次求解产出与分级报告，装配一道完整标注题。
///
/// 纯组装，零算法：所有求解/分级/指纹结果均来自入参。
AnnotatedPuzzle assembleAnnotated({
  required Puzzle puzzle,
  required int seed,
  required StepwiseSolveOutcome outcome,
  required GradingReport report,
}) =>
    AnnotatedPuzzle(
      puzzle81: puzzle.givenString,
      solution81: puzzle.solutionString,
      givenMask: puzzle.toGivenBoard().toGivenMaskString(),
      seed: seed,
      fingerprint: Fingerprint.ofValues(puzzle.given),
      difficulty: report.difficulty,
      hardestTechnique: report.hardestTechnique,
      stepCount: report.stepCount,
      techniques: report.usedTechniques.toSet(),
      usageCounts: report.usageCounts,
      script: <AnnotatedScriptStep>[
        for (final SolveStep step in outcome.steps)
          AnnotatedScriptStep.fromCore(step),
      ],
    );

/// 渲染一步技巧的中文讲解句（复用 `sudoku_core` 模板表，零硬编码文案）。
///
/// 模板表中无对应条目时返回 `null`（脚本的 `narration` 字段留空，不阻断导出）。
String? renderNarration(TechniqueId id, TechniqueResult result) {
  final String? pattern = zhCnTemplates[id];
  if (pattern == null) {
    return null;
  }
  return NarrationTemplate(pattern).render(result.narration.slots);
}

/// 由已生成的题面（未标注）快速构造一个仅含题面/终局解的条目。
AnnotatedPuzzle fromPuzzleOnly({
  required Puzzle puzzle,
  required int seed,
}) =>
    AnnotatedPuzzle(
      puzzle81: puzzle.givenString,
      solution81: puzzle.solutionString,
      givenMask: puzzle.toGivenBoard().toGivenMaskString(),
      seed: seed,
      fingerprint: Fingerprint.ofValues(puzzle.given),
    );
