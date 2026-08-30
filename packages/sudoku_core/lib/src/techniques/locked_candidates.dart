/// T-TEC-07 区块排除（Locked Candidates，rank 50）—— 含指向法与占位法两种情形。
///
/// - **指向（Pointing）**：某宫内数字 d 的候选全部落在同一行/列
///   → 该行/列中宫外的 d 可删。
/// - **占位（Claiming）**：某行/列内数字 d 的候选全部落在同一宫
///   → 该宫中行/列外的 d 可删。
///
/// **不得上报**的情形：
/// - d 在源单元只有 1 个候选位置（那是隐性唯一数，rank 更低）；
/// - 候选位置横跨 ≥ 2 个目标单元（不构成区块）；
/// - 目标单元内无任何可删候选（空结论不上报）。
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

/// 区块排除识别器。
final class LockedCandidatesTechnique extends TechniqueBase {
  /// 构造识别器。
  const LockedCandidatesTechnique();

  @override
  TechniqueId get id => TechniqueId.lockedCandidates;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }

    // ---- 情形一：指向（宫 → 行 / 宫 → 列）----
    for (final Unit box in Units.boxes) {
      for (final int digit in TechniqueSupport.unplacedDigitsIn(ctx, box.cells)) {
        final List<int> positions = TechniqueSupport.positionsOf(ctx, box.cells, digit);
        if (positions.length < 2) {
          continue;
        }
        for (final UnitType lineType in <UnitType>[UnitType.row, UnitType.col]) {
          final List<int> lineIds = TechniqueSupport.unitIdsOfType(lineType, positions);
          if (lineIds.length != 1) {
            continue;
          }
          final Unit line = Units.of(lineType, lineIds.single);
          final List<Elimination> eliminations = TechniqueSupport.eliminateDigit(
            ctx,
            digit,
            line.cells,
            excluded: box.cells.toSet(),
          );
          if (eliminations.isEmpty) {
            continue;
          }
          final TechniqueResult? safe = _build(
            ctx,
            digit: digit,
            sourceUnit: box,
            targetUnit: line,
            positions: positions,
            eliminations: eliminations,
            mode: '指向',
          );
          if (safe == null) {
            continue;
          }
          results.add(safe);
          if (results.length >= limit) {
            return results;
          }
        }
      }
    }

    // ---- 情形二：占位（行 → 宫 / 列 → 宫）----
    for (final Unit line in <Unit>[...Units.rows, ...Units.cols]) {
      for (final int digit in TechniqueSupport.unplacedDigitsIn(ctx, line.cells)) {
        final List<int> positions = TechniqueSupport.positionsOf(ctx, line.cells, digit);
        if (positions.length < 2) {
          continue;
        }
        final List<int> boxIds = TechniqueSupport.unitIdsOfType(UnitType.box, positions);
        if (boxIds.length != 1) {
          continue;
        }
        final Unit box = Units.of(UnitType.box, boxIds.single);
        final List<Elimination> eliminations = TechniqueSupport.eliminateDigit(
          ctx,
          digit,
          box.cells,
          excluded: line.cells.toSet(),
        );
        if (eliminations.isEmpty) {
          continue;
        }
        final TechniqueResult? safe = _build(
          ctx,
          digit: digit,
          sourceUnit: line,
          targetUnit: box,
          positions: positions,
          eliminations: eliminations,
          mode: '占位',
        );
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

  /// 组装一条区块排除结论（含可视化与讲解参数）。
  TechniqueResult? _build(
    SolveContext ctx, {
    required int digit,
    required Unit sourceUnit,
    required Unit targetUnit,
    required List<int> positions,
    required List<Elimination> eliminations,
    required String mode,
  }) {
    final TechniqueResult built = TechniqueResult(
      techniqueId: id,
      eliminations: eliminations,
      visual: VisualHint.assemble(
        patternCells: positions,
        focusDigits: CandidateSet.single(digit),
        emphasized: TechniqueSupport.emphasisEntries(positions, digit),
        eliminated: TechniqueSupport.elimEntries(eliminations),
        regions: <RegionMark>[
          RegionMark(cornerCells: sourceUnit.cells, role: MarkRole.pattern),
          RegionMark(cornerCells: targetUnit.cells, role: MarkRole.cover),
        ],
      ),
      narration: NarrationParams(
        techniqueId: id,
        slots: <String, Object?>{
          'unitLabel': sourceUnit.zhLabel,
          'digit': digit,
          'cellsLabel': Coord.labelAll(positions),
          'mode': mode,
          'targetUnitLabel': targetUnit.zhLabel,
          'elimList': TechniqueSupport.elimListLabel(eliminations),
        },
      ),
    );
    return TechniqueSupport.emit(ctx, built);
  }
}
