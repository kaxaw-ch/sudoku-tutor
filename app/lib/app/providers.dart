/// 根 Provider 与 override（测试可替换 Repository）。
///
/// 批次 A 只提供**引擎门面**与**应用信息**两个最基础的 Provider，
/// 供 M0 冒烟页验证「Flutter 层能正确调用纯 Dart 算法层」这一分层契约。
/// 存档、课程、对局等 Provider 分别在批次 E/F 于各自模块内定义。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/core/core.dart';

/// 应用名称（用于 AppBar 与关于页）。
const String kAppName = '数独教学';

/// 算法层版本自检信息。
///
/// 该 Provider 的存在本身就是分层契约的运行时证据：
/// UI 通过 `core/core.dart` barrel 访问 `sudoku_core`，
/// 而 `sudoku_core` 完全不知道 Flutter 的存在。
final Provider<CoreStatus> coreStatusProvider = Provider<CoreStatus>(
  (Ref ref) => CoreStatus.probe(),
);

/// 算法层连通性自检结果（纯数据，可直接渲染）。
class CoreStatus {
  /// 构造自检结果。
  const CoreStatus({
    required this.techniqueTotal,
    required this.techniqueRegistered,
    required this.ruleSetT1Size,
    required this.ruleSetT2Size,
    required this.sampleSolved,
  });

  /// 探测一次算法层状态。
  factory CoreStatus.probe() {
    final TechniqueRegistry registry = TechniqueRegistry.defaults();
    // 一道公开的简单题，用于验证求解链路在 App 进程内可用。
    const String sample =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    const BacktrackingSolver solver = BacktrackingSolver();
    final List<int>? solution =
        solver.solveFirst(Board.fromPuzzleString(sample));
    return CoreStatus(
      techniqueTotal: TechniqueId.values.length,
      techniqueRegistered: registry.length,
      ruleSetT1Size: RuleSet.t1().length,
      ruleSetT2Size: RuleSet.t2().length,
      sampleSolved: solution != null && Validator.isValidSolution(solution),
    );
  }

  /// 技巧总数（应为 16）。
  final int techniqueTotal;

  /// 已注册识别器数量（批次 C 逐项补齐到 16）。
  final int techniqueRegistered;

  /// T1 规则集大小（应为 13）。
  final int ruleSetT1Size;

  /// T2 规则集大小（应为 16）。
  final int ruleSetT2Size;

  /// 样例题是否被成功求解。
  final bool sampleSolved;

  /// 简体中文摘要。
  String get zhSummary => '技巧 $techniqueRegistered/$techniqueTotal 已注册 · '
      'T1=$ruleSetT1Size / T2=$ruleSetT2Size · '
      '求解自检${sampleSolved ? "通过" : "失败"}';
}
