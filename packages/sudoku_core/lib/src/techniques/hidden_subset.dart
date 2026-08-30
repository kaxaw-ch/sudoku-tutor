/// T-TEC-04 隐对（rank 40）/ T-TEC-06 隐三（rank 70）—— 同一算法按 `size` 参数化。
///
/// 判定：某单元内 `size` 个数字的候选位置并集恰好为 `size` 个空格
/// → 这 `size` 个格必然由这 `size` 个数字占满，格内其余候选可删。
///
/// **不得上报**的情形：
/// - 数字已在该单元落子；
/// - 任一数字在该单元只有 1 个候选位置（那是隐性唯一数，rank 更低）；
/// - 位置并集大小 ≠ `size`；
/// - 这 `size` 个格没有任何多余候选（空结论不上报）。
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

/// 隐性子集识别器（`size == 2` → 隐对，`size == 3` → 隐三）。
final class HiddenSubsetTechnique extends TechniqueBase {
  /// 构造识别器；[size] 仅支持 2 或 3（本期 scope 不含隐四）。
  const HiddenSubsetTechnique({required this.size});

  /// 子集大小。
  final int size;

  @override
  TechniqueId get id => switch (size) {
        2 => TechniqueId.hiddenPair,
        3 => TechniqueId.hiddenTriple,
        _ => throw CoreException(
            CoreErrorCode.techNotRegistered,
            '隐性子集仅支持 size=2/3，收到 $size',
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
      // 候选数字：单元内未落子、且候选位置数在 2..size 之间。
      final Map<int, List<int>> positionsByDigit = <int, List<int>>{};
      for (final int digit in TechniqueSupport.unplacedDigitsIn(ctx, unit.cells)) {
        final List<int> positions =
            TechniqueSupport.positionsOf(ctx, unit.cells, digit);
        if (positions.length >= 2 && positions.length <= size) {
          positionsByDigit[digit] = positions;
        }
      }
      final List<int> digits = positionsByDigit.keys.toList()..sort();
      if (digits.length < size) {
        continue;
      }

      for (final List<int> combo in BitOps.combinations<int>(digits, size)) {
        final Set<int> cellUnion = <int>{};
        for (final int digit in combo) {
          cellUnion.addAll(positionsByDigit[digit]!);
        }
        // 隐性子集铁律：位置并集必须恰好等于子集大小。
        if (cellUnion.length != size) {
          continue;
        }
        final List<int> subsetCells = cellUnion.toList()..sort();
        final CandidateSet keep = CandidateSet.fromDigits(combo);
        final List<Elimination> eliminations =
            TechniqueSupport.retainOnly(ctx, keep, subsetCells);
        if (eliminations.isEmpty) {
          continue;
        }
        final String key =
            '${unit.type.id}#${unit.id}|${subsetCells.join(',')}|${keep.mask}';
        if (!seen.add(key)) {
          continue;
        }

        final TechniqueResult built = TechniqueResult(
          techniqueId: techniqueId,
          eliminations: eliminations,
          visual: VisualHint.assemble(
            patternCells: subsetCells,
            focusDigits: keep,
            emphasized: TechniqueSupport.emphasisEntriesOfDigits(
              ctx,
              subsetCells,
              keep,
            ),
            eliminated: TechniqueSupport.elimEntries(eliminations),
            regions: <RegionMark>[
              RegionMark(cornerCells: unit.cells, role: MarkRole.cover),
            ],
          ),
          narration: NarrationParams(
            techniqueId: techniqueId,
            slots: <String, Object?>{
              'unitLabel': unit.zhLabel,
              _digitsSlot: combo.join('、'),
              'cellsLabel': Coord.labelAll(subsetCells),
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
