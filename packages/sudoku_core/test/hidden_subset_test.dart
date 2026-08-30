/// T-TEC-04 隐对 / T-TEC-06 隐三（Hidden Subset，rank 40 / 70）单测。
///
/// 沙盘设计要点：把参与格分散到不同宫，避免宫单元额外派生出
/// 与被测模式无关的隐性子集，使「精确集合断言」成立。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import 'support/technique_fixture.dart';

void main() {
  const HiddenSubsetTechnique hiddenPair = HiddenSubsetTechnique(size: 2);
  const HiddenSubsetTechnique hiddenTriple = HiddenSubsetTechnique(size: 3);

  group('HiddenPair · 正向识别', () {
    test('两数字只落在同两格 → 删去这两格的其余候选', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[4, 5, 6, 7],
        rc(0, 3): <int>[4, 5, 8, 9],
        rc(0, 4): <int>[6, 7, 8],
        rc(0, 6): <int>[6, 7, 9],
        rc(0, 7): <int>[8, 9],
      });
      final List<TechniqueResult> results = scan(hiddenPair, ctx);

      expect(results, hasLength(1));
      expect(
        allEliminationKeys(results),
        <String>{
          elimKey(rc(0, 0), 6),
          elimKey(rc(0, 0), 7),
          elimKey(rc(0, 3), 8),
          elimKey(rc(0, 3), 9),
        },
      );
      expect(results.single.techniqueId, TechniqueId.hiddenPair);
      expect(hasCompleteHintPayload(results.single), isTrue);
    });

    test('id / rank / difficulty 随 size 派生', () {
      expect(hiddenPair.id, TechniqueId.hiddenPair);
      expect(hiddenPair.rank, 40);
      expect(hiddenPair.difficulty, Difficulty.easy);
      expect(hiddenTriple.id, TechniqueId.hiddenTriple);
      expect(hiddenTriple.rank, 70);
      expect(hiddenTriple.difficulty, Difficulty.medium);
    });
  });

  group('HiddenPair · 反向「不得上报」', () {
    test('两数字的位置并集为 3 格 → 不构成隐对，不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[4, 6],
        rc(0, 3): <int>[5, 7],
        rc(0, 6): <int>[4, 5, 8],
      });
      expect(scan(hiddenPair, ctx), isEmpty);
    });

    test('子集格上没有多余候选 → 无删数，不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[4, 5],
        rc(0, 3): <int>[4, 5],
        rc(0, 6): <int>[6, 7, 8],
      });
      expect(scan(hiddenPair, ctx), isEmpty);
    });

    test('数字在单元内只有 1 个候选位置（隐性唯一数）→ 不参与隐对', () {
      // 4 与 5 各自只有一处 —— 属 rank 20 的范畴，隐对不得越界处理。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[4, 5, 6, 7],
        rc(0, 3): <int>[6, 7, 8],
        rc(0, 6): <int>[6, 7, 8],
      });
      expect(scan(hiddenPair, ctx), isEmpty);
    });

    test('规则集未启用 → 不上报', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{
          rc(0, 0): <int>[4, 5, 6, 7],
          rc(0, 3): <int>[4, 5, 8, 9],
          rc(0, 4): <int>[6, 7, 8],
          rc(0, 6): <int>[6, 7, 9],
          rc(0, 7): <int>[8, 9],
        },
        ruleSet: RuleSet.none(),
      );
      expect(scan(hiddenPair, ctx), isEmpty);
    });

    test('E_TECH_001：删数命中终局解 → 整条结论降级', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{
          rc(0, 0): <int>[4, 5, 6, 7],
          rc(0, 3): <int>[4, 5, 8, 9],
          rc(0, 4): <int>[6, 7, 8],
          rc(0, 6): <int>[6, 7, 9],
          rc(0, 7): <int>[8, 9],
        },
        solution: fakeSolutionWith(rc(0, 0), 6),
      );
      expect(scan(hiddenPair, ctx), isEmpty);
    });
  });

  group('HiddenTriple · 正向识别', () {
    test('三数字只落在同三格 → 删去这三格的其余候选', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2, 7],
        rc(0, 3): <int>[2, 3, 8],
        rc(0, 4): <int>[7, 8, 9],
        rc(0, 6): <int>[1, 3, 9],
        rc(0, 7): <int>[7, 8, 9],
      });
      final List<TechniqueResult> results = scan(hiddenTriple, ctx);

      expect(results, hasLength(1));
      expect(
        allEliminationKeys(results),
        <String>{
          elimKey(rc(0, 0), 7),
          elimKey(rc(0, 3), 8),
          elimKey(rc(0, 6), 9),
        },
      );
      expect(results.single.techniqueId, TechniqueId.hiddenTriple);
      expect(hasCompleteHintPayload(results.single), isTrue);
    });
  });

  group('HiddenTriple · 反向「不得上报」', () {
    test('三数字的位置并集为 4 格 → 不构成隐三，不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 7],
        rc(0, 3): <int>[2, 8],
        rc(0, 6): <int>[3, 9],
        rc(0, 8): <int>[1, 2, 3],
      });
      expect(scan(hiddenTriple, ctx), isEmpty);
    });

    test('size 超出 2/3 → 取 id 时抛 E_TECH_003（本期不含隐四）', () {
      const HiddenSubsetTechnique quad = HiddenSubsetTechnique(size: 4);
      expect(() => quad.id, throwsA(isA<CoreException>()));
    });
  });
}
