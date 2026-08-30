/// 生成器与唯一解单测（doc 07 T-CORE-03 / T-CORE-06）。
///
/// 依赖随机但**可复现**：固定种子后结果稳定，CI 可重复。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

void main() {
  group('PuzzleGenerator 唯一解与可复现', () {
    test('同 seed 生成同题面', () {
      final Puzzle a = PuzzleGenerator().generate(Rng(20260805), targetGivens: 32);
      final Puzzle b = PuzzleGenerator().generate(Rng(20260805), targetGivens: 32);
      expect(a.givenString, equals(b.givenString));
      expect(a.solutionString, equals(b.solutionString));
    });

    test('生成题唯一解且回溯解 == 终局解', () {
      final Puzzle puzzle = PuzzleGenerator().generate(Rng(7), targetGivens: 30);
      final Board board = puzzle.toGivenBoard();
      CandidateCalculator.recomputeAll(board);

      // 唯一解
      expect(UniquenessChecker().isUnique(board), isTrue);
      // 候选一致
      expect(CandidateCalculator.isConsistent(board), isTrue);
      // 题面无冲突
      expect(Validator.isConsistent(board), isTrue);
      // 回溯解与终局解一致
      final List<int>? solved = const BacktrackingSolver().solveFirst(board);
      expect(solved, isNotNull);
      expect(solved!.join(), equals(puzzle.solutionString));
    });

    test('生成题提示数不超过目标上限', () {
      const int target = 28;
      final Puzzle puzzle = PuzzleGenerator().generate(Rng(99), targetGivens: target);
      expect(puzzle.givenCount, lessThanOrEqualTo(target));
      expect(puzzle.givenCount, greaterThanOrEqualTo(PuzzleGenerator.kMinGivens));
    });

    test('generateFullSolution 产出合法终盘', () {
      final List<int> solution = PuzzleGenerator().generateFullSolution(Rng(123));
      expect(Validator.isValidSolution(solution), isTrue);
    });
  });

  group('SymmetryMode', () {
    test('中心对称挖洞仍唯一解', () {
      final Puzzle puzzle = PuzzleGenerator().generate(
        Rng(456),
        targetGivens: 34,
        symmetry: SymmetryMode.central,
      );
      final Board board = puzzle.toGivenBoard();
      expect(UniquenessChecker().isUnique(board), isTrue);
    });
  });
}
