/// T-TEC-01 唯一余数（Naked Single，rank 10）单测。
///
/// 覆盖：正向识别 + 全部「不得上报」反向条件 + E_TECH_001 安全降级。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import 'support/technique_fixture.dart';

void main() {
  const NakedSingleTechnique technique = NakedSingleTechnique();

  group('NakedSingle · 正向识别', () {
    test('候选恰 1 个 → 上报填数，并携带完整可视化与讲解数据', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
      });
      final List<TechniqueResult> results = scan(technique, ctx);

      expect(results, hasLength(1));
      expect(results.single.techniqueId, TechniqueId.nakedSingle);
      expect(allPlacementKeys(results), <String>{placeKey(rc(0, 0), 5)});
      // doc 06 P0-ENG-09/10：任何非空结论必须自带双通道可视 + 讲解槽位。
      expect(results.every(hasCompleteHintPayload), isTrue);
    });

    test('rank / difficulty 由 TechniqueRank 单一事实源派生', () {
      expect(technique.rank, 10);
      expect(technique.difficulty, Difficulty.beginner);
      expect(technique.id, TechniqueId.nakedSingle);
    });

    test('limit 生效：多个唯一余数按 limit 截断', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(4, 4): <int>[6],
        rc(8, 8): <int>[7],
      });
      expect(scan(technique, ctx, limit: 1), hasLength(1));
      expect(scan(technique, ctx, limit: 32), hasLength(3));
    });
  });

  group('NakedSingle · 反向「不得上报」', () {
    test('候选 ≥ 2 → 不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5, 7],
      });
      expect(scan(technique, ctx), isEmpty);
    });

    test('候选为 0 的死格 → 静默跳过，不上报也不抛异常', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[],
      });
      expect(() => scan(technique, ctx), returnsNormally);
      expect(scan(technique, ctx), isEmpty);
    });

    test('规则集未启用该技巧 → 不上报', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{rc(0, 0): <int>[5]},
        ruleSet: RuleSet.none(),
      );
      expect(scan(technique, ctx), isEmpty);
    });

    test('limit <= 0 → 直接返回空', () {
      final SolveContext ctx = sandbox(<int, List<int>>{rc(0, 0): <int>[5]});
      expect(scan(technique, ctx, limit: 0), isEmpty);
    });

    test('E_TECH_001：填数与终局解冲突 → SanityGuard 降级为「本步无提示」', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{rc(0, 0): <int>[5]},
        // 终局解要求 r1c1 = 3，本步却想填 5 → 整步必须作废。
        solution: fakeSolutionWith(rc(0, 0), 3),
      );
      expect(scan(technique, ctx), isEmpty);
    });

    test('E_TECH_001 对照组：填数与终局解一致 → 正常上报', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{rc(0, 0): <int>[5]},
        solution: fakeSolutionWith(rc(0, 0), 5),
      );
      expect(
        allPlacementKeys(scan(technique, ctx)),
        <String>{placeKey(rc(0, 0), 5)},
      );
    });
  });
}
