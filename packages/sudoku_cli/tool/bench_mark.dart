/// 基准测试：随机生成一道题 + 逐级求解定档的耗时（单线程）。
/// 用法: dart run tool/bench_mark.dart
library;

import 'package:sudoku_core/sudoku_core.dart';

void main() {
  const int n = 200; // 生成题数
  final RuleSet ruleSet = RuleSet.t2();

  final gen = PuzzleGenerator();
  final checker = UniquenessChecker();
  final solver = StepwiseSolver();
  final rng = Rng(20260806);

  // 1) 纯生成耗时（不含标注/定档）
  final swGen = Stopwatch()..start();
  final puzzles = <Puzzle>[];
  for (int i = 0; i < n; i++) {
    puzzles.add(gen.generate(rng, targetGivens: 28));
  }
  swGen.stop();
  final genMs = swGen.elapsedMicroseconds / n / 1000.0;

  // 2) 唯一解校验 + 逐级求解定档耗时
  final swFull = Stopwatch()..start();
  int uniqueOk = 0, logicSolved = 0;
  final Map<String, int> diffCount = {};
  for (final p in puzzles) {
    final b = p.toGivenBoard();
    CandidateCalculator.recomputeAll(b);
    if (!checker.isUnique(b)) continue;
    uniqueOk++;
    final out = solver.solve(SolveContext(
      board: b,
      ruleSet: ruleSet,
      uniqueSolutionGuaranteed: true,
      solution: p.solution,
    ));
    if (out.solved) {
      logicSolved++;
      final d = DifficultyGrader.fromOutcome(out).difficulty.name;
      diffCount[d] = (diffCount[d] ?? 0) + 1;
    }
  }
  swFull.stop();
  final fullMs = swFull.elapsedMicroseconds / n / 1000.0;

  print('=== 基准（n=$n, targetGivens=28, 单线程, t2 规则集）===');
  print('纯生成  : ${genMs.toStringAsFixed(2)} ms/题');
  print('生成+唯一解校验+逐级求解定档: ${fullMs.toStringAsFixed(2)} ms/题');
  print('唯一解通过率 : ${(uniqueOk / n * 100).toStringAsFixed(1)}%');
  print('纯逻辑可解率 : ${(logicSolved / n * 100).toStringAsFixed(1)}%');
  print('定档分布: $diffCount');
}
