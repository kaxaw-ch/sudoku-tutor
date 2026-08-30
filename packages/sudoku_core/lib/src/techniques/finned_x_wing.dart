/// T-TEC-14（T2）鳍形 X 翼（Finned X-Wing，含 Sashimi，rank 90）。
///
/// 判定（行基，列基对称）：
/// - 「干净基线」上数字 d 恰有 2 个候选位置 `{c1, c2}`；
/// - 「带鳍基线」上 d 的候选位置 = `{c1, c2}` 的**非空子集** + **恰好 1 个**鳍格；
/// - 鳍格必须与两个覆盖角之一**同宫**；
/// - 删数 = 该覆盖列上、与鳍**同宫**、且不在两条基线上的格。
///
/// Sashimi：带鳍基线缺失鳍宫侧的那个角时仍成立，删数规则不变。
///
/// **不得上报**的情形（doc 08 风险 1 明确要求，一律静默、不抛异常）：
/// - **鳍格数 ≠ 1**：0 个是普通 X 翼（rank 80），≥ 2 个是多鳍形态，本期不实现；
/// - **鳍格与任一覆盖角不同宫**（跨宫鳍）；
/// - 鳍格同时与两个覆盖角同宫（宫内歧义，无法确定删数区）；
/// - 带鳍基线未覆盖「非鳍宫」侧的那个角（骨架不成立）；
/// - 干净基线候选位置数 ≠ 2；
/// - 删数区无任何可删候选。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../model/unit.dart';
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

/// 鳍形 X 翼识别器（含 Sashimi）。
final class FinnedXWingTechnique extends TechniqueBase {
  /// 构造识别器。
  const FinnedXWingTechnique();

  @override
  TechniqueId get id => TechniqueId.finnedXWing;

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
    final List<List<int>> byLine = <List<int>>[
      for (int line = 0; line < kBoardSize; line++)
        FishSupport.crossPositions(ctx, orientation, line, digit),
    ];

    for (int cleanLine = 0; cleanLine < kBoardSize; cleanLine++) {
      if (byLine[cleanLine].length != 2) {
        continue;
      }
      final int c1 = byLine[cleanLine][0];
      final int c2 = byLine[cleanLine][1];

      for (int finLine = 0; finLine < kBoardSize; finLine++) {
        if (finLine == cleanLine) {
          continue;
        }
        final List<int> posFin = byLine[finLine];
        if (posFin.isEmpty) {
          continue;
        }
        final List<int> core = <int>[
          for (final int cross in posFin)
            if (cross == c1 || cross == c2) cross,
        ];
        final List<int> extras = <int>[
          for (final int cross in posFin)
            if (cross != c1 && cross != c2) cross,
        ];
        // 铁律 1：鳍格恰好 1 个（0 → 普通 X 翼；≥2 → 多鳍，本期不实现）。
        if (extras.length != 1) {
          continue;
        }
        if (core.isEmpty) {
          continue;
        }

        final int finCross = extras.single;
        final int finCell = FishSupport.cellAt(orientation, finLine, finCross);
        final int finBox = Coord.boxOf(finCell);

        // 铁律 2：鳍格必须与**恰好一个**覆盖角同宫（0 → 跨宫；2 → 歧义）。
        final List<int> sameBoxCrosses = <int>[
          for (final int cross in <int>[c1, c2])
            if (Coord.boxOf(FishSupport.cellAt(orientation, finLine, cross)) == finBox)
              cross,
        ];
        if (sameBoxCrosses.length != 1) {
          continue;
        }
        final int coverCross = sameBoxCrosses.single;
        final int otherCross = coverCross == c1 ? c2 : c1;

        // 铁律 3：带鳍基线必须覆盖「非鳍宫」侧的角，否则骨架不成立。
        if (!core.contains(otherCross)) {
          continue;
        }

        // 删数区：覆盖线 coverCross 上、与鳍同宫、且不在两条基线上的格。
        final List<int> targets = <int>[];
        for (int line = 0; line < kBoardSize; line++) {
          if (line == cleanLine || line == finLine) {
            continue;
          }
          final int cell = FishSupport.cellAt(orientation, line, coverCross);
          if (Coord.boxOf(cell) != finBox) {
            continue;
          }
          targets.add(cell);
        }
        final List<Elimination> eliminations =
            TechniqueSupport.eliminateDigit(ctx, digit, targets);
        if (eliminations.isEmpty) {
          continue;
        }

        final List<int> patternCells = <int>[
          FishSupport.cellAt(orientation, cleanLine, c1),
          FishSupport.cellAt(orientation, cleanLine, c2),
          for (final int cross in core) FishSupport.cellAt(orientation, finLine, cross),
        ]..sort();
        final int oppositeCorner =
            FishSupport.cellAt(orientation, cleanLine, coverCross);
        final Unit coverUnit =
            Units.of(FishSupport.coverType(orientation), coverCross);

        final TechniqueResult built = TechniqueResult(
          techniqueId: id,
          eliminations: eliminations,
          visual: VisualHint.assemble(
            patternCells: patternCells,
            finCells: <int>[finCell],
            focusDigits: CandidateSet.single(digit),
            emphasized: TechniqueSupport.emphasisEntries(
              <int>[...patternCells, finCell],
              digit,
            ),
            eliminated: TechniqueSupport.elimEntries(eliminations),
            regions: <RegionMark>[
              RegionMark(
                cornerCells: TechniqueSupport.boundingCorners(patternCells),
                role: MarkRole.pattern,
              ),
              RegionMark(cornerCells: coverUnit.cells, role: MarkRole.cover),
            ],
          ),
          narration: NarrationParams(
            techniqueId: id,
            slots: <String, Object?>{
              'baseUnits':
                  FishSupport.baseUnitsLabel(orientation, <int>[cleanLine, finLine]),
              'digit': digit,
              'finUnit': FishSupport.baseUnitsLabel(orientation, <int>[finLine]),
              'finCell': Coord.label(finCell),
              'oppositeCorner': Coord.label(oppositeCorner),
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
