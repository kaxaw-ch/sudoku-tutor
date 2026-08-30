/// 唯一解校验器单测（doc 07 T-CORE-03）。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

// 一道经典唯一解题面
const String kUnique =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

// 一道明显多解的盘面（仅两格）
const String kMultiple =
    '.................................................................................';

void main() {
  group('UniquenessChecker', () {
    test('已知唯一解题面 verdict = unique', () {
      final Board board = Board.fromPuzzleString(kUnique);
      expect(const UniquenessChecker().verdictOf(board),
          equals(UniquenessVerdict.unique));
      expect(const UniquenessChecker().isUnique(board), isTrue);
    });

    test('几乎空格面为多解', () {
      final Board board = Board.fromPuzzleString(kMultiple);
      final UniquenessVerdict verdict = const UniquenessChecker().verdictOf(board);
      expect(verdict, equals(UniquenessVerdict.multiple));
      expect(const UniquenessChecker().isUnique(board), isFalse);
    });

    test('requireUnique 对多解抛 E_SOLVE_002', () {
      final Board board = Board.fromPuzzleString(kMultiple);
      expect(
        () => const UniquenessChecker().requireUnique(board),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_SOLVE_002')),
      );
    });

    test('uniqueSolutionOf 返回与终局一致的解', () {
      final List<int>? solution =
          const UniquenessChecker().uniqueSolutionOf(Board.fromPuzzleString(kUnique));
      expect(solution, isNotNull);
      expect(Validator.isValidSolution(solution!), isTrue);
    });
  });
}
