/// 唯一矩形族单测：UR 型一（rank 140）/ UR 型二（rank 150）+ 前提收口。
///
/// UR 是全项目**最危险**的一族：推理依据不是候选分布，而是「题目保证唯一解」
/// 这一外部事实。前提一旦不成立，删数就是错的。本文件逐条钉死
/// `UrSupport` 的五条前提，以及两个型别各自的「不得上报」分支。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import '../support/technique_fixture.dart';

/// 在纯候选沙盘基础上，把 [givens] 标记为题面给定格（用于前提 4 的反例）。
SolveContext sandboxWithGivens(
  Map<int, List<int>> candidates,
  Set<int> givens, {
  bool uniqueSolutionGuaranteed = true,
}) {
  final Board board = candidateBoard(candidates);
  for (final int index in givens) {
    board.setGiven(index, true);
  }
  return contextOf(board, uniqueSolutionGuaranteed: uniqueSolutionGuaranteed);
}

void main() {
  const UrType1Technique urType1 = UrType1Technique();
  const UrType2Technique urType2 = UrType2Technique();

  /// 型一盘面：r1c1 / r1c4 / r2c1 三个地板格为 {1,2}，
  /// 屋顶格 r2c4 为 {1,2,5}；4 格跨第 1、2 两宫。
  Map<int, List<int>> type1Pattern() => <int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 3): <int>[1, 2],
        rc(1, 0): <int>[1, 2],
        rc(1, 3): <int>[1, 2, 5],
      };

  /// 型二盘面：地板 r1c1 / r1c4 = {1,2}，屋顶 r2c1 / r2c4 = {1,2,5}（同行），
  /// 公共可见格 r2c7 含 5。
  Map<int, List<int>> type2Pattern() => <int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 3): <int>[1, 2],
        rc(1, 0): <int>[1, 2, 5],
        rc(1, 3): <int>[1, 2, 5],
        rc(1, 6): <int>[5, 7],
      };

  // ------------------------------------------------------------ UrSupport

  group('UrSupport · 五条前提收口', () {
    test('合法矩形被正确枚举，地板/屋顶分类正确', () {
      final List<UrRectangle> rectangles =
          UrSupport.enumerate(sandbox(type1Pattern()));

      expect(rectangles, hasLength(1));
      final UrRectangle rectangle = rectangles.single;
      expect(rectangle.cells,
          equals(<int>[rc(0, 0), rc(0, 3), rc(1, 0), rc(1, 3)]));
      expect(rectangle.pair.digits(), equals(<int>[1, 2]));
      expect(rectangle.boxes, equals(<int>[0, 1]));
      expect(rectangle.floorCells, hasLength(3));
      expect(rectangle.roofCells, equals(<int>[rc(1, 3)]));
    });

    test('前提 1：uniqueSolutionGuaranteed=false → 整族返回空', () {
      final SolveContext ctx =
          sandbox(type1Pattern(), uniqueSolutionGuaranteed: false);
      expect(UrSupport.isEnabled(ctx), isFalse);
      expect(UrSupport.enumerate(ctx), isEmpty);
      expect(
        () => UrSupport.requireEnabled(ctx),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_TECH_002')),
      );
    });

    test('前提 3：4 格落在同一宫（未跨 2 宫）→ 不是致命模式', () {
      // 列改成 c1/c2 → 4 格全在第 1 宫。
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[1, 2],
        rc(1, 0): <int>[1, 2],
        rc(1, 1): <int>[1, 2, 5],
      });
      expect(UrSupport.enumerate(ctx), isEmpty);
    });

    test('前提 4：任一角为题面给定格 → 不产出矩形', () {
      final SolveContext ctx = sandboxWithGivens(
        type1Pattern(),
        <int>{rc(0, 0)},
      );
      expect(UrSupport.enumerate(ctx), isEmpty);
    });

    test('前提 5：4 格候选交集不是恰好 2 个数字 → 不产出矩形', () {
      final Map<int, List<int>> pattern = type1Pattern()
        ..[rc(0, 0)] = <int>[1, 3];
      expect(UrSupport.enumerate(sandbox(pattern)), isEmpty);
    });
  });

  // -------------------------------------------------------------- UR 型一

  group('UR 型一 · 正向识别', () {
    test('3 个地板 + 1 个屋顶 → 删去屋顶格的共享候选对', () {
      final List<TechniqueResult> results =
          scan(urType1, sandbox(type1Pattern()));

      expect(results, hasLength(1));
      expect(
        allEliminationKeys(results),
        <String>{elimKey(rc(1, 3), 1), elimKey(rc(1, 3), 2)},
      );
      expect(results.single.techniqueId, TechniqueId.urType1);
      expect(hasCompleteHintPayload(results.single), isTrue);
      expect(urType1.rank, 140);
    });
  });

  group('UR 型一 · 反向「不得上报」', () {
    test('唯一解无保证 → 静默（架构红线：外部事实不成立即整族禁用）', () {
      expect(
        scan(urType1, sandbox(type1Pattern(), uniqueSolutionGuaranteed: false)),
        isEmpty,
      );
    });

    test('角格是题面给定格 → 静默', () {
      expect(
        scan(urType1, sandboxWithGivens(type1Pattern(), <int>{rc(1, 0)})),
        isEmpty,
      );
    });

    test('只有 2 个地板格（属型二范畴）→ 型一静默', () {
      expect(scan(urType1, sandbox(type2Pattern())), isEmpty);
    });

    test('屋顶格删去共享对后将无候选（死格）→ 保守静默', () {
      // 屋顶格候选就等于共享对本身时不构成型一；
      // 这里让屋顶只比地板多出「已被占用」的情形：4 格全为 {1,2}。
      final Map<int, List<int>> pattern = type1Pattern()
        ..[rc(1, 3)] = <int>[1, 2];
      expect(scan(urType1, sandbox(pattern)), isEmpty);
    });

    test('规则集未启用 / E_TECH_001 降级', () {
      expect(
        scan(urType1, sandbox(type1Pattern(), ruleSet: RuleSet.none())),
        isEmpty,
      );
      expect(
        scan(urType1,
            sandbox(type1Pattern(), solution: fakeSolutionWith(rc(1, 3), 1))),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------- UR 型二

  group('UR 型二 · 正向识别', () {
    test('2 地板 + 2 同行屋顶且多余候选同为 5 → 公共可见格删 5', () {
      final List<TechniqueResult> results =
          scan(urType2, sandbox(type2Pattern()));

      expect(results, hasLength(1));
      expect(allEliminationKeys(results), <String>{elimKey(rc(1, 6), 5)});
      expect(results.single.techniqueId, TechniqueId.urType2);
      expect(hasCompleteHintPayload(results.single), isTrue);
      expect(results.single.narration.slots['extraDigit'], 5);
      expect(urType2.rank, 150);
    });
  });

  group('UR 型二 · 反向「不得上报」', () {
    test('两屋顶呈对角分布（Type 2b/2c）→ 本期不实现，静默', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2, 5],
        rc(0, 3): <int>[1, 2],
        rc(1, 0): <int>[1, 2],
        rc(1, 3): <int>[1, 2, 5],
        rc(1, 6): <int>[5, 7],
      });
      expect(scan(urType2, ctx), isEmpty);
    });

    test('两屋顶的多余候选不是同一个数字（Type 3/5/6）→ 静默', () {
      final Map<int, List<int>> pattern = type2Pattern()
        ..[rc(1, 3)] = <int>[1, 2, 6];
      expect(scan(urType2, sandbox(pattern)), isEmpty);
    });

    test('屋顶多余候选不止 1 个 → 静默', () {
      final Map<int, List<int>> pattern = type2Pattern()
        ..[rc(1, 0)] = <int>[1, 2, 5, 6]
        ..[rc(1, 3)] = <int>[1, 2, 5, 6];
      expect(scan(urType2, sandbox(pattern)), isEmpty);
    });

    test('地板数不是 2（属型一范畴）→ 型二静默', () {
      expect(scan(urType2, sandbox(type1Pattern())), isEmpty);
    });

    test('公共可见格无该多余候选 → 空结论不外泄', () {
      final Map<int, List<int>> pattern = type2Pattern()..remove(rc(1, 6));
      expect(scan(urType2, sandbox(pattern)), isEmpty);
    });

    test('唯一解无保证 / 规则集未启用 / E_TECH_001 降级', () {
      expect(
        scan(urType2, sandbox(type2Pattern(), uniqueSolutionGuaranteed: false)),
        isEmpty,
      );
      expect(
        scan(urType2, sandbox(type2Pattern(), ruleSet: RuleSet.none())),
        isEmpty,
      );
      expect(
        scan(urType2,
            sandbox(type2Pattern(), solution: fakeSolutionWith(rc(1, 6), 5))),
        isEmpty,
      );
    });
  });
}
