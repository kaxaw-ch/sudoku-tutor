/// T-TEC-01 唯一余数（Naked Single，rank 10）。
///
/// 判定：某个空格的候选集只剩 1 个数字 → 该格只能填这个数字。
///
/// **不得上报**的情形：
/// - 候选数 ≥ 2 的格（那不是唯一余数）；
/// - 候选数为 0 的死格（盘面已矛盾，交由 `Validator` 处理，本技巧静默）。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../narrative/narration_params.dart';
import '../visual/visual_hint.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// 唯一余数识别器。
final class NakedSingleTechnique extends TechniqueBase {
  /// 构造识别器。
  const NakedSingleTechnique();

  @override
  TechniqueId get id => TechniqueId.nakedSingle;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    for (final int index in ctx.blankCells()) {
      final CandidateSet candidates = ctx.candidatesAt(index);
      if (candidates.count() != 1) {
        continue;
      }
      final int digit = candidates.lowest;
      final Placement placement = Placement(index, digit);
      final TechniqueResult built = TechniqueResult(
        techniqueId: id,
        placements: <Placement>[placement],
        visual: VisualHint.assemble(
          placed: <MapEntry<int, int>>[MapEntry<int, int>(index, digit)],
          focusDigits: candidates,
        ),
        narration: NarrationParams(
          techniqueId: id,
          slots: <String, Object?>{
            'cellLabel': Coord.label(index),
            'digit': digit,
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
