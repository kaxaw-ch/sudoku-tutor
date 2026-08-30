/// T-TEC-11 XYZ 翼（XYZ-Wing，rank 120）。
///
/// 判定：枢轴格候选恰为 `{x, y, z}`（三值），两个夹翼格候选分别恰为
/// `{x, z}` 与 `{y, z}`（双值），且都能看到枢轴格
/// → **同时看到枢轴与两个夹翼**的其余格可删去 z。
///
/// 与 XY 翼的关键差异：枢轴本身也含 z，因此删数格必须同时看到**三格**
/// （而不是只看到两个夹翼），这是最容易写错、也最容易误删的一点。
///
/// **不得上报**的情形：
/// - 枢轴候选数 ≠ 3 或夹翼候选数 ≠ 2；
/// - 夹翼看不到枢轴；
/// - 两夹翼候选并集 ≠ 枢轴候选（三数字未闭合）；
/// - 两夹翼的公共数字 ≠ 1 个（z 不唯一）；
/// - 三格公共可见格中无任何 z 候选（空结论不上报）。
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

/// XYZ 翼识别器。
final class XyzWingTechnique extends TechniqueBase {
  /// 构造识别器。
  const XyzWingTechnique();

  @override
  TechniqueId get id => TechniqueId.xyzWing;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }
    final List<int> blanks = ctx.blankCells();
    final List<int> bivalues = <int>[
      for (final int index in blanks)
        if (ctx.candidatesAt(index).count() == 2) index,
    ];
    if (bivalues.length < 2) {
      return results;
    }
    final Set<String> seen = <String>{};

    for (final int pivot in blanks) {
      final CandidateSet pivotSet = ctx.candidatesAt(pivot);
      if (pivotSet.count() != 3) {
        continue;
      }
      final List<int> wings = <int>[
        for (final int index in bivalues)
          if (index != pivot && ctx.sees(index, pivot))
            if (pivotSet.containsAll(ctx.candidatesAt(index))) index,
      ];
      if (wings.length < 2) {
        continue;
      }

      for (int i = 0; i < wings.length; i++) {
        for (int j = i + 1; j < wings.length; j++) {
          final int p1 = wings[i];
          final int p2 = wings[j];
          final CandidateSet s1 = ctx.candidatesAt(p1);
          final CandidateSet s2 = ctx.candidatesAt(p2);
          // 两夹翼并集必须等于枢轴的三个数字。
          if (s1.union(s2).mask != pivotSet.mask) {
            continue;
          }
          final CandidateSet shared = s1.intersect(s2);
          if (shared.count() != 1) {
            continue;
          }
          final int z = shared.lowest;

          // XYZ 翼铁律：删数格必须同时看到「枢轴 + 两个夹翼」三格。
          final List<int> targets = TechniqueSupport.commonPeersWithCandidate(
            ctx,
            <int>[pivot, p1, p2],
            z,
          );
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
              focusDigits: pivotSet,
              emphasized: TechniqueSupport.emphasisEntriesOfDigits(
                ctx,
                <int>[pivot, p1, p2],
                pivotSet,
              ),
              eliminated: TechniqueSupport.elimEntries(eliminations),
              links: <LinkMark>[
                LinkMark(fromCell: pivot, toCell: p1, digit: z, strong: false),
                LinkMark(fromCell: pivot, toCell: p2, digit: z, strong: false),
              ],
            ),
            narration: NarrationParams(
              techniqueId: id,
              slots: <String, Object?>{
                'pivotCell': Coord.label(pivot),
                'pivotDigits': pivotSet.digits().join('、'),
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
