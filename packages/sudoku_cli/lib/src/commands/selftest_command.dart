/// `selftest` 子命令：算法层连通性自检（批次 A 保留）。
///
/// 职责不变：生成 → 唯一解校验 → 回溯求解 → 比对终局解，
/// 顺带输出技巧注册表就绪数。全部复用 `sudoku_core`，零实现。
library;

import 'package:sudoku_core/sudoku_core.dart';

import 'command_base.dart';

/// 连通性自检命令。
class SelftestCommand extends SudokuCommand {
  /// 构造命令。
  SelftestCommand(super.reporter);

  @override
  String get name => 'selftest';

  @override
  String get description =>
      '算法层连通性自检（生成 → 唯一解 → 回溯求解比对）';

  @override
  Future<Object?> run() async {
    const int seed = 20260805;
    final Rng rng = Rng(seed);

    const PuzzleGenerator generator = PuzzleGenerator();
    final Puzzle puzzle = generator.generate(rng, targetGivens: 32);

    const UniquenessChecker checker = UniquenessChecker();
    final Board board = puzzle.toGivenBoard();
    CandidateCalculator.recomputeAll(board);

    const BacktrackingSolver solver = BacktrackingSolver();
    final List<int>? solved = solver.solveFirst(board);

    final bool unique = checker.isUnique(board);
    final bool consistent = Validator.isConsistent(board);
    final bool candidatesOk = CandidateCalculator.isConsistent(board);
    final bool solvedMatches =
        solved != null && solved.join() == puzzle.solutionString;

    reporter.info('sudoku_cli selftest（seed=$seed）');
    reporter.info('  题面提示数        : ${puzzle.givenCount}');
    reporter.info('  题面             : ${puzzle.givenString}');
    reporter.info('  盘面无冲突        : ${_mark(consistent)}');
    reporter.info('  候选与全量重算一致 : ${_mark(candidatesOk)}');
    reporter.info('  唯一解            : ${_mark(unique)}');
    reporter.info('  回溯解 == 终局解   : ${_mark(solvedMatches)}');
    reporter.info('  技巧注册表已启用   : ${TechniqueRegistry.defaults().length} / '
        '${TechniqueId.values.length}');

    final bool allPassed = unique && consistent && candidatesOk && solvedMatches;
    reporter.info(allPassed ? '自检通过 ✅' : '自检失败 ❌');
    return allPassed ? 0 : 1;
  }

  static String _mark(bool ok) => ok ? '通过' : '失败';
}
