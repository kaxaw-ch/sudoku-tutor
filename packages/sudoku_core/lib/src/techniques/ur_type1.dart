/// T-TEC-12 唯一矩形 型一（Unique Rectangle Type 1，rank 140）。
///
/// 判定：矩形 4 格中**恰好 3 格**候选为共享对 `{a, b}`，第 4 格候选为
/// `{a, b} + 其它` → 若第 4 格也取 a 或 b，则 `{a,b}` 可在矩形内自由互换，
/// 谜题将出现双解；与「题目唯一解」矛盾
/// → 第 4 格的 a、b 必须删除。
///
/// **不得上报**的情形（前提由 [UrSupport] 统一收口，任一不满足即静默）：
/// - `uniqueSolutionGuaranteed == false`；
/// - 4 格未构成 2 行 × 2 列，或未恰好跨 2 宫；
/// - 4 格中存在**已填格**或**题面给定格**（`Board.givenMask`，PRD C-11）；
/// - 4 格候选交集 ≠ 2 个数字（共享候选对不唯一）；
/// - 地板格数 ≠ 3（那是型二或更高型，本技巧不管）；
/// - 第 4 格删去 a、b 后将无候选（会造成死格，保守静默）。
///
/// **明确不实现**：Hidden UR、Avoidable Rectangle、UR Type 3/4/5/6。
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

/// 唯一矩形 型一识别器。
final class UrType1Technique extends TechniqueBase {
  /// 构造识别器。
  const UrType1Technique();

  @override
  TechniqueId get id => TechniqueId.urType1;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    // 前提 1：唯一解无保证时整族禁用。
    if (!UrSupport.isEnabled(ctx)) {
      return results;
    }

    for (final UrRectangle rectangle in UrSupport.enumerate(ctx)) {
      // 型一：恰好 3 个地板格 + 1 个屋顶格。
      if (rectangle.floorCells.length != 3 || rectangle.roofCells.length != 1) {
        continue;
      }
      final int extraCell = rectangle.roofCells.single;
      final CandidateSet extraSet =
          ctx.candidatesAt(extraCell).difference(rectangle.pair);
      // 删去 a、b 后必须还剩候选，否则会造出死格 —— 保守静默。
      if (extraSet.isEmpty) {
        continue;
      }

      final List<Elimination> eliminations = TechniqueSupport.eliminateDigits(
        ctx,
        rectangle.pair,
        <int>[extraCell],
      );
      if (eliminations.isEmpty) {
        continue;
      }

      final TechniqueResult built = TechniqueResult(
        techniqueId: id,
        eliminations: eliminations,
        visual: VisualHint.assemble(
          patternCells: rectangle.floorCells,
          focusDigits: rectangle.pair,
          emphasized: TechniqueSupport.emphasisEntriesOfDigits(
            ctx,
            rectangle.floorCells,
            rectangle.pair,
          ),
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
            'extraCell': Coord.label(extraCell),
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
