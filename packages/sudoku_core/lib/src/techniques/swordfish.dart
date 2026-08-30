/// T-TEC-09 剑鱼（Swordfish，rank 100）—— **仅标准 N=3**。
///
/// 判定（行基，列基对称）：数字 d 在三行中各有 2~3 个候选位置，
/// 且三行的候选列号并集恰好为 3 列
/// → d 在这 3 列的其余格可删。
///
/// **不得上报**的情形（doc 08 风险 1 明确要求）：
/// - **退化为 X 翼的形态不得以剑鱼上报**：若三条基线中存在某 2 条，
///   其列号并集只有 2 列，则该模式实质是 X 翼（rank 80），本技巧静默；
/// - 任一基线候选位置数 < 2（隐性唯一数）或 > 3（超出 N=3）；
/// - 列号并集 ≠ 3；
/// - 覆盖列中无任何可删候选。
///
/// **明确不实现**：Finned/Sashimi Swordfish、Jellyfish 及更高阶 Fish。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../narrative/narration_params.dart';
import '../util/bit_ops.dart';
import '../visual/mark_role.dart';
import '../visual/region_mark.dart';
import '../visual/visual_hint.dart';
import 'fish_support.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// 剑鱼识别器（标准 N=3）。
final class SwordfishTechnique extends TechniqueBase {
  /// 剑鱼的阶数（固定 3）。
  static const int fishSize = 3;

  /// 构造识别器。
  const SwordfishTechnique();

  @override
  TechniqueId get id => TechniqueId.swordfish;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    for (final FishOrientation orientation in FishOrientation.values) {
      for (int digit = 1; digit <= kBoardSize; digit++) {
        _scan(ctx, orientation, digit, limit, results);
        if (results.length >= limit) {
          return results;
        }
      }
    }
    return results;
  }

  void _scan(
    SolveContext ctx,
    FishOrientation orientation,
    int digit,
    int limit,
    List<TechniqueResult> results,
  ) {
    final List<int> usableLines = <int>[];
    final Map<int, List<int>> byLine = <int, List<int>>{};
    for (int line = 0; line < kBoardSize; line++) {
      final List<int> positions =
          FishSupport.crossPositions(ctx, orientation, line, digit);
      if (positions.length >= 2 && positions.length <= fishSize) {
        usableLines.add(line);
        byLine[line] = positions;
      }
    }
    if (usableLines.length < fishSize) {
      return;
    }

    for (final List<int> lines in BitOps.combinations<int>(usableLines, fishSize)) {
      final Set<int> crossUnion = <int>{};
      for (final int line in lines) {
        crossUnion.addAll(byLine[line]!);
      }
      if (crossUnion.length != fishSize) {
        continue;
      }
      // ⚠️ 退化检测：任意 2 条基线的列并集若只有 2 列，说明这是 X 翼而非剑鱼。
      if (_degeneratesToXWing(lines, byLine)) {
        continue;
      }

      final List<int> crosses = crossUnion.toList()..sort();
      final Set<int> baseLines = lines.toSet();
      final List<int> targets = <int>[
        for (final int cross in crosses)
          ...FishSupport.coverTargets(ctx, orientation, cross, digit, baseLines),
      ];
      final List<Elimination> eliminations =
          TechniqueSupport.eliminateDigit(ctx, digit, targets);
      if (eliminations.isEmpty) {
        continue;
      }

      final List<int> patternCells = <int>[
        for (final int line in lines)
          for (final int cross in byLine[line]!)
            FishSupport.cellAt(orientation, line, cross),
      ]..sort();

      final TechniqueResult built = TechniqueResult(
        techniqueId: id,
        eliminations: eliminations,
        visual: VisualHint.assemble(
          patternCells: patternCells,
          focusDigits: CandidateSet.single(digit),
          emphasized: TechniqueSupport.emphasisEntries(patternCells, digit),
          eliminated: TechniqueSupport.elimEntries(eliminations),
          regions: <RegionMark>[
            RegionMark(
              cornerCells: TechniqueSupport.boundingCorners(patternCells),
              role: MarkRole.pattern,
            ),
          ],
        ),
        narration: NarrationParams(
          techniqueId: id,
          slots: <String, Object?>{
            'baseUnits': FishSupport.baseUnitsLabel(orientation, lines),
            'digit': digit,
            'coverUnits': FishSupport.coverUnitsLabel(orientation, crosses),
            'coverType': FishSupport.coverTypeLabel(orientation),
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
        return;
      }
    }
  }

  /// 三条基线中是否存在 2 条，其覆盖线并集只有 2 条（即退化为 X 翼）。
  static bool _degeneratesToXWing(List<int> lines, Map<int, List<int>> byLine) {
    for (int i = 0; i < lines.length; i++) {
      for (int j = i + 1; j < lines.length; j++) {
        final Set<int> pairUnion = <int>{...byLine[lines[i]]!, ...byLine[lines[j]]!};
        if (pairUnion.length <= 2) {
          return true;
        }
      }
    }
    return false;
  }
}
