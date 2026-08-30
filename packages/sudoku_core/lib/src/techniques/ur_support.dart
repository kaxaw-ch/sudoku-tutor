/// 唯一矩形族（UR）的**前提校验与矩形枚举**（doc 06 §6.2，doc 08 风险 1 最高优先级）。
///
/// UR 是全项目**最危险**的一族技巧：它的推理依据不是候选分布，而是
/// 「题目保证唯一解」这一外部事实。前提一旦不成立，删数就是错的。
/// 因此本文件把 5 条前提集中收口，`UrType1` / `UrType2` 只允许经由这里取矩形。
///
/// **五条前提（全部满足才产出矩形，任一不满足一律静默返回空）**：
/// 1. `ctx.uniqueSolutionGuaranteed == true`（doc 06 风险 A-07）；
/// 2. 4 格构成 **2 行 × 2 列**；
/// 3. 4 格恰好跨 **2 个宫**（跨 1 宫或 4 宫都不是致命模式）；
/// 4. 4 格**全部为空格且全部非题面给定**（`Board.givenMask`，PRD C-11）；
/// 5. 4 格候选的**交集恰好为 2 个数字**（有且仅有一个共享候选对）。
///
/// **明确不实现**（越界即误删）：Hidden UR、Avoidable Rectangle、
/// UR Type 3/4/5/6、以及对角线型 Type 2b —— 一律不产出结论。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../util/core_error.dart';
import 'solve_context.dart';

/// 一个通过全部前提校验的唯一矩形。
class UrRectangle {
  /// 构造一个已校验的矩形（仅供 [UrSupport] 内部使用）。
  const UrRectangle({
    required this.cells,
    required this.pair,
    required this.rows,
    required this.cols,
    required this.boxes,
    required this.floorCells,
    required this.roofCells,
  });

  /// 4 个角格索引（升序：左上、右上、左下、右下）。
  final List<int> cells;

  /// 共享候选对（恰好 2 个数字）。
  final CandidateSet pair;

  /// 两个行号（升序）。
  final List<int> rows;

  /// 两个列号（升序）。
  final List<int> cols;

  /// 两个宫号（升序）。
  final List<int> boxes;

  /// 「地板格」：候选恰好等于 [pair] 的角格（升序）。
  final List<int> floorCells;

  /// 「屋顶格」：候选严格包含 [pair] 且另有多余候选的角格（升序）。
  final List<int> roofCells;

  /// 共享候选对的中文标签，如 `2、7`。
  String get pairLabel => pair.digits().join('、');

  /// 4 角格的中文标签，如 `r2c3、r2c8、r7c3、r7c8`。
  String get cellsLabel => Coord.labelAll(cells);

  @override
  String toString() => 'UrRectangle([$cellsLabel],pair=${pair.describe()})';
}

/// UR 前提校验与矩形枚举（全部为静态纯函数）。
abstract final class UrSupport {
  /// UR 族在 [ctx] 下是否被允许运行（前提 1）。
  ///
  /// 唯一解无保证时（如玩家手工导入的题目）必须整族禁用。
  static bool isEnabled(SolveContext ctx) => ctx.uniqueSolutionGuaranteed;

  /// 强校验版本：前提不满足抛 `E_TECH_002`。
  ///
  /// 供 CLI 严格模式 / 单测显式断言使用；识别器主路径用 [isEnabled] 静默跳过。
  static void requireEnabled(SolveContext ctx) {
    if (!isEnabled(ctx)) {
      throw const CoreException(
        CoreErrorCode.techUniquenessPrecondition,
        '唯一矩形族要求 uniqueSolutionGuaranteed == true',
      );
    }
  }

  /// 枚举当前盘面上全部满足五条前提的唯一矩形（按角格升序稳定输出）。
  ///
  /// 前提 1 不满足时**直接返回空列表**（不抛异常）。
  static List<UrRectangle> enumerate(SolveContext ctx) {
    if (!isEnabled(ctx)) {
      return const <UrRectangle>[];
    }
    final List<UrRectangle> result = <UrRectangle>[];
    for (int r1 = 0; r1 < kBoardSize - 1; r1++) {
      for (int r2 = r1 + 1; r2 < kBoardSize; r2++) {
        for (int c1 = 0; c1 < kBoardSize - 1; c1++) {
          for (int c2 = c1 + 1; c2 < kBoardSize; c2++) {
            final UrRectangle? rectangle = tryBuild(ctx, r1, r2, c1, c2);
            if (rectangle != null) {
              result.add(rectangle);
            }
          }
        }
      }
    }
    return result;
  }

  /// 尝试按给定行列构造矩形；任一前提不满足返回 `null`。
  static UrRectangle? tryBuild(SolveContext ctx, int r1, int r2, int c1, int c2) {
    if (!isEnabled(ctx)) {
      return null;
    }
    // 前提 2：2 行 × 2 列（行列必须两两不同）。
    if (r1 == r2 || c1 == c2) {
      return null;
    }
    final List<int> cells = <int>[
      Coord.indexOf(r1, c1),
      Coord.indexOf(r1, c2),
      Coord.indexOf(r2, c1),
      Coord.indexOf(r2, c2),
    ];

    // 前提 4：4 格全部为空格且全部非题面给定（givenMask，PRD C-11）。
    for (final int index in cells) {
      if (!ctx.board.isBlank(index)) {
        return null;
      }
      if (ctx.givenMask[index]) {
        return null;
      }
    }

    // 前提 3：恰好跨 2 个宫。
    final Set<int> boxSet = <int>{for (final int index in cells) Coord.boxOf(index)};
    if (boxSet.length != 2) {
      return null;
    }

    // 前提 5：4 格候选交集恰好 2 个数字（有且仅有一个共享候选对）。
    CandidateSet common = ctx.candidatesAt(cells.first);
    for (final int index in cells.skip(1)) {
      common = common.intersect(ctx.candidatesAt(index));
    }
    if (common.count() != 2) {
      return null;
    }

    final List<int> floors = <int>[];
    final List<int> roofs = <int>[];
    for (final int index in cells) {
      if (ctx.candidatesAt(index).mask == common.mask) {
        floors.add(index);
      } else {
        roofs.add(index);
      }
    }
    // 地板格少于 2 个时不构成致命模式雏形（Type1 需 3 个、Type2 需 2 个）。
    if (floors.length < 2) {
      return null;
    }

    final List<int> boxes = boxSet.toList()..sort();
    return UrRectangle(
      cells: List<int>.unmodifiable(cells),
      pair: common,
      rows: List<int>.unmodifiable(<int>[r1, r2]),
      cols: List<int>.unmodifiable(<int>[c1, c2]),
      boxes: List<int>.unmodifiable(boxes),
      floorCells: List<int>.unmodifiable(floors),
      roofCells: List<int>.unmodifiable(roofs),
    );
  }
}
