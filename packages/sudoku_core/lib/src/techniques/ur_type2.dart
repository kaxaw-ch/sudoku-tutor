/// T-TEC-13 唯一矩形 型二（Unique Rectangle Type 2，rank 150）。
///
/// 判定：矩形 4 格中**恰好 2 格**候选为共享对 `{a, b}`（地板），
/// 另 2 格（屋顶）候选恰为 `{a, b, c}`——**同一个**多余数字 c，
/// 且两屋顶格同行或同列
/// → 若两屋顶格都不取 c，矩形将出现双解；故 c 必在两屋顶之一
/// → 同时看到两个屋顶格的其余格可删去 c。
///
/// **不得上报**的情形（前提由 [UrSupport] 统一收口，任一不满足即静默）：
/// - `uniqueSolutionGuaranteed == false`；
/// - 4 格未构成 2 行 × 2 列，或未恰好跨 2 宫；
/// - 4 格中存在**已填格**或**题面给定格**（`Board.givenMask`，PRD C-11）；
/// - 4 格候选交集 ≠ 2 个数字；
/// - 地板格数 ≠ 2 或屋顶格数 ≠ 2；
/// - 两屋顶格的多余候选不是**同一个单一数字**（那是 Type 3/5/6 范畴）；
/// - **两屋顶格呈对角分布**（Type 2b/2c，本期不实现）；
/// - 公共可见格中无任何 c 候选。
///
/// **明确不实现**：Hidden UR、Avoidable Rectangle、UR Type 3/4/5/6、对角型 2b/2c。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../narrative/narration_params.dart';
import '../visual/mark_role.dart';
import '../visual/region_mark.dart';
import '../visual/visual_hint.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';
import 'ur_support.dart';

/// 唯一矩形 型二识别器。
final class UrType2Technique extends TechniqueBase {
  /// 构造识别器。
  const UrType2Technique();

  @override
  TechniqueId get id => TechniqueId.urType2;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    if (!UrSupport.isEnabled(ctx)) {
      return results;
    }

    for (final UrRectangle rectangle in UrSupport.enumerate(ctx)) {
      // 型二：恰好 2 个地板格 + 2 个屋顶格。
      if (rectangle.floorCells.length != 2 || rectangle.roofCells.length != 2) {
        continue;
      }
      final int roof1 = rectangle.roofCells[0];
      final int roof2 = rectangle.roofCells[1];

      // 两屋顶格必须同行或同列；对角分布属 Type 2b/2c，本期静默。
      final bool sameRow = Coord.rowOf(roof1) == Coord.rowOf(roof2);
      final bool sameCol = Coord.colOf(roof1) == Coord.colOf(roof2);
      if (!sameRow && !sameCol) {
        continue;
      }

      final CandidateSet extra1 =
          ctx.candidatesAt(roof1).difference(rectangle.pair);
      final CandidateSet extra2 =
          ctx.candidatesAt(roof2).difference(rectangle.pair);
      // 多余候选必须是同一个单一数字。
      if (extra1.count() != 1 || extra2.count() != 1 || extra1.mask != extra2.mask) {
        continue;
      }
      final int extraDigit = extra1.lowest;

      final List<int> targets = TechniqueSupport.commonPeersWithCandidate(
        ctx,
        <int>[roof1, roof2],
        extraDigit,
      );
      final List<Elimination> eliminations = TechniqueSupport.eliminateDigit(
        ctx,
        extraDigit,
        targets,
        excluded: rectangle.cells.toSet(),
      );
      if (eliminations.isEmpty) {
        continue;
      }

      final TechniqueResult built = TechniqueResult(
        techniqueId: id,
        eliminations: eliminations,
        visual: VisualHint.assemble(
          patternCells: rectangle.floorCells,
          pincerCells: rectangle.roofCells,
          focusDigits: rectangle.pair.plus(extraDigit),
          emphasized: <MapEntry<int, int>>[
            ...TechniqueSupport.emphasisEntriesOfDigits(
              ctx,
              rectangle.cells,
              rectangle.pair,
            ),
            ...TechniqueSupport.emphasisEntries(
              rectangle.roofCells,
              extraDigit,
            ),
          ],
          eliminated: TechniqueSupport.elimEntries(eliminations),
          regions: <RegionMark>[
            RegionMark(cornerCells: rectangle.cells, role: MarkRole.pattern),
          ],
        ),
        narration: NarrationParams(
          techniqueId: id,
          slots: <String, Object?>{
            'cellsLabel': rectangle.cellsLabel,
            'pairDigits': rectangle.pairLabel,
            'extraCells': Coord.labelAll(rectangle.roofCells),
            'extraDigit': extraDigit,
            'elimList': TechniqueSupport.elimListLabel(eliminations),
          },
        ),
      );
      final TechniqueResult? safe = TechniqueSupport.emit(ctx, built);
      if (safe == null) {
        continue;
      }
      results.add(safe);
      if (results.length >= limit) {
        return results;
      }
    }
    return results;
  }
}
