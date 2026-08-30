/// 核对答案服务 —— 一键核对，**只标错、不纠正、不透露空格**（P0-PRA-03）。
///
/// 口径（T-DOM-04 验收）：
/// - 逐格对比当前盘面与终局解，找出**填错**的格（含玩家填错的格）；
/// - 只返回「错误格集合」，**绝不**直接改盘面 / 擦除错误 / 填入正确数；
/// - 空格不参与核对（空格不是错误，不透露空格）；
/// - 同时统计正确格数与错误格数（计入统计，P0-STO-03 原始采集）。
library;

import 'package:sudoku_tutor/core/core.dart';

/// 一次核对的结果。
class CheckResult {
  /// 构造核对结果。
  const CheckResult({
    required this.wrongCells,
    required this.correctCount,
    required this.wrongCount,
  });

  /// 填错的格索引集合（已填且 ≠ 终局解；升序）。
  final Set<int> wrongCells;

  /// 已填且正确的格数。
  final int correctCount;

  /// 已填且错误的格数。
  final int wrongCount;
}

/// 核对答案服务（无状态，纯函数式）。
abstract final class CheckAnswerService {
  /// 核对 [board] 与 [solution]。
  ///
  /// - [solution] 为 `null` 时（旧断点无终局解）返回空错误集、计数 0，
  ///   即「无法核对」的降级语义，不抛异常；
  /// - [markErrors] 由调用方决定错误集是否标红，本服务只产出结果。
  static CheckResult check(Board board, List<int>? solution) {
    if (solution == null || solution.length != kCellCount) {
      return const CheckResult(
        wrongCells: <int>{},
        correctCount: 0,
        wrongCount: 0,
      );
    }
    final Set<int> wrong = <int>{};
    int correct = 0;
    for (int i = 0; i < kCellCount; i++) {
      final int value = board.values[i];
      if (value == kEmptyValue) {
        continue; // 空格不参与核对。
      }
      if (value == solution[i]) {
        correct++;
      } else {
        wrong.add(i);
      }
    }
    return CheckResult(
      wrongCells: wrong,
      correctCount: correct,
      wrongCount: wrong.length,
    );
  }
}
