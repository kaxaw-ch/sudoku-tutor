/// 识别器单测公共夹具：**纯候选沙盘**。
///
/// 为什么不用真实题面：16 项技巧中有 9 项要求非常特定的候选分布，
/// 用真实题面构造既难以手工验证、又容易掺入无关技巧的干扰。
/// 沙盘做法是：81 格全部为空、`givenMask` 全 false，
/// 只在**指定格**写入指定候选；其余格候选掩码为 0，
/// 由于所有识别器都以 `candidatesAt(index).contains(digit)` 为准入条件，
/// 掩码为 0 的格对任何扫描都是「不存在」，从而得到完全可控、可手算验证的输入。
///
/// ⚠️ 沙盘只用于**识别器单项**测试；逐级求解 / 难度分级使用真实题面。
library;

import 'package:sudoku_core/sudoku_core.dart';

/// 由 `格索引 -> 候选数字列表` 构造纯候选沙盘。
Board candidateBoard(Map<int, List<int>> candidates) {
  final Board board = Board.empty();
  candidates.forEach((int index, List<int> digits) {
    board.setCandidates(index, CandidateSet.fromDigits(digits));
  });
  return board;
}

/// 0 基行列 → 格索引（与 `Coord.indexOf` 同义，测试里书写更短）。
int rc(int row, int col) => Coord.indexOf(row, col);

/// 构造只读求解上下文。
SolveContext contextOf(
  Board board, {
  RuleSet? ruleSet,
  bool uniqueSolutionGuaranteed = true,
  List<int>? solution,
}) =>
    SolveContext(
      board: board,
      ruleSet: ruleSet ?? RuleSet.t2(),
      uniqueSolutionGuaranteed: uniqueSolutionGuaranteed,
      solution: solution,
    );

/// 一次性构造沙盘上下文。
SolveContext sandbox(
  Map<int, List<int>> candidates, {
  RuleSet? ruleSet,
  bool uniqueSolutionGuaranteed = true,
  List<int>? solution,
}) =>
    contextOf(
      candidateBoard(candidates),
      ruleSet: ruleSet,
      uniqueSolutionGuaranteed: uniqueSolutionGuaranteed,
      solution: solution,
    );

/// 扫描技巧并返回全部结论（默认放开 limit，便于断言「包含 / 不含」）。
List<TechniqueResult> scan(Technique technique, SolveContext ctx, {int limit = 32}) =>
    technique.find(ctx, limit: limit).toList(growable: false);

/// 全部结论中的删数条目（`格:数字` 字符串集合，便于集合断言）。
Set<String> allEliminationKeys(Iterable<TechniqueResult> results) => <String>{
      for (final TechniqueResult r in results)
        for (final Elimination e in r.eliminations) '${e.cellIndex}:${e.digit}',
    };

/// 全部结论中的填数条目（`格=数字` 字符串集合）。
Set<String> allPlacementKeys(Iterable<TechniqueResult> results) => <String>{
      for (final TechniqueResult r in results)
        for (final Placement p in r.placements) '${p.cellIndex}=${p.digit}',
    };

/// 删数条目键。
String elimKey(int cellIndex, int digit) => '$cellIndex:$digit';

/// 填数条目键。
String placeKey(int cellIndex, int digit) => '$cellIndex=$digit';

/// 取第一条含指定删数的结论；找不到返回 `null`。
TechniqueResult? resultWithElimination(
  Iterable<TechniqueResult> results,
  int cellIndex,
  int digit,
) {
  for (final TechniqueResult r in results) {
    for (final Elimination e in r.eliminations) {
      if (e.cellIndex == cellIndex && e.digit == digit) {
        return r;
      }
    }
  }
  return null;
}

/// 由 81 字符解答串构造 `List<int>`（用于 `SanityGuard` / `SolveContext.solution`）。
List<int> solutionOf(String s81) => <int>[
      for (int i = 0; i < s81.length; i++) int.parse(s81[i]),
    ];

/// 造一份「除 [cellIndex] 外全部为 1」的伪终局解，令 `solution[cellIndex] == digit`。
///
/// 只用于验证 `SanityGuard` 降级路径，不要求它是一个合法数独解 ——
/// `SanityGuard.collectViolations` 只做逐格比对，不校验数独合法性。
List<int> fakeSolutionWith(int cellIndex, int digit) {
  final List<int> solution = List<int>.filled(kCellCount, 1);
  solution[cellIndex] = digit;
  return solution;
}

/// 断言用：结论是否携带完整的可视化与讲解数据（doc 06 P0-ENG-09/10 铁律）。
bool hasCompleteHintPayload(TechniqueResult result) =>
    result.visual.isNotEmpty &&
    result.narration.slots.isNotEmpty &&
    result.fingerprint.isNotEmpty;
