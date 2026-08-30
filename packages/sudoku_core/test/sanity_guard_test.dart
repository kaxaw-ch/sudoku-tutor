/// SanityGuard 安全断言单测（doc 07 T-CORE-06，P0-QA-03 底座）。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

// 已知合法终盘（供 solution 入参）
const List<int> kSolution = <int>[
  5, 3, 4, 6, 7, 8, 9, 1, 2,
  6, 7, 2, 1, 9, 5, 3, 4, 8,
  1, 9, 8, 3, 4, 2, 5, 6, 7,
  8, 5, 9, 7, 6, 1, 4, 2, 3,
  4, 2, 6, 8, 5, 3, 7, 9, 1,
  7, 1, 3, 9, 2, 4, 8, 5, 6,
  9, 6, 1, 5, 3, 7, 2, 8, 4,
  2, 8, 7, 4, 1, 9, 6, 3, 5,
  3, 4, 5, 2, 8, 6, 1, 7, 9,
];

void main() {
  group('SanityGuard 删数安全', () {
    test('删掉终局解候选抛 E_TECH_001', () {
      expect(
        () => SanityGuard.assertEliminationSafe(kSolution, 0, 5),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_001')),
      );
    });

    test('删掉非终局解候选放行', () {
      expect(
        () => SanityGuard.assertEliminationSafe(kSolution, 0, 9),
        returnsNormally,
      );
    });

    test('无终局解时直接放行', () {
      expect(
        () => SanityGuard.assertEliminationSafe(null, 0, 5),
        returnsNormally,
      );
    });
  });

  group('SanityGuard 填数安全', () {
    test('填入非终局解数字抛 E_TECH_001', () {
      expect(
        () => SanityGuard.assertPlacementSafe(kSolution, 0, 9),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_001')),
      );
    });

    test('填入终局解数字放行', () {
      expect(
        () => SanityGuard.assertPlacementSafe(kSolution, 0, 5),
        returnsNormally,
      );
    });
  });

  group('SanityGuard.checkResult', () {
    test('命中终局解的删数结论抛异常', () {
      final SolveContext ctx = SolveContext(
        board: Board.empty(),
        ruleSet: RuleSet.t2(),
        solution: kSolution,
      );
      final TechniqueResult bad = TechniqueResult(
        techniqueId: TechniqueId.nakedSingle,
        eliminations: <Elimination>[Elimination(0, 5)],
      );
      expect(
        () => SanityGuard.checkResult(ctx, bad),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_001')),
      );
    });

    test('安全结论通过 collectViolations', () {
      final TechniqueResult good = TechniqueResult(
        techniqueId: TechniqueId.nakedSingle,
        eliminations: <Elimination>[Elimination(0, 9)],
      );
      expect(SanityGuard.collectViolations(kSolution, good), isEmpty);
      expect(SanityGuard.isResultSafe(kSolution, good), isTrue);
    });
  });

  group('SanityGuard.enabled 开关', () {
    test('关闭后不再断言', () {
      final bool prev = SanityGuard.enabled;
      SanityGuard.enabled = false;
      try {
        expect(
          () => SanityGuard.assertEliminationSafe(kSolution, 0, 5),
          returnsNormally,
        );
      } finally {
        SanityGuard.enabled = prev;
      }
    });
  });
}
