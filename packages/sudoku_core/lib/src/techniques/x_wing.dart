/// T-TEC-08 X 翼（X-Wing，rank 80）。
///
/// 判定（行基，列基对称）：数字 d 在两行中各**恰好 2 个**候选位置，
/// 且这两行的候选列号完全相同 `{c1, c2}`
/// → d 在 c1、c2 两列的其余格可删。
///
/// **不得上报**的情形：
/// - 任一基行的候选位置数 ≠ 2（3 个及以上属剑鱼/鳍形范畴，1 个是隐性唯一数）；
/// - 两行的列号集合不完全相同；
/// - 覆盖列中无任何可删候选（空结论不上报）。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../narrative/narration_params.dart';
import '../visual/mark_role.dart';
import '../visual/region_mark.dart';
import '../visual/visual_hint.dart';
import 'fish_support.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// X 翼识别器。
final class XWingTechnique extends TechniqueBase {
  /// 构造识别器。
  const XWingTechnique();

  @override
  TechniqueId get id => TechniqueId.xWing;

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
    // 预扫描：每条基线上 d 的候选位置。
    final List<List<int>> byLine = <List<int>>[
      for (int line = 0; line < kBoardSize; line++)
        FishSupport.crossPositions(ctx, orientation, line, digit),
    ];

    for (int l1 = 0; l1 < kBoardSize - 1; l1++) {
      if (byLine[l1].length != 2) {
        continue;
      }
      for (int l2 = l1 + 1; l2 < kBoardSize; l2++) {
        if (byLine[l2].length != 2) {
          continue;
        }
        if (byLine[l1][0] != byLine[l2][0] || byLine[l1][1] != byLine[l2][1]) {
          continue;
        }
        final List<int> crosses = byLine[l1];
        final Set<int> baseLines = <int>{l1, l2};
        final List<int> targets = <int>[
          for (final int cross in crosses)
            ...FishSupport.coverTargets(ctx, orientation, cross, digit, baseLines),
        ];
        final List<Elimination> eliminations =
            TechniqueSupport.eliminateDigit(ctx, digit, targets);
        if (eliminations.isEmpty) {
          continue;
        }

        final List<int> corners = <int>[
          for (final int line in <int>[l1, l2])
            for (final int cross in crosses)
              FishSupport.cellAt(orientation, line, cross),
        ]..sort();

        final TechniqueResult built = TechniqueResult(
          techniqueId: id,
          eliminations: eliminations,
          visual: VisualHint.assemble(
            patternCells: corners,
            focusDigits: CandidateSet.single(digit),
            emphasized: TechniqueSupport.emphasisEntries(corners, digit),
            eliminated: TechniqueSupport.elimEntries(eliminations),
            regions: <RegionMark>[
              RegionMark(cornerCells: corners, role: MarkRole.pattern),
            ],
          ),
          narration: NarrationParams(
            techniqueId: id,
            slots: <String, Object?>{
              'baseUnits': FishSupport.baseUnitsLabel(orientation, <int>[l1, l2]),
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
  }
}
