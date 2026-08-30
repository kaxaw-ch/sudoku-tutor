/// T-TEC-03 裸对（rank 30）/ T-TEC-05 裸三（rank 60）—— 同一算法按 `size` 参数化。
///
/// 判定：某单元内 `size` 个空格，其候选并集恰好为 `size` 个数字
/// → 这 `size` 个数字被这 `size` 个格锁定，单元内其余格可删去这些数字。
///
/// **不得上报**的情形：
/// - 候选并集大小 ≠ `size`；
/// - 组合中含候选数 < 2 的格（那是唯一余数，rank 更低，避免重复上报）；
/// - 单元内其余格无任何可删候选（空结论不上报）。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../model/unit.dart';
import '../narrative/narration_params.dart';
import '../util/bit_ops.dart';
import '../util/core_error.dart';
import '../visual/mark_role.dart';
import '../visual/region_mark.dart';
import '../visual/visual_hint.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// 裸子集识别器（`size == 2` → 裸对，`size == 3` → 裸三）。
final class NakedSubsetTechnique extends TechniqueBase {
  /// 构造识别器；[size] 仅支持 2 或 3（本期 scope 不含裸四）。
  const NakedSubsetTechnique({required this.size});

  /// 子集大小。
  final int size;

  @override
  TechniqueId get id => switch (size) {
        2 => TechniqueId.nakedPair,
        3 => TechniqueId.nakedTriple,
        _ => throw CoreException(
            CoreErrorCode.techNotRegistered,
            '裸子集仅支持 size=2/3，收到 $size',
          ),
      };

  /// 讲解模板中承载数字组的槽位名。
  String get _digitsSlot => size == 2 ? 'pairDigits' : 'tripleDigits';

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    final TechniqueId techniqueId = id;
    final Set<String> seen = <String>{};

    for (final Unit unit in Units.all) {
      // 只取候选数在 2..size 之间的空格作为候选成员。
      final List<int> members = <int>[
        for (final int index in unit.cells)
          if (ctx.board.isBlank(index))
            if (ctx.candidatesAt(index).count() >= 2 &&
                ctx.candidatesAt(index).count() <= size)
              index,
      ];
      if (members.length < size) {
        continue;
      }

      for (final List<int> combo in BitOps.combinations<int>(members, size)) {
        CandidateSet union = CandidateSet.none;
        for (final int index in combo) {
          union = union.union(ctx.candidatesAt(index));
        }
        // 裸子集铁律：并集必须恰好等于子集大小。
        if (union.count() != size) {
          continue;
        }
        final List<Elimination> eliminations = TechniqueSupport.eliminateDigits(
          ctx,
          union,
          unit.cells,
          excluded: combo.toSet(),
        );
        if (eliminations.isEmpty) {
          continue;
        }
        final String key =
            '${unit.type.id}#${unit.id}|${combo.join(',')}|${union.mask}';
        if (!seen.add(key)) {
          continue;
        }

        final TechniqueResult built = TechniqueResult(
          techniqueId: techniqueId,
          eliminations: eliminations,
          visual: VisualHint.assemble(
            patternCells: combo,
            focusDigits: union,
            emphasized:
                TechniqueSupport.emphasisEntriesOfDigits(ctx, combo, union),
            eliminated: TechniqueSupport.elimEntries(eliminations),
            regions: <RegionMark>[
              RegionMark(cornerCells: unit.cells, role: MarkRole.cover),
            ],
          ),
          narration: NarrationParams(
            techniqueId: techniqueId,
            slots: <String, Object?>{
              'unitLabel': unit.zhLabel,
              'cellsLabel': Coord.labelAll(combo),
              _digitsSlot: union.digits().join('、'),
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
    }
    return results;
  }
}
