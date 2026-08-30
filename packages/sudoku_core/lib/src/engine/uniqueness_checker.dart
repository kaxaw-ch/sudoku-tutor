/// 唯一解校验封装（UR 前提校验、导入题校验、生成器挖洞共用）。
///
/// 存在意义（doc 06 §3.1）：把「盘面是否恰有一个解」这一高频判定
/// 收敛到一处，避免各处散落 `countSolutions(stopAt: 2) == 1` 的口径漂移。
library;

import '../model/board.dart';
import '../util/core_error.dart';
import 'backtracking_solver.dart';

/// 唯一解判定结果。
enum UniquenessVerdict {
  /// 无解。
  none('none', '无解'),

  /// 恰有唯一解。
  unique('unique', '唯一解'),

  /// 存在两个及以上的解。
  multiple('multiple', '多解');

  const UniquenessVerdict(this.id, this.zhName);

  /// 稳定标识（JSON / 日志用）。
  final String id;

  /// 简体中文名。
  final String zhName;

  /// 是否为唯一解。
  bool get isUnique => this == UniquenessVerdict.unique;
}

/// 唯一解校验器（无状态，可安全复用同一实例）。
class UniquenessChecker {
  /// 构造校验器；[solver] 省略时使用默认确定性求解器（无随机）。
  const UniquenessChecker({BacktrackingSolver solver = const BacktrackingSolver()})
      : _solver = solver;

  final BacktrackingSolver _solver;

  /// 判定盘面的解数情况。
  UniquenessVerdict verdictOf(Board board) =>
      verdictOfValues(board.toValueList());

  /// 判定数值列表的解数情况。
  UniquenessVerdict verdictOfValues(List<int> values) {
    final int count = _solver.countSolutionsOfValues(values, stopAt: 2);
    return switch (count) {
      0 => UniquenessVerdict.none,
      1 => UniquenessVerdict.unique,
      _ => UniquenessVerdict.multiple,
    };
  }

  /// 盘面是否恰有唯一解。
  bool isUnique(Board board) => verdictOf(board).isUnique;

  /// 数值列表是否恰有唯一解。
  bool isUniqueValues(List<int> values) => verdictOfValues(values).isUnique;

  /// 求出唯一解；无解或多解时返回 `null`。
  List<int>? uniqueSolutionOf(Board board) {
    final List<int> values = board.toValueList();
    if (!isUniqueValues(values)) {
      return null;
    }
    return _solver.solveValues(values);
  }

  /// 校验盘面唯一解，不满足时抛 `E_SOLVE_001` / `E_SOLVE_002`。
  ///
  /// 供题目导入（PRD P0-PRA-10）与 CLI 出题管线使用。
  void requireUnique(Board board) {
    switch (verdictOf(board)) {
      case UniquenessVerdict.none:
        throw const CoreException(CoreErrorCode.solveNoSolution);
      case UniquenessVerdict.multiple:
        throw const CoreException(CoreErrorCode.solveMultipleSolutions);
      case UniquenessVerdict.unique:
        return;
    }
  }
}
