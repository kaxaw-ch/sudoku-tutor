/// 提示状态 `HintState` —— 一次提示请求的裁剪产物（T-DOM-05）。
///
/// ⚠️ **结构上不包含任何「某格填几」的字段**（无 [Placement]）：
/// - 一级/二级：只携带技巧名 + 高亮格 + 可视化（模式格高亮）；
/// - 三级：携带删数结论 [eliminations]（候选删除），仍非填数；
/// - 专项测试断言本类型不存在把答案直出的途径。
library;

import 'package:sudoku_tutor/core/core.dart';

import 'hint_level.dart';

/// 一次提示的不可变结果。
class HintState {
  /// 构造提示结果。
  const HintState({
    required this.level,
    required this.scope,
    required this.techniqueId,
    required this.narration,
    required this.highlightedCells,
    required this.eliminations,
    required this.visual,
    this.sceneFingerprint = '',
  });

  /// 本提示的级别。
  final HintLevel level;

  /// 请求场景（决定最高开放级别）。
  final HintScope scope;

  /// 命中的技巧。
  final TechniqueId techniqueId;

  /// 简体中文讲解（按级别裁剪，绝不出现「某格填几」句式）。
  final String narration;

  /// 需要高亮的格索引（升序去重）。
  final List<int> highlightedCells;

  /// 删数结论（候选删除；仅三级非空，一级/二级恒为空）。
  final List<Elimination> eliminations;

  /// 可视化数据（模式格高亮；已剔除目标格/填数语义标记）。
  final VisualHint visual;

  /// 本提示所属推理步骤的稳定指纹。
  ///
  /// 同一指纹的一级/二级/三级属于同一个递进场景；指纹变化时，UI 应
  /// 清空上一场景的提示历史并从一级重新展示。
  final String sceneFingerprint;

  /// 是否携带删数结论。
  bool get hasEliminations => eliminations.isNotEmpty;

  /// 是否已达到本场景最高级别（教学三级 / 练习两级）。
  bool get isMaxLevel => level.order == HintRules.maxLevelOf(scope);

  /// 技巧中文名（一级/二级文案复用）。
  String get techniqueZhName => techniqueId.zhName;
}
