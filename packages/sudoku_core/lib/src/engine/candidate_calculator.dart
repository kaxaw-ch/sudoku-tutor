/// 候选数全量计算 + 填数/清除时的增量同步（P0-ENG-04）。
///
/// 一致性契约（doc 07 T-CORE-02 验收项）：
/// 任意操作序列后，增量同步的结果必须与 [CandidateCalculator.recomputeAll] **逐格一致**。
library;

import '../model/board.dart';
import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../model/peers.dart';
import '../util/bit_ops.dart';

/// 候选数计算器（全部为静态纯函数，直接原地修改传入盘面的候选位）。
abstract final class CandidateCalculator {
  /// 全量重算 81 格候选。
  ///
  /// 规则：已填格候选恒为空集；空格候选 = 全集减去同行/列/宫已出现的数字。
  static void recomputeAll(Board board) {
    for (int index = 0; index < kCellCount; index++) {
      board.candidateMasks[index] =
          board.values[index] == kEmptyValue ? _allowedMask(board, index) : 0;
    }
  }

  /// 计算格 [index] 在当前盘面下**应有**的候选集（不写回盘面）。
  static CandidateSet candidatesFor(Board board, int index) {
    Coord.requireIndex(index);
    if (board.values[index] != kEmptyValue) {
      return CandidateSet.none;
    }
    return CandidateSet(_allowedMask(board, index));
  }

  /// 重算单格候选并写回。
  static void recomputeCell(Board board, int index) {
    Coord.requireIndex(index);
    board.candidateMasks[index] =
        board.values[index] == kEmptyValue ? _allowedMask(board, index) : 0;
  }

  /// 在格 [index] 填入 [digit] **之后**的增量同步。
  ///
  /// 调用前提：`board.values[index]` 已被置为 [digit]。
  /// 效果：本格候选清空；同行/列/宫全部空格删去候选 [digit]。
  static void syncAfterPlace(Board board, int index, int digit) {
    Coord.requireIndex(index);
    Digit.requireDigit(digit);
    board.candidateMasks[index] = 0;
    final int clearBit = ~BitOps.bitOf(digit);
    for (final int peer in Peers.peersOf(index)) {
      if (board.values[peer] == kEmptyValue) {
        board.candidateMasks[peer] &= clearBit;
      }
    }
  }

  /// 清除格 [index] **之后**的增量同步。
  ///
  /// 调用前提：`board.values[index]` 已被置为 0。
  /// 效果：重算本格与其 20 个 peer 的候选。
  ///
  /// 说明：清除会让被清数字重新对 peer 可用，而 peer 是否可用还取决于
  /// 其余两条单元线，故此处按「本格 + peers」局部重算，
  /// 21 格 × 20 peer 的常数开销远小于全盘 81 格重算，且与全量结果严格一致。
  static void syncAfterClear(Board board, int index) {
    Coord.requireIndex(index);
    recomputeCell(board, index);
    for (final int peer in Peers.peersOf(index)) {
      recomputeCell(board, peer);
    }
  }

  /// 校验盘面当前候选是否与全量重算结果一致（测试与 CI 用）。
  ///
  /// 返回不一致的格索引列表（升序）；完全一致时返回空列表。
  static List<int> findInconsistentCells(Board board) {
    final List<int> mismatched = <int>[];
    for (int index = 0; index < kCellCount; index++) {
      final int expected =
          board.values[index] == kEmptyValue ? _allowedMask(board, index) : 0;
      if (board.candidateMasks[index] != expected) {
        mismatched.add(index);
      }
    }
    return mismatched;
  }

  /// 盘面候选是否与全量重算结果完全一致。
  static bool isConsistent(Board board) => findInconsistentCells(board).isEmpty;

  /// 是否存在「空格却无任何候选」的死格（用于早期矛盾检测）。
  static bool hasDeadCell(Board board) {
    for (int index = 0; index < kCellCount; index++) {
      if (board.values[index] == kEmptyValue && board.candidateMasks[index] == 0) {
        return true;
      }
    }
    return false;
  }

  /// 计算格 [index] 允许的候选掩码（不判断该格是否已填）。
  static int _allowedMask(Board board, int index) {
    int used = 0;
    for (final int peer in Peers.peersOf(index)) {
      final int value = board.values[peer];
      if (value != kEmptyValue) {
        used |= BitOps.bitOf(value);
      }
    }
    return BitOps.fullMask & ~used;
  }
}
