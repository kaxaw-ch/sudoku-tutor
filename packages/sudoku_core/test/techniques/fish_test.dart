/// Fish 族单测：X 翼（rank 80）/ 剑鱼（rank 100）/ 鳍形 X 翼（rank 90）。
///
/// 三者共用 `fish_support.dart` 的行列对称扫描，放在同一文件便于交叉验证
/// 「同一盘面只能被**恰当**的那一项识别」这条精确率红线：
/// - 退化成 X 翼的三行模式**不得**以剑鱼上报；
/// - 有鳍的模式**不得**以普通 X 翼上报。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import '../support/technique_fixture.dart';

void main() {
  const XWingTechnique xWing = XWingTechnique();
  const SwordfishTechnique swordfish = SwordfishTechnique();
  const FinnedXWingTechnique finned = FinnedXWingTechnique();

  // ------------------------------------------------------------------ X 翼

  group('X 翼 · 正向识别', () {
    test('两行的 5 各恰好 2 处且列号相同 → 删去这两列其余格的 5', () {
      // 基行 r1 / r5，覆盖列 c2 / c6；r3c2 是覆盖列上的多余 5。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 5): <int>[5],
        rc(4, 1): <int>[5],
        rc(4, 5): <int>[5],
        rc(2, 1): <int>[5, 9],
      });
      final List<TechniqueResult> results = scan(xWing, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(2, 1), 5)});
      expect(results.single.techniqueId, TechniqueId.xWing);
      expect(hasCompleteHintPayload(results.single), isTrue);
    });

    test('rank 与登记表一致', () {
      expect(xWing.rank, 80);
      expect(swordfish.rank, 100);
      expect(finned.rank, 90);
    });
  });

  group('X 翼 · 反向「不得上报」', () {
    test('基行候选位置数为 3 → 不构成 X 翼', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 5): <int>[5],
        rc(0, 7): <int>[5],
        rc(4, 1): <int>[5],
        rc(4, 5): <int>[5],
        rc(2, 1): <int>[5, 9],
      });
      expect(scan(xWing, ctx), isEmpty);
    });

    test('两行列号集合不同 → 不构成 X 翼', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 5): <int>[5],
        rc(4, 1): <int>[5],
        rc(4, 6): <int>[5],
        rc(2, 1): <int>[5, 9],
      });
      expect(scan(xWing, ctx), isEmpty);
    });

    test('模式成立但覆盖列无可删候选 → 空结论不外泄', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 5): <int>[5],
        rc(4, 1): <int>[5],
        rc(4, 5): <int>[5],
      });
      expect(scan(xWing, ctx), isEmpty);
    });

    test('规则集未启用 / E_TECH_001 降级', () {
      final Map<int, List<int>> pattern = <int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 5): <int>[5],
        rc(4, 1): <int>[5],
        rc(4, 5): <int>[5],
        rc(2, 1): <int>[5, 9],
      };
      expect(scan(xWing, sandbox(pattern, ruleSet: RuleSet.none())), isEmpty);
      expect(
        scan(xWing, sandbox(pattern, solution: fakeSolutionWith(rc(2, 1), 5))),
        isEmpty,
      );
    });
  });

  // ------------------------------------------------------------------ 剑鱼

  group('剑鱼 · 正向识别', () {
    test('三行的 5 列号并集恰为 3 列 → 删去这 3 列其余格的 5', () {
      // r1={c2,c5}, r5={c5,c8}, r9={c2,c8}，并集 {c2,c5,c8}；
      // 任意两行的并集都是 3 列，不退化为 X 翼。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 4): <int>[5],
        rc(4, 4): <int>[5],
        rc(4, 7): <int>[5],
        rc(8, 1): <int>[5],
        rc(8, 7): <int>[5],
        rc(2, 4): <int>[5, 9],
      });
      final List<TechniqueResult> results = scan(swordfish, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(2, 4), 5)});
      expect(results.single.techniqueId, TechniqueId.swordfish);
      expect(hasCompleteHintPayload(results.single), isTrue);
    });
  });

  group('剑鱼 · 反向「不得上报」', () {
    test('退化为 X 翼的三行模式：剑鱼静默，X 翼正常命中', () {
      // r1 与 r5 的列号都恰好是 {c2,c5} → 两行并集只有 2 列 = X 翼本体。
      final Map<int, List<int>> pattern = <int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 4): <int>[5],
        rc(4, 1): <int>[5],
        rc(4, 4): <int>[5],
        rc(8, 1): <int>[5],
        rc(8, 4): <int>[5],
        rc(8, 7): <int>[5],
        rc(2, 4): <int>[5, 9],
      };
      final SolveContext ctx = sandbox(pattern);

      expect(
        scan(swordfish, ctx),
        isEmpty,
        reason: '退化形态必须让位给 rank 更低的 X 翼，不得以剑鱼上报',
      );
      expect(scan(xWing, sandbox(pattern)), isNotEmpty);
    });

    test('列号并集为 4 列 → 不构成标准剑鱼', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 4): <int>[5],
        rc(4, 4): <int>[5],
        rc(4, 7): <int>[5],
        rc(8, 1): <int>[5],
        rc(8, 6): <int>[5],
        rc(2, 4): <int>[5, 9],
      });
      expect(scan(swordfish, ctx), isEmpty);
    });

    test('规则集未启用 / E_TECH_001 降级', () {
      final Map<int, List<int>> pattern = <int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 4): <int>[5],
        rc(4, 4): <int>[5],
        rc(4, 7): <int>[5],
        rc(8, 1): <int>[5],
        rc(8, 7): <int>[5],
        rc(2, 4): <int>[5, 9],
      };
      expect(scan(swordfish, sandbox(pattern, ruleSet: RuleSet.none())), isEmpty);
      expect(
        scan(swordfish,
            sandbox(pattern, solution: fakeSolutionWith(rc(2, 4), 5))),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------- 鳍形 X 翼

  group('鳍形 X 翼 · 正向识别', () {
    test('单鳍且与一个覆盖角同宫 → 只删「鳍所在宫」内的覆盖列格', () {
      // 干净基行 r1 = {c1, c5}；带鳍基行 r2 = {c5(核心), c2(鳍)}；
      // 鳍 r2c2 与覆盖角 r2c1 同宫（第 1 宫）→ 删数区 = c1 列上第 1 宫内、
      // 且不在两条基行上的格 = r3c1。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(0, 4): <int>[5],
        rc(1, 1): <int>[5],
        rc(1, 4): <int>[5],
        rc(2, 0): <int>[5, 9],
      });
      final List<TechniqueResult> results = scan(finned, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(2, 0), 5)});
      expect(results.single.techniqueId, TechniqueId.finnedXWing);
      expect(hasCompleteHintPayload(results.single), isTrue);
      // Sashimi：带鳍基行缺了 r2c1 这个角，模式依然成立。
      expect(ctx.candidatesAt(rc(1, 0)).contains(5), isFalse);
    });

    test('删数严格限制在鳍所在宫内，不得波及整条覆盖列', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(0, 4): <int>[5],
        rc(1, 1): <int>[5],
        rc(1, 4): <int>[5],
        rc(2, 0): <int>[5, 9],
        rc(6, 0): <int>[5, 9], // 同在 c1 列，但属第 7 宫 → 绝不可删
      });
      final Set<String> keys = allEliminationKeys(scan(finned, ctx));
      expect(keys, contains(elimKey(rc(2, 0), 5)));
      expect(
        keys.contains(elimKey(rc(6, 0), 5)),
        isFalse,
        reason: '鳍宫之外的覆盖列格不在删数区，删了就是误删',
      );
    });
  });

  group('鳍形 X 翼 · 反向「不得上报」', () {
    test('鳍格有 2 个（多鳍形态）→ 本期不实现，静默', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(0, 4): <int>[5],
        rc(1, 1): <int>[5],
        rc(1, 4): <int>[5],
        rc(1, 7): <int>[5],
        rc(2, 0): <int>[5, 9],
      });
      expect(scan(finned, ctx), isEmpty);
    });

    test('鳍与两个覆盖角都不同宫（跨宫鳍）→ 静默', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[5],
        rc(0, 4): <int>[5],
        rc(1, 7): <int>[5],
        rc(1, 4): <int>[5],
        rc(2, 0): <int>[5, 9],
      });
      expect(scan(finned, ctx), isEmpty);
    });

    test('无鳍的纯 X 翼形态 → 由 X 翼负责，鳍形不重复上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 1): <int>[5],
        rc(0, 5): <int>[5],
        rc(4, 1): <int>[5],
        rc(4, 5): <int>[5],
        rc(2, 1): <int>[5, 9],
      });
      expect(scan(finned, ctx), isEmpty);
    });

    test('规则集未启用 / E_TECH_001 降级', () {
      final Map<int, List<int>> pattern = <int, List<int>>{
        rc(0, 0): <int>[5],
        rc(0, 4): <int>[5],
        rc(1, 1): <int>[5],
        rc(1, 4): <int>[5],
        rc(2, 0): <int>[5, 9],
      };
      expect(scan(finned, sandbox(pattern, ruleSet: RuleSet.none())), isEmpty);
      expect(
        scan(finned, sandbox(pattern, solution: fakeSolutionWith(rc(2, 0), 5))),
        isEmpty,
      );
    });
  });
}
