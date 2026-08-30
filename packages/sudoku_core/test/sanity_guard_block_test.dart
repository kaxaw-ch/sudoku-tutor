/// SanityGuard 误删/误填拦截（P0-QA-03 底座，批次 B，doc 07 T-CORE-06）。
///
/// 目标：把"删数不得等于终局解、填数必须等于终局解"这条 P0 正确性护栏
/// 用可执行断言钉死——任何技巧识别器一旦误删正确候选或误填错误数字，
/// 必须抛 `E_TECH_001`，否则玩家会被引入死局。
///
/// ⚠️ 说明：早期沙箱无 Dart SDK 时此文件由 CI 在客户端运行；
/// 2026-08-06 起本地可直接执行（`dart test` 已验证通过）。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

void main() {
  group('assertEliminationSafe / assertPlacementSafe', () {
    late List<int> solution;
    late int cell;
    late int correct;
    late int wrong;

    setUp(() {
      // 用生成器产出一份合法终盘作为终局解。
      solution = PuzzleGenerator().generateFullSolution(Rng(555));
      cell = solution.indexWhere((int v) => v != kEmptyValue);
      correct = solution[cell];
      wrong = (correct % 9) + 1; // 必与 correct 不同（1..9 循环）
      SanityGuard.enabled = true;
    });

    tearDown(() {
      SanityGuard.enabled = true;
    });

    test('删掉终局解候选 -> 抛 E_TECH_001', () {
      expect(
        () => SanityGuard.assertEliminationSafe(solution, cell, correct),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_001')),
      );
    });

    test('删除非解候选 -> 不抛', () {
      expect(() => SanityGuard.assertEliminationSafe(solution, cell, wrong),
          returnsNormally);
    });

    test('填入错误数字 -> 抛 E_TECH_001', () {
      expect(
        () => SanityGuard.assertPlacementSafe(solution, cell, wrong),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_001')),
      );
    });

    test('填入正确数字 -> 不抛', () {
      expect(() => SanityGuard.assertPlacementSafe(solution, cell, correct),
          returnsNormally);
    });

    test('solution 为 null 时短路放行（设计使然）', () {
      expect(() => SanityGuard.assertEliminationSafe(null, cell, correct),
          returnsNormally);
      expect(() => SanityGuard.assertPlacementSafe(null, cell, wrong),
          returnsNormally);
    });

    test('enabled=false 时整体关闭', () {
      SanityGuard.enabled = false;
      expect(() => SanityGuard.assertEliminationSafe(solution, cell, correct),
          returnsNormally);
      expect(() => SanityGuard.assertPlacementSafe(solution, cell, wrong),
          returnsNormally);
    });
  });

  group('checkResult 统一入口', () {
    test('命中终局解的删数结论抛 E_TECH_001，安全结论不抛', () {
      final List<int> solution = PuzzleGenerator().generateFullSolution(Rng(13));
      final int cell = solution.indexWhere((int v) => v != kEmptyValue);
      final int correct = solution[cell];
      final Board board = Board.fromValues(solution);
      final SolveContext ctx = SolveContext(
        board: board,
        ruleSet: RuleSet.t2(),
        solution: solution,
      );

      final TechniqueResult bad = TechniqueResult(
        techniqueId: TechniqueId.nakedSingle,
        eliminations: <Elimination>[Elimination(cell, correct)],
      );
      expect(
        () => SanityGuard.checkResult(ctx, bad),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_001')),
      );

      final TechniqueResult good = TechniqueResult(
        techniqueId: TechniqueId.nakedSingle,
        eliminations: <Elimination>[Elimination(cell, (correct % 9) + 1)],
      );
      expect(() => SanityGuard.checkResult(ctx, good), returnsNormally);
    });
  });

  group('collectViolations / isResultSafe', () {
    test('命中终局解的删数 + 误填被标记为两条违规', () {
      final List<int> solution = PuzzleGenerator().generateFullSolution(Rng(99));
      final int cell = solution.indexWhere((int v) => v != kEmptyValue);
      final int correct = solution[cell];
      final int wrong = (correct % 9) + 1;
      final TechniqueResult r = TechniqueResult(
        techniqueId: TechniqueId.nakedSingle,
        eliminations: <Elimination>[Elimination(cell, correct)],
        placements: <Placement>[Placement(cell, wrong)],
      );
      final List<SanityViolation> violations =
          SanityGuard.collectViolations(solution, r);
      expect(violations.length, equals(2));
      expect(SanityGuard.isResultSafe(solution, r), isFalse);
    });

    test('无终局解时 collectViolations 返回空', () {
      final TechniqueResult r = TechniqueResult(
        techniqueId: TechniqueId.nakedSingle,
        eliminations: <Elimination>[Elimination(0, 5)],
      );
      expect(SanityGuard.collectViolations(null, r), isEmpty);
    });
  });
}
