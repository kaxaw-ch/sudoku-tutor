/// 生成器唯一解保证 + 可解性压力测试（批次 B，doc 07 T-CORE-03）。
///
/// 目标：把"挖洞每一步都复验唯一解"这一正确性保证用可执行断言钉死，
/// 防止任何回归把题目退化成多解。
///
/// ⚠️ 静态约束：本文件不在当前沙箱执行（无 Flutter/Dart SDK），
/// 由 CI 在客户端运行；详见 `docs/08-QA批次A+B审查.md` §8 验证清单。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

void main() {
  group('生成器 100 次唯一解 + 可解性', () {
    test('连续 100 个随机种子均产出唯一解且可解', () {
      final PuzzleGenerator generator = PuzzleGenerator();
      for (int i = 0; i < 100; i++) {
        final Rng rng = Rng(1000 + i);
        final Puzzle puzzle = generator.generate(rng, targetGivens: 30);

        // 1) 题面合法：提示数不低于数学下界 17。
        expect(puzzle.givenCount,
            greaterThanOrEqualTo(PuzzleGenerator.kMinGivens),
            reason: 'seed=${rng.seed} 提示数不应低于 17');

        // 2) 唯一解：计数恰为 1。
        final Board board = puzzle.toGivenBoard();
        CandidateCalculator.recomputeAll(board);
        expect(const BacktrackingSolver().hasUniqueSolution(board), isTrue,
            reason: 'seed=${rng.seed} 应唯一解');

        // 3) 可解且解等于终局解（越强越好）。
        final List<int>? solved = const BacktrackingSolver().solveFirst(board);
        expect(solved, isNotNull, reason: 'seed=${rng.seed} 应可解');
        expect(solved, equals(puzzle.solution),
            reason: 'seed=${rng.seed} 回溯解应等于生成终局解');

        // 4) 终局解自身合法。
        expect(Validator.isValidSolution(puzzle.solution), isTrue);
      }
    });

    test('同 seed 可复现（结果稳定）', () {
      final PuzzleGenerator generator = PuzzleGenerator();
      final Puzzle a = generator.generate(Rng(42));
      final Puzzle b = generator.generate(Rng(42));
      expect(a.givenString, equals(b.givenString));
      expect(a.solutionString, equals(b.solutionString));
    });

    test('中心对称模式仍唯一解', () {
      final PuzzleGenerator generator = PuzzleGenerator();
      final Puzzle puzzle = generator.generate(
        Rng(7),
        targetGivens: 32,
        symmetry: SymmetryMode.central,
      );
      final Board board = puzzle.toGivenBoard();
      CandidateCalculator.recomputeAll(board);
      expect(const BacktrackingSolver().hasUniqueSolution(board), isTrue);
    });

    test('requireExactTarget=true 至多重试 kMaxRestart 轮不抛异常', () {
      final PuzzleGenerator generator = PuzzleGenerator();
      final Puzzle puzzle = generator.generate(
        Rng(31415),
        targetGivens: 24,
        requireExactTarget: true,
      );
      final Board board = puzzle.toGivenBoard();
      CandidateCalculator.recomputeAll(board);
      expect(const BacktrackingSolver().hasUniqueSolution(board), isTrue);
    });
  });
}
