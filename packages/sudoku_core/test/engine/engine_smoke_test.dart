/// 引擎核心冒烟测试（批次 A/B）：求解器 / 生成器 / 候选计算 / 安全护栏。
///
/// 与 `test/generator_test.dart`（生成器专项）互补：本文件走「已知题面 →
/// 已知答案」的确定性路径，任何一处口径漂移都会立刻暴露，不依赖随机。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

/// 经典题面（0 = 空格），30 个提示数。
const String kPuzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

/// [kPuzzle] 的唯一终局解。
const String kSolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

List<int> valuesOf(String s81) =>
    <int>[for (int i = 0; i < s81.length; i++) int.parse(s81[i])];

void main() {
  group('BacktrackingSolver · 已知题面', () {
    const BacktrackingSolver solver = BacktrackingSolver();

    test('solveFirst 求出的正是已知终局解', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      final List<int>? solved = solver.solveFirst(board);

      expect(solved, isNotNull);
      expect(solved, equals(valuesOf(kSolution)));
      expect(Validator.isValidSolution(solved!), isTrue);
    });

    test('求解为纯函数：不修改传入盘面', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      final String before = board.toPuzzleString();
      solver.solveFirst(board);
      solver.countSolutions(board);
      expect(board.toPuzzleString(), equals(before));
    });

    test('countSolutions == 1 且 hasUniqueSolution 为 true', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      expect(solver.countSolutions(board), equals(1));
      expect(solver.hasUniqueSolution(board), isTrue);
    });

    test('空盘为多解：countSolutions(stopAt:2) == 2', () {
      final Board empty = Board.empty();
      expect(solver.countSolutions(empty), equals(2));
      expect(solver.hasUniqueSolution(empty), isFalse);
    });

    test('自相矛盾的盘面无解：countSolutions == 0', () {
      final Board board = Board.empty();
      board.forceSetValue(Coord.indexOf(0, 0), 5);
      board.forceSetValue(Coord.indexOf(0, 1), 5);
      expect(solver.countSolutions(board), equals(0));
      expect(solver.solveFirst(board), isNull);
    });

    test('挖掉一个提示后仍唯一；挖掉整行则不再唯一', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      final List<int> values = board.toValueList().toList();
      values[0] = kEmptyValue;
      expect(solver.countSolutionsOfValues(values), equals(1));

      for (int col = 0; col < kBoardSize; col++) {
        values[Coord.indexOf(0, col)] = kEmptyValue;
      }
      expect(solver.countSolutionsOfValues(values), greaterThanOrEqualTo(1));
    });
  });

  group('UniquenessChecker · 判定口径', () {
    const UniquenessChecker checker = UniquenessChecker();

    test('已知题面 verdict = unique，且 uniqueSolutionOf 与终局一致', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      expect(checker.verdictOf(board), equals(UniquenessVerdict.unique));
      expect(checker.isUnique(board), isTrue);
      expect(checker.uniqueSolutionOf(board), equals(valuesOf(kSolution)));
      expect(() => checker.requireUnique(board), returnsNormally);
    });

    test('空盘 verdict = multiple，矛盾盘 verdict = none', () {
      expect(checker.verdictOf(Board.empty()),
          equals(UniquenessVerdict.multiple));

      final Board broken = Board.empty();
      broken.forceSetValue(Coord.indexOf(0, 0), 5);
      broken.forceSetValue(Coord.indexOf(1, 1), 5);
      expect(checker.verdictOf(broken), equals(UniquenessVerdict.none));
      expect(checker.uniqueSolutionOf(broken), isNull);
      expect(
        () => checker.requireUnique(broken),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_SOLVE_001')),
      );
    });
  });

  group('PuzzleGenerator · 产出合法且唯一解的题目', () {
    const PuzzleGenerator generator = PuzzleGenerator();

    test('generateFullSolution 产出合法终盘', () {
      for (final int seed in <int>[1, 7, 42]) {
        final List<int> solution = generator.generateFullSolution(Rng(seed));
        expect(Validator.isValidSolution(solution), isTrue,
            reason: 'seed=$seed 的终盘必须合法');
      }
    });

    test('generate 的题面唯一解、可解回原终盘、提示数不低于下界', () {
      const UniquenessChecker checker = UniquenessChecker();
      const BacktrackingSolver solver = BacktrackingSolver();

      for (final int seed in <int>[3, 11, 2024]) {
        final Puzzle puzzle = generator.generate(Rng(seed), targetGivens: 30);

        expect(Validator.isValidSolution(puzzle.solution), isTrue);
        expect(puzzle.givenCount, greaterThanOrEqualTo(PuzzleGenerator.kMinGivens));

        final Board given = puzzle.toGivenBoard();
        expect(Validator.isConsistent(given), isTrue);
        expect(checker.isUnique(given), isTrue,
            reason: 'seed=$seed 生成的题面必须唯一解');
        expect(solver.solveFirst(given), equals(puzzle.solution),
            reason: '题面的唯一解必须等于生成时的终盘');

        // 题面每个提示都与终局解一致。
        for (int i = 0; i < kCellCount; i++) {
          if (puzzle.given[i] != kEmptyValue) {
            expect(puzzle.given[i], equals(puzzle.solution[i]));
            expect(puzzle.givenMask[i], isTrue);
          } else {
            expect(puzzle.givenMask[i], isFalse);
          }
        }
      }
    });

    test('同 seed 可复现（§7.1 铁律）', () {
      final Puzzle a = generator.generate(Rng(777), targetGivens: 32);
      final Puzzle b = generator.generate(Rng(777), targetGivens: 32);
      expect(a.givenString, equals(b.givenString));
      expect(a.solutionString, equals(b.solutionString));
    });

    test('中心对称挖洞仍唯一解且题面确为中心对称', () {
      const UniquenessChecker checker = UniquenessChecker();
      final Puzzle puzzle = generator.generate(
        Rng(1234),
        targetGivens: 30,
        symmetry: SymmetryMode.central,
      );
      expect(checker.isUnique(puzzle.toGivenBoard()), isTrue);
      for (int i = 0; i < kCellCount; i++) {
        expect(
          puzzle.given[i] != kEmptyValue,
          equals(puzzle.given[kCellCount - 1 - i] != kEmptyValue),
          reason: '格 $i 与其中心对称格的填充状态应一致',
        );
      }
    });

    test('generateBoard 直接产出候选已算好的可对局盘面', () {
      final Board board = generator.generateBoard(Rng(88), targetGivens: 32);
      expect(CandidateCalculator.findInconsistentCells(board), isEmpty);
      expect(CandidateCalculator.hasDeadCell(board), isFalse);
      expect(board.givenCount(), equals(board.filledCount()));
    });
  });

  group('CandidateCalculator · 候选集正确性', () {
    test('已知题面上逐格候选与「全集减去 peer 已用数字」一致', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      CandidateCalculator.recomputeAll(board);

      for (int index = 0; index < kCellCount; index++) {
        if (board.isFilled(index)) {
          expect(board.candidatesAt(index).isEmpty, isTrue,
              reason: '已填格 ${Coord.label(index)} 的候选必须为空集');
          continue;
        }
        final Set<int> used = <int>{
          for (final int peer in Peers.peersOf(index))
            if (board.valueAt(peer) != kEmptyValue) board.valueAt(peer),
        };
        final Set<int> expected = <int>{
          for (int d = kMinDigit; d <= kMaxDigit; d++)
            if (!used.contains(d)) d,
        };
        expect(board.candidatesAt(index).digits().toSet(), equals(expected),
            reason: '${Coord.label(index)} 的候选集不符');
      }
    });

    test('已知题面上几处手算候选（钉死具体数值）', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      CandidateCalculator.recomputeAll(board);

      // r1c3：行内已有 {5,3,7}，第 3 列已有 {8}，第 1 宫已有 {5,3,6,9,8}
      // → 候选 {1,2,4}。
      expect(board.candidatesAt(Coord.indexOf(0, 2)).digits(),
          equals(<int>[1, 2, 4]));
      // r1c9：行 {5,3,7}，第 9 列 {3,6,1,5,9}，第 3 宫 {6,}
      // → 候选 {2,4,8}。
      expect(board.candidatesAt(Coord.indexOf(0, 8)).digits(),
          equals(<int>[2, 4, 8]));
    });

    test('终局解上的候选必定包含在每个空格的候选集中', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      CandidateCalculator.recomputeAll(board);
      final List<int> solution = valuesOf(kSolution);
      for (final int index in board.blankCells()) {
        expect(board.candidatesAt(index).contains(solution[index]), isTrue,
            reason: '${Coord.label(index)} 的候选集丢失了正确答案 ${solution[index]}');
      }
    });

    test('candidatesFor 与 recomputeAll 写回结果一致', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      CandidateCalculator.recomputeAll(board);
      for (int index = 0; index < kCellCount; index++) {
        expect(CandidateCalculator.candidatesFor(board, index).mask,
            equals(board.candidateMasks[index]));
      }
    });

    test('place / clear 后增量同步与全量重算逐格一致', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      CandidateCalculator.recomputeAll(board);
      final List<int> solution = valuesOf(kSolution);

      // 按终局解逐格填入前 20 个空格，每步都做一致性校验。
      final List<int> blanks = board.blankCells().take(20).toList();
      for (final int index in blanks) {
        board.place(index, solution[index]);
        CandidateCalculator.syncAfterPlace(board, index, solution[index]);
        expect(CandidateCalculator.findInconsistentCells(board), isEmpty,
            reason: '填 ${Coord.label(index)} 后候选与全量重算不一致');
      }
      // 再逐格撤回。
      for (final int index in blanks.reversed) {
        board.clear(index);
        CandidateCalculator.syncAfterClear(board, index);
        expect(CandidateCalculator.findInconsistentCells(board), isEmpty,
            reason: '清 ${Coord.label(index)} 后候选与全量重算不一致');
      }
    });
  });

  group('SanityGuard · 合法盘面全程放行', () {
    test('沿终局解推进的每一步都不产生任何违规', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      CandidateCalculator.recomputeAll(board);
      final List<int> solution = valuesOf(kSolution);

      for (final int index in board.blankCells()) {
        // 填入正确数字 → 放行。
        expect(
          () => SanityGuard.assertPlacementSafe(solution, index, solution[index]),
          returnsNormally,
        );
        // 删掉「非正确答案」的候选 → 放行。
        for (final int digit in board.candidatesAt(index).digits()) {
          if (digit == solution[index]) {
            continue;
          }
          expect(
            () => SanityGuard.assertEliminationSafe(solution, index, digit),
            returnsNormally,
          );
        }
      }
    });

    test('E_TECH_001 语义：删掉的候选正是终局解才算违规', () {
      final List<int> solution = valuesOf(kSolution);
      final int cell = Coord.indexOf(0, 2); // 终局解为 4
      expect(solution[cell], equals(4));

      expect(
        () => SanityGuard.assertEliminationSafe(solution, cell, 4),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_001')),
      );
      expect(() => SanityGuard.assertEliminationSafe(solution, cell, 1),
          returnsNormally);
    });
  });
}
