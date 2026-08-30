/// 随机终盘生成 + 挖洞 + 唯一解保持（P0-ENG-06）。
///
/// 算法流程（doc 07 T-CORE-03）：
///   1. [PuzzleGenerator.generateFullSolution] —— 用带随机化的回溯求解器从空盘
///      求出一个随机合法终盘；
///   2. [PuzzleGenerator.digHoles] —— 随机顺序逐格挖洞，**每挖一格立即用
///      `countSolutions(stopAt: 2)` 复验唯一解**，破坏唯一解则回填；
///   3. [PuzzleGenerator.generate] —— 串起前两步，产出 `Puzzle{given, solution}`。
///
/// 可复现性铁律（§7.1）：全部随机走传入的 [Rng]，同 seed 必产出同一道题。
library;

import '../model/board.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../puzzle/puzzle.dart';
import '../util/core_error.dart';
import '../util/rng.dart';
import 'backtracking_solver.dart';
import 'candidate_calculator.dart';
import 'uniqueness_checker.dart';
import 'validator.dart';

/// 挖洞时的对称策略。
///
/// 说明：对称题面更美观，且能显著减少「挖到一半破坏唯一解」的抖动。
enum SymmetryMode {
  /// 无对称，逐格独立挖。
  none('none', '无对称'),

  /// 中心对称：`index` 与 `80 - index` 成对挖。
  central('central', '中心对称');

  const SymmetryMode(this.id, this.zhName);

  /// 稳定标识。
  final String id;

  /// 简体中文名。
  final String zhName;
}

/// 谜题生成器。
///
/// 无可变字段，可安全复用同一实例；随机性完全由调用时传入的 [Rng] 决定。
class PuzzleGenerator {
  /// 构造生成器。
  const PuzzleGenerator({
    UniquenessChecker checker = const UniquenessChecker(),
  }) : _checker = checker;

  final UniquenessChecker _checker;

  /// 题面提示数的下限（数学下界为 17，低于此值必非唯一解）。
  static const int kMinGivens = 17;

  /// 挖洞失败时的最大重试轮数（换一副终盘重来）。
  static const int kMaxRestart = 8;

  // ---------------------------------------------------------------- 终盘

  /// 生成一副随机合法终盘（81 个 1..9）。
  ///
  /// 实现：以 [rng] 驱动的回溯求解器从空盘求首解；数独空盘必然有解，
  /// 故正常情况下不会返回失败。理论上不可达的失败路径抛 `E_SOLVE_001`。
  List<int> generateFullSolution(Rng rng) {
    final BacktrackingSolver solver = BacktrackingSolver(rng: rng);
    final List<int>? solution =
        solver.solveValues(List<int>.filled(kCellCount, kEmptyValue));
    if (solution == null || !Validator.isValidSolution(solution)) {
      throw const CoreException(CoreErrorCode.solveNoSolution, '终盘生成失败');
    }
    return solution;
  }

  /// [generateFullSolution] 的盘面形态（全部格标记为给定）。
  Board generateFullSolutionBoard(Rng rng) =>
      Board.fromValues(generateFullSolution(rng));

  // ---------------------------------------------------------------- 挖洞

  /// 从终盘 [solution] 挖洞，尽量把提示数降到 [targetGivens]。
  ///
  /// - 逐格尝试清空，清空后若解不再唯一则**立即回填**；
  /// - [symmetry] 为 [SymmetryMode.central] 时按中心对称成对挖，
  ///   成对挖破坏唯一解则整对回填；
  /// - 返回长度 81 的题面数值列表（0 = 空），**保证唯一解**；
  /// - 达不到 [targetGivens] 时返回当前能挖到的最少提示数结果（不抛异常），
  ///   由调用方（CLI 管线）决定是否换 seed 重试。
  List<int> digHoles(
    List<int> solution,
    int targetGivens,
    Rng rng, {
    SymmetryMode symmetry = SymmetryMode.none,
  }) {
    if (solution.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        'solution 长度 ${solution.length}，期望 $kCellCount',
      );
    }
    if (!Validator.isValidSolution(solution)) {
      throw const CoreException(CoreErrorCode.boardInconsistent, '传入的终盘不合法');
    }

    final int floor = targetGivens < kMinGivens ? kMinGivens : targetGivens;
    final List<int> working = List<int>.of(solution);
    int remaining = kCellCount;

    for (final List<int> group in _digOrder(rng, symmetry)) {
      if (remaining <= floor) {
        break;
      }
      // 跳过已经空掉的格（中心对称时对子可能已被处理）。
      final List<int> filled = <int>[
        for (final int index in group)
          if (working[index] != kEmptyValue) index,
      ];
      if (filled.isEmpty) {
        continue;
      }
      if (remaining - filled.length < floor) {
        continue;
      }

      final List<int> backup = <int>[for (final int index in filled) working[index]];
      for (final int index in filled) {
        working[index] = kEmptyValue;
      }

      if (_checker.isUniqueValues(working)) {
        remaining -= filled.length;
      } else {
        for (int i = 0; i < filled.length; i++) {
          working[filled[i]] = backup[i];
        }
      }
    }
    return working;
  }

  /// 完整生成一道题目。
  ///
  /// - [targetGivens] 为期望提示数（会被钳制到不低于 [kMinGivens]）；
  /// - 若 [requireExactTarget] 为 true，则在挖不到目标提示数时最多重试
  ///   [kMaxRestart] 轮（每轮换一副终盘）；仍失败则返回最优的一次结果。
  Puzzle generate(
    Rng rng, {
    int targetGivens = 30,
    SymmetryMode symmetry = SymmetryMode.none,
    bool requireExactTarget = false,
  }) {
    Puzzle? best;
    final int rounds = requireExactTarget ? kMaxRestart : 1;

    for (int attempt = 0; attempt < rounds; attempt++) {
      final Rng roundRng = attempt == 0 ? rng : rng.derive(attempt);
      final List<int> solution = generateFullSolution(roundRng);
      final List<int> given =
          digHoles(solution, targetGivens, roundRng, symmetry: symmetry);
      final Puzzle candidate = Puzzle(
        given: given,
        solution: solution,
        seed: rng.seed,
      );
      if (best == null || candidate.givenCount < best.givenCount) {
        best = candidate;
      }
      if (candidate.givenCount <= targetGivens) {
        return candidate;
      }
    }
    // rounds >= 1 保证 best 必不为空。
    return best!;
  }

  /// 生成一个**可直接对局**的盘面：`givenMask` 已固化、候选已算好。
  Board generateBoard(
    Rng rng, {
    int targetGivens = 30,
    SymmetryMode symmetry = SymmetryMode.none,
  }) {
    final Puzzle puzzle =
        generate(rng, targetGivens: targetGivens, symmetry: symmetry);
    final Board board = puzzle.toGivenBoard();
    CandidateCalculator.recomputeAll(board);
    return board;
  }

  /// 盘面是否恰有唯一解（转发 [UniquenessChecker]，保持单一口径）。
  bool isUnique(Board board) => _checker.isUnique(board);

  /// 数值列表是否恰有唯一解。
  bool isUniqueValues(List<int> values) => _checker.isUniqueValues(values);

  /// 生成挖洞的访问顺序。
  ///
  /// 返回值的每个元素是「一次挖洞尝试所涉及的格集合」：
  /// 无对称时每组 1 格；中心对称时每组 1–2 格（正中心格 40 自成一组）。
  List<List<int>> _digOrder(Rng rng, SymmetryMode symmetry) {
    switch (symmetry) {
      case SymmetryMode.none:
        final List<int> indices =
            rng.shuffled(List<int>.generate(kCellCount, (int i) => i));
        return <List<int>>[for (final int index in indices) <int>[index]];
      case SymmetryMode.central:
        final List<List<int>> groups = <List<int>>[];
        for (int index = 0; index < kCellCount; index++) {
          final int mirror = kCellCount - 1 - index;
          if (index > mirror) {
            continue;
          }
          groups.add(index == mirror ? <int>[index] : <int>[index, mirror]);
        }
        rng.shuffle(groups);
        return groups;
    }
  }
}
