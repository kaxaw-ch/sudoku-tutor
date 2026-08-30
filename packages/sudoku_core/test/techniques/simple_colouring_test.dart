/// T-TEC-16 简单涂色（Simple Colouring，rank 160，T2）单测 + 共轭对图底座。
///
/// 本期 scope 只含两条规则，测试逐条覆盖：
/// - 规则二·色链陷阱：链外格同时看到两色 → 删它的该数字；
/// - 规则四·同色矛盾：同色两格互相可见 → 该色整体为假，删该色全部格。
///
/// 同时钉死「只认严格共轭对」这条底座红线：单元内该数字出现 ≥3 次即不连边。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import '../support/technique_fixture.dart';

void main() {
  const SimpleColouringTechnique technique = SimpleColouringTechnique();

  /// 规则二盘面（数字 5）：
  /// 强链 c1{r1c1,r5c1}、r5{r5c1,r5c8}、c8{r1c8,r5c8} 构成一条链；
  /// 染色后 色A={r1c1,r5c8}、色B={r1c8,r5c1}；
  /// 第 1 行故意放 3 个 5（r1c1/r1c4/r1c8）以**避免**第 1 行成链，
  /// 于是链外格 r1c4 同时看到 r1c1(色A) 与 r1c8(色B) → 删它的 5。
  Map<int, List<int>> trapPattern() => <int, List<int>>{
        rc(0, 0): <int>[5],
        rc(0, 3): <int>[5, 9],
        rc(0, 7): <int>[5],
        rc(4, 0): <int>[5],
        rc(4, 7): <int>[5],
      };

  /// 规则四盘面（数字 5）：
  /// 强链 c1{r1c1,r9c1}、box1{r1c1,r2c2}、r2{r2c2,r2c5}、c5{r2c5,r9c5}；
  /// 染色后 色B={r2c2,r9c1,r9c5}，其中 r9c1 与 r9c5 同在第 9 行 → 同色矛盾。
  /// 第 9 行放 3 个 5（r9c1/r9c5/r9c9）以避免第 9 行自己成链。
  Map<int, List<int>> wrapPattern() => <int, List<int>>{
        rc(0, 0): <int>[5],
        rc(1, 1): <int>[5],
        rc(1, 4): <int>[5],
        rc(8, 0): <int>[5],
        rc(8, 4): <int>[5],
        rc(8, 8): <int>[5],
      };

  group('ConjugateGraph · 严格共轭对底座', () {
    test('单元内该数字恰好 2 处 → 连边；≥3 处 → 不连边', () {
      final SolveContext two = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(4, 0): <int>[5],
      });
      final ConjugateGraph graphTwo = ConjugateGraph.build(two, 5);
      expect(graphTwo.links, hasLength(1));
      expect(graphTwo.links.single.a, rc(0, 0));
      expect(graphTwo.links.single.b, rc(4, 0));
      expect(graphTwo.links.single.unitType, UnitType.col);

      final SolveContext three = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(4, 0): <int>[5],
        rc(8, 0): <int>[5],
      });
      expect(
        ConjugateGraph.build(three, 5).isEmpty,
        isTrue,
        reason: '出现第 3 个候选位即为弱链，不得连边',
      );
    });

    test('连通分量被稳定地双色染色', () {
      final ConjugateGraph graph = ConjugateGraph.build(sandbox(trapPattern()), 5);
      final List<Map<int, int>> components = graph.colouredComponents();
      expect(components, hasLength(1));
      final Map<int, int> colours = components.single;
      expect(colours.keys.toSet(),
          equals(<int>{rc(0, 0), rc(0, 7), rc(4, 0), rc(4, 7)}));
      // 强链两端必然异色。
      for (final ConjugateLink link in graph.links) {
        expect(colours[link.a], isNot(equals(colours[link.b])));
      }
    });
  });

  group('规则二 · 色链陷阱', () {
    test('链外格同时看到两色 → 删去它的该数字', () {
      final List<TechniqueResult> results = scan(technique, sandbox(trapPattern()));

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(0, 3), 5)});
      expect(results.single.techniqueId, TechniqueId.simpleColouring);
      expect(
        results.single.narration.slots['ruleLabel'],
        SimpleColouringTechnique.ruleTrapLabel,
      );
      expect(hasCompleteHintPayload(results.single), isTrue);
      expect(technique.rank, 160);
    });

    test('只看到单色的链外格不得被删（零误报）', () {
      // 唯一强链 c1{r1c1, r5c1} → 色A={r1c1}、色B={r5c1}。
      // r1c4 与 r1c7 都只经第 1 行看到色A 的 r1c1，看不到色B → 一个都不许删。
      // （第 1 行故意保持 3 个 5，避免第 1 行自己成链而改变拓扑。）
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(4, 0): <int>[5],
        rc(0, 3): <int>[5, 9],
        rc(0, 6): <int>[5, 9],
      });
      expect(
        scan(technique, ctx),
        isEmpty,
        reason: '色链陷阱要求同时看到两色，只看到单色不构成任何结论',
      );
    });
  });

  group('规则四 · 同色矛盾', () {
    test('同色两格互相可见 → 该色整体为假，删该色全部格的该数字', () {
      final List<TechniqueResult> results = scan(technique, sandbox(wrapPattern()));

      expect(results, hasLength(1));
      expect(
        allEliminationKeys(results),
        <String>{
          elimKey(rc(1, 1), 5),
          elimKey(rc(8, 0), 5),
          elimKey(rc(8, 4), 5),
        },
      );
      expect(
        results.single.narration.slots['ruleLabel'],
        SimpleColouringTechnique.ruleWrapLabel,
      );
      expect(hasCompleteHintPayload(results.single), isTrue);
    });
  });

  group('反向「不得上报」', () {
    test('不存在严格共轭对 → 图为空，静默', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(4, 0): <int>[5],
        rc(8, 0): <int>[5],
      });
      expect(scan(technique, ctx), isEmpty);
    });

    test('有链但既无陷阱也无同色矛盾 → 静默', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(4, 0): <int>[5],
      });
      expect(scan(technique, ctx), isEmpty);
    });

    test('规则集未启用 → 不上报', () {
      expect(
        scan(technique, sandbox(trapPattern(), ruleSet: RuleSet.none())),
        isEmpty,
      );
    });

    test('E_TECH_001：删数命中终局解 → 整条结论降级为无提示', () {
      expect(
        scan(technique,
            sandbox(trapPattern(), solution: fakeSolutionWith(rc(0, 3), 5))),
        isEmpty,
      );
      expect(
        scan(technique,
            sandbox(wrapPattern(), solution: fakeSolutionWith(rc(8, 0), 5))),
        isEmpty,
      );
    });
  });
}
