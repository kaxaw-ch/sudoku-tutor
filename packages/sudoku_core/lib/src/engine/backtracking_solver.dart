/// 回溯求解 + 解数计数（found 2 即中止）（P0-ENG-03）。
///
/// 实现要点：
/// - 行/列/宫各持一个 9 位「已用数字」掩码，落子与回退均为 O(1)；
/// - 选格用 MRV（最少候选优先），显著剪枝，PC 端 p95 < 5ms；
/// - **纯函数无副作用**：不修改传入的 [Board]，全部在内部副本上运算；
/// - 可选 [Rng]：传入时数字尝试顺序随机化，供生成器产出随机终盘。
library;

import 'dart:typed_data';

import '../model/board.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../util/bit_ops.dart';
import '../util/rng.dart';

/// 回溯求解器。
class BacktrackingSolver {
  /// 构造求解器；[rng] 非空时数字尝试顺序随机化（用于生成随机终盘）。
  const BacktrackingSolver({this.rng});

  /// 可复现随机源，可为空（为空时按 1..9 升序尝试，结果确定）。
  final Rng? rng;

  /// 求出第一个解；无解返回 `null`。
  ///
  /// 返回值为长度 81 的数值列表（1..9），不修改 [board]。
  List<int>? solveFirst(Board board) => solveValues(board.toValueList());

  /// 在数值列表上求出第一个解；无解返回 `null`。
  List<int>? solveValues(List<int> values) {
    final _SolverState? state = _SolverState.tryCreate(values);
    if (state == null) {
      return null;
    }
    final List<int>? found = _search(state, stopAt: 1);
    return found;
  }

  /// 统计解的个数，最多数到 [stopAt] 即中止（默认 2，用于唯一解校验）。
  int countSolutions(Board board, {int stopAt = 2}) =>
      countSolutionsOfValues(board.toValueList(), stopAt: stopAt);

  /// 在数值列表上统计解的个数。
  int countSolutionsOfValues(List<int> values, {int stopAt = 2}) {
    if (stopAt < 1) {
      return 0;
    }
    final _SolverState? state = _SolverState.tryCreate(values);
    if (state == null) {
      return 0;
    }
    state.stopAt = stopAt;
    _search(state, stopAt: stopAt);
    return state.solutionCount;
  }

  /// 盘面是否恰有唯一解。
  bool hasUniqueSolution(Board board) => countSolutions(board, stopAt: 2) == 1;

  /// 数值列表是否恰有唯一解。
  bool hasUniqueSolutionOfValues(List<int> values) =>
      countSolutionsOfValues(values, stopAt: 2) == 1;

  /// 核心搜索：返回首个解的数值列表（[stopAt] 仅控制计数何时中止）。
  List<int>? _search(_SolverState state, {required int stopAt}) {
    final int index = state.pickCell();
    if (index < 0) {
      // 全部填满 → 记一个解。
      state.solutionCount++;
      state.firstSolution ??= List<int>.from(state.values);
      return state.firstSolution;
    }

    final int mask = state.candidateMaskAt(index);
    if (mask == 0) {
      return null;
    }

    final List<int> digits = BitOps.digitsOf(mask).toList(growable: false);
    final List<int> order = rng == null ? digits : rng!.shuffled(digits);
    for (final int digit in order) {
      state.push(index, digit);
      _search(state, stopAt: stopAt);
      state.pop(index, digit);
      if (state.solutionCount >= stopAt) {
        return state.firstSolution;
      }
    }
    return state.firstSolution;
  }
}

/// 求解过程的可变状态（内部实现，不对外暴露）。
class _SolverState {
  _SolverState._(this.values, this.rowUsed, this.colUsed, this.boxUsed);

  /// 由数值列表创建；初始盘面自相矛盾时返回 `null`。
  static _SolverState? tryCreate(List<int> source) {
    if (source.length != kCellCount) {
      return null;
    }
    final Int8List values = Int8List(kCellCount);
    final Uint16List rowUsed = Uint16List(kBoardSize);
    final Uint16List colUsed = Uint16List(kBoardSize);
    final Uint16List boxUsed = Uint16List(kBoardSize);

    for (int index = 0; index < kCellCount; index++) {
      final int value = source[index];
      if (value == kEmptyValue) {
        continue;
      }
      if (value < kMinDigit || value > kMaxDigit) {
        return null;
      }
      final int bit = BitOps.bitOf(value);
      final int row = Coord.rowOf(index);
      final int col = Coord.colOf(index);
      final int box = Coord.boxOf(index);
      if ((rowUsed[row] & bit) != 0 ||
          (colUsed[col] & bit) != 0 ||
          (boxUsed[box] & bit) != 0) {
        return null; // 初始盘面重复数字 → 无解。
      }
      values[index] = value;
      rowUsed[row] |= bit;
      colUsed[col] |= bit;
      boxUsed[box] |= bit;
    }
    return _SolverState._(values, rowUsed, colUsed, boxUsed);
  }

  final Int8List values;
  final Uint16List rowUsed;
  final Uint16List colUsed;
  final Uint16List boxUsed;

  /// 已找到的解数量。
  int solutionCount = 0;

  /// 计数上限。
  int stopAt = 1;

  /// 首个解的快照。
  List<int>? firstSolution;

  /// 格 [index] 当前可填数字的掩码。
  int candidateMaskAt(int index) {
    final int used = rowUsed[Coord.rowOf(index)] |
        colUsed[Coord.colOf(index)] |
        boxUsed[Coord.boxOf(index)];
    return BitOps.fullMask & ~used;
  }

  /// MRV 选格：返回候选最少的空格索引；全部填满返回 -1。
  ///
  /// 一旦发现候选数为 0 的空格（死格），立即返回该格，让上层剪枝。
  int pickCell() {
    int best = -1;
    int bestCount = kMaxDigit + 1;
    for (int index = 0; index < kCellCount; index++) {
      if (values[index] != kEmptyValue) {
        continue;
      }
      final int count = BitOps.popcount(candidateMaskAt(index));
      if (count < bestCount) {
        best = index;
        bestCount = count;
        if (count <= 1) {
          return best;
        }
      }
    }
    return best;
  }

  /// 落子。
  void push(int index, int digit) {
    final int bit = BitOps.bitOf(digit);
    values[index] = digit;
    rowUsed[Coord.rowOf(index)] |= bit;
    colUsed[Coord.colOf(index)] |= bit;
    boxUsed[Coord.boxOf(index)] |= bit;
  }

  /// 回退。
  void pop(int index, int digit) {
    final int bit = ~BitOps.bitOf(digit);
    values[index] = kEmptyValue;
    rowUsed[Coord.rowOf(index)] &= bit;
    colUsed[Coord.colOf(index)] &= bit;
    boxUsed[Coord.boxOf(index)] &= bit;
  }
}
