/// 翼族单测：XY 翼（rank 110）/ XYZ 翼（rank 120）/ W 翼（rank 130）。
///
/// 三者最容易写错的都是**删数格的可见性范围**，本文件针对性地把边界钉死：
/// - XY 翼：删数格需同时看到**两个夹翼**；
/// - XYZ 翼：枢轴本身也含 z，删数格必须同时看到**枢轴 + 两个夹翼**三格；
/// - W 翼：强链必须是**严格共轭对**，出现第 3 个候选位即不成链。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import '../support/technique_fixture.dart';

void main() {
  const XyWingTechnique xyWing = XyWingTechnique();
  const XyzWingTechnique xyzWing = XyzWingTechnique();
  const WWingTechnique wWing = WWingTechnique();

  // ----------------------------------------------------------------- XY 翼

  group('XY 翼 · 正向识别', () {
    test('{1,2} 枢轴 + {1,3}/{2,3} 夹翼 → 公共可见格删 3', () {
      // 枢轴 r1c1={1,2}；夹翼 r1c6={1,3}（同行可见）、r6c1={2,3}（同列可见）；
      // 同时看到两夹翼的 r6c6 不可能是 3。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 5): <int>[1, 3],
        rc(5, 0): <int>[2, 3],
        rc(5, 5): <int>[3, 7],
      });
      final List<TechniqueResult> results = scan(xyWing, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(5, 5), 3)});
      expect(results.single.techniqueId, TechniqueId.xyWing);
      expect(hasCompleteHintPayload(results.single), isTrue);
      expect(results.single.narration.slots['digit'], 3);
    });

    test('rank 与登记表一致', () {
      expect(xyWing.rank, 110);
      expect(xyzWing.rank, 120);
      expect(wWing.rank, 130);
    });
  });

  group('XY 翼 · 反向「不得上报」', () {
    test('三格并集为 4 个数字（未闭合成三元环）→ 不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 5): <int>[1, 3],
        rc(5, 0): <int>[2, 4],
        rc(5, 5): <int>[3, 7],
      });
      expect(scan(xyWing, ctx), isEmpty);
    });

    test('夹翼看不到枢轴 → 不上报', () {
      // r6c6 看不到枢轴 r1c1。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 5): <int>[1, 3],
        rc(5, 5): <int>[2, 3],
        rc(5, 0): <int>[3, 7],
      });
      expect(scan(xyWing, ctx), isEmpty);
    });

    test('两夹翼带同一个枢轴数字（非 x/y 分工）→ 不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 5): <int>[1, 3],
        rc(5, 0): <int>[1, 3],
        rc(5, 5): <int>[3, 7],
      });
      expect(scan(xyWing, ctx), isEmpty);
    });

    test('公共可见格中无 z 候选 → 空结论不外泄', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 5): <int>[1, 3],
        rc(5, 0): <int>[2, 3],
      });
      expect(scan(xyWing, ctx), isEmpty);
    });

    test('规则集未启用 / E_TECH_001 降级', () {
      final Map<int, List<int>> pattern = <int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 5): <int>[1, 3],
        rc(5, 0): <int>[2, 3],
        rc(5, 5): <int>[3, 7],
      };
      expect(scan(xyWing, sandbox(pattern, ruleSet: RuleSet.none())), isEmpty);
      expect(
        scan(xyWing, sandbox(pattern, solution: fakeSolutionWith(rc(5, 5), 3))),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------- XYZ 翼

  group('XYZ 翼 · 正向识别', () {
    test('{1,2,3} 枢轴 + {1,3}/{2,3} 夹翼 → 同时看到三格者删 3', () {
      // 枢轴 r1c1={1,2,3}；夹翼 r1c5={1,3}（同行）、r2c2={2,3}（同宫）；
      // r1c3 同时看到三格（行看枢轴与 r1c5，宫看 r2c2）→ 删 3。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2, 3],
        rc(0, 4): <int>[1, 3],
        rc(1, 1): <int>[2, 3],
        rc(0, 2): <int>[3, 8],
      });
      final List<TechniqueResult> results = scan(xyzWing, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(0, 2), 3)});
      expect(results.single.techniqueId, TechniqueId.xyzWing);
      expect(hasCompleteHintPayload(results.single), isTrue);
    });
  });

  group('XYZ 翼 · 反向「不得上报」', () {
    test('只看到两个夹翼、看不到枢轴的格绝不可删（最易误删的分支）', () {
      // r2c5 能看到 r1c5（同列）与 r2c2（同行），但看不到枢轴 r1c1。
      // XY 翼口径会误删它，XYZ 翼必须静默。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2, 3],
        rc(0, 4): <int>[1, 3],
        rc(1, 1): <int>[2, 3],
        rc(1, 4): <int>[3, 8],
      });
      expect(
        scan(xyzWing, ctx),
        isEmpty,
        reason: 'XYZ 翼的枢轴也含 z，删数格必须同时看到枢轴',
      );
    });

    test('枢轴候选数不是 3 → 不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 4): <int>[1, 3],
        rc(1, 1): <int>[2, 3],
        rc(0, 2): <int>[3, 8],
      });
      expect(scan(xyzWing, ctx), isEmpty);
    });

    test('两夹翼并集 ≠ 枢轴候选（三数字未闭合）→ 不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2, 3],
        rc(0, 4): <int>[1, 3],
        rc(1, 1): <int>[1, 3],
        rc(0, 2): <int>[3, 8],
      });
      expect(scan(xyzWing, ctx), isEmpty);
    });

    test('规则集未启用 / E_TECH_001 降级', () {
      final Map<int, List<int>> pattern = <int, List<int>>{
        rc(0, 0): <int>[1, 2, 3],
        rc(0, 4): <int>[1, 3],
        rc(1, 1): <int>[2, 3],
        rc(0, 2): <int>[3, 8],
      };
      expect(scan(xyzWing, sandbox(pattern, ruleSet: RuleSet.none())), isEmpty);
      expect(
        scan(xyzWing, sandbox(pattern, solution: fakeSolutionWith(rc(0, 2), 3))),
        isEmpty,
      );
    });
  });

  // ------------------------------------------------------------------ W 翼

  /// W 翼正向盘面：
  /// - A=r1c1、B=r5c5 候选同为 {1,2} 且互不可见；
  /// - 第 8 列的 2 恰好出现在 r1c8 / r5c8 → 严格共轭对强链；
  /// - A 看得见 r1c8（同行）、B 看得见 r5c8（同行）；
  /// - 同时看到 A 与 B 的 r1c5 删 1。
  Map<int, List<int>> wWingPattern() => <int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(4, 4): <int>[1, 2],
        rc(0, 7): <int>[2, 3],
        rc(4, 7): <int>[2, 4],
        rc(0, 4): <int>[1, 5],
      };

  group('W 翼 · 正向识别', () {
    test('同候选双值格 + 严格共轭对强链 → 公共可见格删另一个数字', () {
      final SolveContext ctx = sandbox(wWingPattern());
      final List<TechniqueResult> results = scan(wWing, ctx);

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(0, 4), 1)});
      expect(results.single.techniqueId, TechniqueId.wWing);
      expect(hasCompleteHintPayload(results.single), isTrue);
      expect(results.single.narration.slots['linkDigit'], 2);
      expect(results.single.narration.slots['digit'], 1);
    });
  });

  group('W 翼 · 反向「不得上报」', () {
    test('强链单元内该数字出现 3 次（非严格共轭对）→ 不成链，静默', () {
      final Map<int, List<int>> pattern = wWingPattern()
        ..[rc(6, 7)] = <int>[2, 8]; // 第 8 列的 2 变成 3 处
      expect(
        scan(wWing, sandbox(pattern)),
        isEmpty,
        reason: '本项目只认严格共轭对强链，弱链一律不连边',
      );
    });

    test('A、B 互相可见（属裸对场景）→ 让位给 rank 30，不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 3): <int>[1, 2], // 与 A 同行 → 互相可见
        rc(0, 7): <int>[2, 3],
        rc(4, 7): <int>[2, 4],
        rc(0, 4): <int>[1, 5],
      });
      expect(scan(wWing, ctx), isEmpty);
    });

    test('两个双值格候选不完全相同 → 不上报', () {
      final Map<int, List<int>> pattern = wWingPattern()
        ..[rc(4, 4)] = <int>[1, 3];
      expect(scan(wWing, sandbox(pattern)), isEmpty);
    });

    test('公共可见格无可删候选 → 空结论不外泄', () {
      final Map<int, List<int>> pattern = wWingPattern()..remove(rc(0, 4));
      expect(scan(wWing, sandbox(pattern)), isEmpty);
    });

    test('规则集未启用 / E_TECH_001 降级', () {
      expect(
        scan(wWing, sandbox(wWingPattern(), ruleSet: RuleSet.none())),
        isEmpty,
      );
      expect(
        scan(
          wWing,
          sandbox(wWingPattern(), solution: fakeSolutionWith(rc(0, 4), 1)),
        ),
        isEmpty,
      );
    });
  });
}
