/// T-TEC-10 XY 翼（XY-Wing，rank 110）。
///
/// 判定：枢轴格候选恰为 `{x, y}`，两个夹翼格候选分别恰为 `{x, z}` 与 `{y, z}`，
/// 且两个夹翼格都能看到枢轴格（`x != y != z`）
/// → 同时看到两个夹翼格的其余格可删去 z。
///
/// **不得上报**的情形：
/// - 枢轴或夹翼格候选数 ≠ 2；
/// - 夹翼格看不到枢轴格；
/// - 三个数字不满足 `{x,y} / {x,z} / {y,z}` 的三元环结构（并集必须恰好 3 个数字）；
/// - 两夹翼格的公共可见格中无任何 z 候选（空结论不上报）。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../narrative/narration_params.dart';
import '../visual/link_mark.dart';
import '../visual/visual_hint.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// XY 翼识别器。
final class XyWingTechnique extends TechniqueBase {
  /// 构造识别器。
  const XyWingTechnique();

  @override
  TechniqueId get id => TechniqueId.xyWing;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    final List<int> bivalues = <int>[
      for (final int index in ctx.blankCells())
        if (ctx.candidatesAt(index).count() == 2) index,
    ];
    if (bivalues.length < 3) {
      return results;
    }
    final Set<String> seen = <String>{};

    for (final int pivot in bivalues) {
      final CandidateSet pivotSet = ctx.candidatesAt(pivot);
      final List<int> pivotDigits = pivotSet.digits();
      final int x = pivotDigits[0];
      final int y = pivotDigits[1];

      // 枢轴可见的双值格。
      final List<int> wings = <int>[
        for (final int index in bivalues)
          if (index != pivot && ctx.sees(index, pivot)) index,
      ];

      for (int i = 0; i < wings.length; i++) {
        for (int j = i + 1; j < wings.length; j++) {
          final int p1 = wings[i];
          final int p2 = wings[j];
          final CandidateSet s1 = ctx.candidatesAt(p1);
          final CandidateSet s2 = ctx.candidatesAt(p2);

          // 三元环结构：并集恰好 3 个数字，且两夹翼各含枢轴的一个数字。
          final CandidateSet union = pivotSet.union(s1).union(s2);
          if (union.count() != 3) {
            continue;
          }
          final CandidateSet zSet = union.difference(pivotSet);
          if (zSet.count() != 1) {
            continue;
          }
          final int z = zSet.lowest;
          if (!s1.contains(z) || !s2.contains(z)) {
            continue;
          }
          // p1 带 x、p2 带 y（或反之），且不得两者带同一个枢轴数字。
          final bool okDirect = s1.contains(x) && s2.contains(y) && !s1.contains(y) && !s2.contains(x);
          final bool okSwapped = s1.contains(y) && s2.contains(x) && !s1.contains(x) && !s2.contains(y);
          if (!okDirect && !okSwapped) {
            continue;
          }

          final List<int> targets =
              TechniqueSupport.commonPeersWithCandidate(ctx, <int>[p1, p2], z);
          final List<Elimination> eliminations = TechniqueSupport.eliminateDigit(
            ctx,
            z,
            targets,
            excluded: <int>{pivot, p1, p2},
          );
          if (eliminations.isEmpty) {
            continue;
          }
          final String key = '$pivot|${p1 < p2 ? p1 : p2}|${p1 < p2 ? p2 : p1}|$z';
          if (!seen.add(key)) {
            continue;
          }

          final TechniqueResult built = TechniqueResult(
            techniqueId: id,
            eliminations: eliminations,
            visual: VisualHint.assemble(
              pivotCells: <int>[pivot],
              pincerCells: <int>[p1, p2],
              focusDigits: union,
              emphasized: TechniqueSupport.emphasisEntriesOfDigits(
                ctx,
                <int>[pivot, p1, p2],
                union,
              ),
              eliminated: TechniqueSupport.elimEntries(eliminations),
              links: <LinkMark>[
                LinkMark(
                  fromCell: pivot,
                  toCell: p1,
                  digit: s1.intersect(pivotSet).lowest,
                  strong: false,
                ),
                LinkMark(
                  fromCell: pivot,
                  toCell: p2,
                  digit: s2.intersect(pivotSet).lowest,
                  strong: false,
                ),
              ],
            ),
            narration: NarrationParams(
              techniqueId: id,
              slots: <String, Object?>{
                'pivotCell': Coord.label(pivot),
                'pivotDigits': pivotDigits.join('、'),
                'pincerCells': Coord.labelAll(<int>[p1, p2]),
                'digit': z,
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
    }
    return results;
  }
}
