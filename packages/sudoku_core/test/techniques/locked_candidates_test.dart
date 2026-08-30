/// T-TEC-07 区块排除（Locked Candidates，rank 50）单测。
///
/// 覆盖两种情形与全部「不得上报」分支：
/// - 指向（Pointing）：宫内某数字候选全在同一行/列 → 删该行/列宫外的它；
/// - 占位（Claiming）：行/列内某数字候选全在同一宫 → 删该宫内行/列外的它。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import '../support/technique_fixture.dart';

void main() {
  const LockedCandidatesTechnique technique = LockedCandidatesTechnique();

  group('指向（宫 → 行/列）· 正向识别', () {
    test('宫内数字 5 只落在第 1 行 → 删去该行宫外的 5', () {
      // 第 1 宫的 5 只可能在 r1c1 / r1c2（都在第 1 行）
      // → 第 1 行宫外的 r1c4 不可能是 5。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5, 6],
        rc(0, 1): <int>[5, 6],
        rc(0, 3): <int>[5, 7],
      });
      final List<TechniqueResult> results = scan(technique, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(0, 3), 5)});
      expect(results.single.techniqueId, TechniqueId.lockedCandidates);
      expect(hasCompleteHintPayload(results.single), isTrue);
      expect(results.single.narration.slots['mode'], '指向');
    });

    test('rank / difficulty 与登记表一致', () {
      expect(technique.id, TechniqueId.lockedCandidates);
      expect(technique.rank, 50);
    });
  });

  group('占位（行/列 → 宫）· 正向识别', () {
    test('第 1 行的 5 只落在第 1 宫 → 删去该宫内行外的 5', () {
      // 第 1 行的 5 只可能在 r1c1 / r1c2（都在第 1 宫）
      // → 第 1 宫内非第 1 行的 r2c3 不可能是 5。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5, 6],
        rc(0, 1): <int>[5, 6],
        rc(1, 2): <int>[5, 7],
      });
      final List<TechniqueResult> results = scan(technique, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(1, 2), 5)});
      expect(results.single.narration.slots['mode'], '占位');
      expect(hasCompleteHintPayload(results.single), isTrue);
    });
  });

  group('反向「不得上报」', () {
    test('宫内候选跨 2 行 2 列、行内候选跨 2 宫 → 两种情形都不成立', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(1, 1): <int>[5],
        rc(0, 4): <int>[5],
      });
      expect(scan(technique, ctx), isEmpty);
    });

    test('源单元内该数字只有 1 个候选位（那是隐性唯一数）→ 不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(0, 4): <int>[5, 6],
      });
      // 第 1 宫的 5 只有 r1c1 一处 → positions.length < 2，整支直接跳过。
      final List<TechniqueResult> results = scan(technique, ctx);
      expect(
        allEliminationKeys(results).contains(elimKey(rc(0, 4), 5)),
        isFalse,
      );
    });

    test('区块成立但目标单元无可删候选 → 空结论不外泄', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5, 6],
        rc(0, 1): <int>[5, 6],
      });
      expect(scan(technique, ctx), isEmpty);
    });

    test('规则集未启用 → 不上报', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{
          rc(0, 0): <int>[5, 6],
          rc(0, 1): <int>[5, 6],
          rc(0, 3): <int>[5, 7],
        },
        ruleSet: RuleSet.none(),
      );
      expect(scan(technique, ctx), isEmpty);
    });

    test('E_TECH_001：删数命中终局解 → 整条结论降级为无提示', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{
          rc(0, 0): <int>[5, 6],
          rc(0, 1): <int>[5, 6],
          rc(0, 3): <int>[5, 7],
        },
        solution: fakeSolutionWith(rc(0, 3), 5),
      );
      expect(scan(technique, ctx), isEmpty);
    });

    test('limit <= 0 时直接返回空', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5, 6],
        rc(0, 1): <int>[5, 6],
        rc(0, 3): <int>[5, 7],
      });
      expect(technique.find(ctx, limit: 0), isEmpty);
    });
  });
}
