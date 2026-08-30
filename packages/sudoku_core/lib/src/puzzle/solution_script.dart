/// 解题脚本模型（T-CORE-09：doc 07 §3 批次 C）。
///
/// 职责：
/// - [ScriptStep]：**一步** = 技巧 ID + 涉及格 + 删数 + 填数 + 中文旁白 + [VisualHint]，
///   字段语义与 CLI 侧 `AnnotatedScriptStep`（批次 D）逐一对齐；
/// - [SolutionScript]：步骤序列容器（`stepCount` 为派生字段）。
///
/// JSON 形态（⚠️ 关键差异，三方对照见文件头注释）：
/// - **关卡 JSON**（doc 06 §4.3 权威 schema / export-level 产物）：`script` 是**对象**
///   `{"steps": [ {order, techniqueId, involvedCells, eliminations, placements,
///   narration, visual} ... ]}`；`eliminations/placements` 的格索引字段用 **`cell`**；
/// - **题库/标注集合 JSON**（export-bank / annotate 产物，CLI `AnnotatedPuzzle.toJson`）：
///   `script` 是**数组** `[ {order, ...} ... ]`，`eliminations/placements` 用 **`cellIndex`**；
/// - 本模型的 toJson/fromJson 同时支持两种形态：
///   写侧默认输出关卡形态（`cell` 键），读侧对 `cell`/`cellIndex` 双兼容。
///
/// `visual` 直接复用 `sudoku_core` 的 [VisualHint] 强类型（其 JSON 与 CLI 产物一致：
/// `cells[].focusDigits`、`candidateMarks[].cellIndex`），保证 UI「零推断」口径不丢字段。
library;

import 'package:meta/meta.dart';

import '../techniques/technique_id.dart';
import '../techniques/technique_result.dart';
import '../visual/visual_hint.dart';

/// 解题脚本中的一步。
@immutable
class ScriptStep {
  /// 构造一步脚本。
  ///
  /// [visual] 省略时为空可视化数据。
  ScriptStep({
    required this.order,
    required this.techniqueId,
    List<Elimination> eliminations = const <Elimination>[],
    List<Placement> placements = const <Placement>[],
    List<int> involvedCells = const <int>[],
    this.narration,
    VisualHint? visual,
  })  : eliminations = List<Elimination>.unmodifiable(eliminations),
        placements = List<Placement>.unmodifiable(placements),
        involvedCells = List<int>.unmodifiable(involvedCells),
        visual = visual ?? VisualHint.empty();

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

  /// 渲染好的中文讲解句（可空；由 `sudoku_core` 的叙事模板渲染得到）。
  final String? narration;

  /// 本步可视化数据（UI 零推断的坐标来源）。
  final VisualHint visual;

  /// 是否有实际结论（删数或填数）。
  bool get hasConclusion => eliminations.isNotEmpty || placements.isNotEmpty;

  /// 序列化为 JSON map（**关卡形态**：`cell` 键，对齐 doc 06 §4.3 / export-level 产物）。
  Map<String, Object?> toJson() => <String, Object?>{
        'order': order,
        'techniqueId': techniqueId.id,
        'involvedCells': List<int>.of(involvedCells),
        'eliminations': <Map<String, Object?>>[
          for (final Elimination e in eliminations)
            <String, Object?>{'cell': e.cellIndex, 'digit': e.digit},
        ],
        'placements': <Map<String, Object?>>[
          for (final Placement p in placements)
            <String, Object?>{'cell': p.cellIndex, 'digit': p.digit},
        ],
        'narration': narration,
        'visual': visual.toJson(),
      };

  /// 由 JSON map 反序列化。
  ///
  /// 兼容 `cell` 与 `cellIndex` 两种格索引键（题库 JSON 用 `cellIndex`）。
  static ScriptStep fromJson(Map<String, Object?> json) => ScriptStep(
        order: json['order']! as int,
        techniqueId: TechniqueId.parse(json['techniqueId']! as String),
        eliminations: <Elimination>[
          for (final Object? item
              in (json['eliminations'] as List<Object?>? ?? const <Object?>[]))
            Elimination.fromJson(_withCellKey(item! as Map<String, Object?>)),
        ],
        placements: <Placement>[
          for (final Object? item
              in (json['placements'] as List<Object?>? ?? const <Object?>[]))
            Placement.fromJson(_withCellKey(item! as Map<String, Object?>)),
        ],
        involvedCells: <int>[
          for (final Object? v
              in (json['involvedCells'] as List<Object?>? ?? const <Object?>[]))
            v! as int,
        ],
        narration: json['narration'] as String?,
        visual: json['visual'] == null
            ? null
            : VisualHint.fromJson(json['visual']! as Map<String, Object?>),
      );

  /// 把 `{cell: ...}` 归一为 core 内部 `{cellIndex: ...}` 键（读侧双兼容）。
  static Map<String, Object?> _withCellKey(Map<String, Object?> raw) {
    final Object? cell = raw['cellIndex'] ?? raw['cell'];
    if (cell == null || raw.containsKey('cellIndex')) {
      return raw;
    }
    return <String, Object?>{...raw, 'cellIndex': cell};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScriptStep &&
          other.order == order &&
          other.techniqueId == techniqueId &&
          _sameElims(other.eliminations, eliminations) &&
          _samePlaces(other.placements, placements) &&
          other.narration == narration &&
          other.visual == visual);

  static bool _sameElims(List<Elimination> a, List<Elimination> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _samePlaces(List<Placement> a, List<Placement> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        order,
        techniqueId,
        Object.hashAll(eliminations),
        Object.hashAll(placements),
        narration,
        visual,
      );

  @override
  String toString() => '#$order ${techniqueId.id}'
      '（删 ${eliminations.length}，填 ${placements.length}）';
}

/// 一段完整解题脚本（步骤序列）。
@immutable
class SolutionScript {
  /// 构造脚本；[steps] 做不可变拷贝。
  SolutionScript({List<ScriptStep> steps = const <ScriptStep>[]})
      : steps = List<ScriptStep>.unmodifiable(steps);

  /// 步骤序列（按应用顺序）。
  final List<ScriptStep> steps;

  /// 步数（对齐 doc 06 §4.3 `SolutionScript.stepCount`）。
  int get stepCount => steps.length;

  /// 是否为空脚本。
  bool get isEmpty => steps.isEmpty;

  /// 是否含至少一步。
  bool get isNotEmpty => steps.isNotEmpty;

  /// 用到的全部技巧（按 rank 升序去重）。
  Set<TechniqueId> get usedTechniques => <TechniqueId>{
        for (final ScriptStep step in steps) step.techniqueId,
      };

  /// 序列化为**关卡形态** JSON（对象 `{steps, stepCount}`，对齐 doc 06 §4.3）。
  Map<String, Object?> toJson() => <String, Object?>{
        'steps': <Map<String, Object?>>[
          for (final ScriptStep step in steps) step.toJson(),
        ],
        'stepCount': stepCount,
      };

  /// 由**关卡形态** JSON（对象）反序列化；`steps` 缺失时按 [stepCount] 兜底为空脚本。
  static SolutionScript fromJson(Map<String, Object?> json) =>
      SolutionScript(
        steps: <ScriptStep>[
          for (final Object? item
              in (json['steps'] as List<Object?>? ?? const <Object?>[]))
            ScriptStep.fromJson(item! as Map<String, Object?>),
        ],
      );

  /// 序列化为**题库形态** JSON（数组，对齐 CLI `AnnotatedPuzzle.toJson().script`）。
  List<Map<String, Object?>> toStepJsonList() => <Map<String, Object?>>[
        for (final ScriptStep step in steps) step.toJson(),
      ];

  /// 由**题库形态** JSON（数组）反序列化。
  static SolutionScript fromStepJsonList(List<Object?> rawSteps) =>
      SolutionScript(
        steps: <ScriptStep>[
          for (final Object? item in rawSteps)
            ScriptStep.fromJson(item! as Map<String, Object?>),
        ],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SolutionScript && _sameSteps(other.steps, steps));

  static bool _sameSteps(List<ScriptStep> a, List<ScriptStep> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);

  @override
  String toString() => 'SolutionScript(steps=$stepCount)';
}
