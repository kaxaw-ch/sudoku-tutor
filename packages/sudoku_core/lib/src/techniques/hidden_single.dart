/// T-TEC-02 隐性唯一数（Hidden Single，rank 20）。
///
/// 判定：某个单元（行/列/宫）内，数字 d 的候选只落在唯一一个空格 → 该格填 d。
///
/// **不得上报**的情形：
/// - 数字 d 已在该单元落子；
/// - d 在该单元有 ≥ 2 个候选位置；
/// - d 在该单元无任何候选位置（盘面矛盾，静默交由 `Validator`）。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../model/unit.dart';
import '../narrative/narration_params.dart';
import '../visual/mark_role.dart';
import '../visual/region_mark.dart';
import '../visual/visual_hint.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// 隐性唯一数识别器。
final class HiddenSingleTechnique extends TechniqueBase {
  /// 构造识别器。
  const HiddenSingleTechnique();

  @override
  TechniqueId get id => TechniqueId.hiddenSingle;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    final Set<String> seen = <String>{};

    for (final Unit unit in Units.all) {
      for (final int digit in TechniqueSupport.unplacedDigitsIn(ctx, unit.cells)) {
        final List<int> positions =
            TechniqueSupport.positionsOf(ctx, unit.cells, digit);
        if (positions.length != 1) {
          continue;
        }
        final int index = positions.single;
        // 同一个 (格, 数字) 可能被行/列/宫三次命中，去重后只上报一次。
        if (!seen.add('$index:$digit')) {
          continue;
        }
        final TechniqueResult built = TechniqueResult(
          techniqueId: id,
          placements: <Placement>[Placement(index, digit)],
          visual: VisualHint.assemble(
            placed: <MapEntry<int, int>>[MapEntry<int, int>(index, digit)],
            focusDigits: CandidateSet.single(digit),
            regions: <RegionMark>[
              RegionMark(cornerCells: unit.cells, role: MarkRole.pattern),
            ],
          ),
          narration: NarrationParams(
            techniqueId: id,
            slots: <String, Object?>{
              'unitLabel': unit.zhLabel,
              'digit': digit,
              'cellLabel': Coord.label(index),
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
    }
    return results;
  }
}
