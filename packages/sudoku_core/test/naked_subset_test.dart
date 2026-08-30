/// T-TEC-03 裸对 / T-TEC-05 裸三（Naked Subset，rank 30 / 60）单测。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import 'support/technique_fixture.dart';

void main() {
  const NakedSubsetTechnique nakedPair = NakedSubsetTechnique(size: 2);
  const NakedSubsetTechnique nakedTriple = NakedSubsetTechnique(size: 3);

  group('NakedPair · 正向识别', () {
    test('两格候选并集恰为 2 → 删去同单元其余格的这 2 个数字', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[1, 2],
        rc(0, 2): <int>[1, 2, 3],
        rc(0, 3): <int>[2, 3, 4],
      });
      final List<TechniqueResult> results = scan(nakedPair, ctx);

      expect(results, isNotEmpty);
      expect(
        allEliminationKeys(results),
        <String>{
          elimKey(rc(0, 2), 1),
          elimKey(rc(0, 2), 2),
          elimKey(rc(0, 3), 2),
        },
      );
      expect(results.every(hasCompleteHintPayload), isTrue);
      expect(
        results.every((TechniqueResult r) => r.techniqueId == TechniqueId.nakedPair),
        isTrue,
      );
    });

    test('id / rank / difficulty 随 size 派生', () {
      expect(nakedPair.id, TechniqueId.nakedPair);
      expect(nakedPair.rank, 30);
      expect(nakedPair.difficulty, Difficulty.easy);
      expect(nakedTriple.id, TechniqueId.nakedTriple);
      expect(nakedTriple.rank, 60);
      expect(nakedTriple.difficulty, Difficulty.medium);
    });
  });

  group('NakedPair · 反向「不得上报」', () {
    test('并集为 3 个数字 → 不构成裸对，不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[2, 3],
        rc(0, 2): <int>[1, 2, 3],
      });
      expect(scan(nakedPair, ctx), isEmpty);
    });

    test('同单元内无任何可删候选 → 不上报（空结论不得外泄）', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[1, 2],
      });
      expect(scan(nakedPair, ctx), isEmpty);
    });

    test('候选数超出 2..size 的格不得成为子集成员', () {
      // r1c3 候选为 {1,2,3}，即便它是 {1,2} 的超集也不能当裸对成员。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 2): <int>[1, 2, 3],
        rc(0, 3): <int>[1, 2, 3],
      });
      expect(scan(nakedPair, ctx), isEmpty);
    });

    test('规则集未启用 → 不上报', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{
          rc(0, 0): <int>[1, 2],
          rc(0, 1): <int>[1, 2],
          rc(0, 2): <int>[1, 2, 3],
        },
        ruleSet: RuleSet.none(),
      );
      expect(scan(nakedPair, ctx), isEmpty);
    });

    test('E_TECH_001：删数命中终局解 → 整条结论降级为无提示', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{
          rc(0, 0): <int>[1, 2],
          rc(0, 1): <int>[1, 2],
          rc(0, 2): <int>[1, 2, 3],
          rc(0, 3): <int>[2, 3, 4],
        },
        // 终局解在 r1c3 就是 1，删掉它即为误删 → 必须整步作废。
        solution: fakeSolutionWith(rc(0, 2), 1),
      );
      expect(scan(nakedPair, ctx), isEmpty);
    });
  });

  group('NakedTriple · 正向识别', () {
    test('三格候选并集恰为 3 → 删去同单元其余格的这 3 个数字', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[2, 3],
        rc(0, 2): <int>[1, 3],
        rc(0, 3): <int>[1, 2, 3, 4],
        rc(0, 4): <int>[3, 5],
      });
      final List<TechniqueResult> results = scan(nakedTriple, ctx);

      expect(results, hasLength(1));
      expect(
        allEliminationKeys(results),
        <String>{
          elimKey(rc(0, 3), 1),
          elimKey(rc(0, 3), 2),
          elimKey(rc(0, 3), 3),
          elimKey(rc(0, 4), 3),
        },
      );
      expect(results.single.techniqueId, TechniqueId.nakedTriple);
      expect(hasCompleteHintPayload(results.single), isTrue);
    });
  });

  group('NakedTriple · 反向「不得上报」', () {
    test('并集为 4 个数字 → 不构成裸三，不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[2, 3],
        rc(0, 2): <int>[3, 4],
        rc(0, 3): <int>[1, 2, 3, 4],
      });
      expect(scan(nakedTriple, ctx), isEmpty);
    });

    test('size 超出 2/3 → 取 id 时抛 E_TECH_003（本期不含裸四）', () {
      const NakedSubsetTechnique quad = NakedSubsetTechnique(size: 4);
      expect(() => quad.id, throwsA(isA<CoreException>()));
    });
  });
}
