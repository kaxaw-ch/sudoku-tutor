/// T-TEC-15（T2）W 翼（W-Wing，rank 130）—— **仅严格共轭对强链**。
///
/// 判定：两个候选完全相同的双值格 A、B（候选 `{x, y}`，且 A 与 B 互不可见），
/// 存在数字 y 的一条**严格共轭对** `S1 = y = S2`（某单元内 y 恰好出现 2 次），
/// 满足 A 看得见 S1、B 看得见 S2（且 A、B 都不是链端点）
/// → 同时看到 A 与 B 的其余格可删去 x。
///
/// 推理链：若 A ≠ x 则 A = y ⇒ S1 ≠ y ⇒ S2 = y ⇒ B ≠ y ⇒ B = x。
/// 故 A、B 之中必有一个为 x，同时看到二者的格都不能是 x。
///
/// **不得上报**的情形（doc 08 风险 1 明确要求，一律静默）：
/// - 强链不是严格共轭对：某单元内 y 出现 **≥ 3 次**（弱链）或 1 次（隐性唯一数），
///   由 [ConjugateGraph] 在建图阶段就不产生边；
/// - **grouped strong link（区块强链）与 ALS 强链一律不认**（本期不实现）；
/// - A、B 候选不完全相同，或任一格候选数 ≠ 2；
/// - A 与 B 互相可见（那是裸对场景，rank 30）；
/// - A 或 B 本身是链端点；
/// - A、B 的公共可见格中无任何 x 候选。
///
/// 保守取舍：删数目标**排除链端点 S1/S2 自身**。
/// 即使 S1/S2 恰好同时可见 A、B（该情形删数在逻辑上也成立），
/// 本实现仍不删——精确率优先于命中率（doc 08 风险 1）。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../narrative/narration_params.dart';
import '../visual/link_mark.dart';
import '../visual/visual_hint.dart';
import 'conjugate_pairs.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// W 翼识别器（严格共轭对强链）。
final class WWingTechnique extends TechniqueBase {
  /// 构造识别器。
  const WWingTechnique();

  @override
  TechniqueId get id => TechniqueId.wWing;

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
    if (bivalues.length < 2) {
      return results;
    }

    // 按候选掩码分桶，只有掩码完全相同的两格才可能构成 W 翼。
    final Map<int, List<int>> byMask = <int, List<int>>{};
    for (final int index in bivalues) {
      (byMask[ctx.candidatesAt(index).mask] ??= <int>[]).add(index);
    }

    final Map<int, ConjugateGraph> graphCache = <int, ConjugateGraph>{};
    ConjugateGraph graphOf(int digit) =>
        graphCache[digit] ??= ConjugateGraph.build(ctx, digit);

    final Set<String> seen = <String>{};

    for (final MapEntry<int, List<int>> entry in byMask.entries) {
      final List<int> cells = entry.value;
      if (cells.length < 2) {
        continue;
      }
      final CandidateSet pair = CandidateSet(entry.key);
      final List<int> pairDigits = pair.digits();

      for (int i = 0; i < cells.length; i++) {
        for (int j = i + 1; j < cells.length; j++) {
          final int a = cells[i];
          final int b = cells[j];
          // A、B 必须互不可见（可见即裸对场景，交给 rank 30）。
          if (ctx.sees(a, b)) {
            continue;
          }
          for (int d = 0; d < 2; d++) {
            final int linkDigit = pairDigits[d];
            final int elimDigit = pairDigits[1 - d];
            for (final ConjugateLink link in graphOf(linkDigit).links) {
              if (link.touches(a) || link.touches(b)) {
                continue;
              }
              // A 连一端、B 连另一端（两种搭配都要试）。
              final List<List<int>> pairings = <List<int>>[
                <int>[link.a, link.b],
                <int>[link.b, link.a],
              ];
              for (final List<int> pairing in pairings) {
                final int s1 = pairing[0];
                final int s2 = pairing[1];
                if (!ctx.sees(a, s1) || !ctx.sees(b, s2)) {
                  continue;
                }
                final List<int> targets = TechniqueSupport.commonPeersWithCandidate(
                  ctx,
                  <int>[a, b],
                  elimDigit,
                );
                final List<Elimination> eliminations =
                    TechniqueSupport.eliminateDigit(
                  ctx,
                  elimDigit,
                  targets,
                  excluded: <int>{a, b, link.a, link.b},
                );
                if (eliminations.isEmpty) {
                  continue;
                }
                final String key = '$a|$b|$linkDigit|${link.a}|${link.b}';
                if (!seen.add(key)) {
                  continue;
                }

                final TechniqueResult built = TechniqueResult(
                  techniqueId: id,
                  eliminations: eliminations,
                  visual: VisualHint.assemble(
                    pincerCells: <int>[a, b],
                    chainStrongCells: <int>[link.a, link.b],
                    focusDigits: pair,
                    emphasized: <MapEntry<int, int>>[
                      ...TechniqueSupport.emphasisEntriesOfDigits(
                        ctx,
                        <int>[a, b],
                        pair,
                      ),
                      ...TechniqueSupport.emphasisEntries(
                        <int>[link.a, link.b],
                        linkDigit,
                      ),
                    ],
                    eliminated: TechniqueSupport.elimEntries(eliminations),
                    links: <LinkMark>[
                      LinkMark(
                        fromCell: link.a,
                        toCell: link.b,
                        digit: linkDigit,
                        strong: true,
                      ),
                      LinkMark(
                        fromCell: a,
                        toCell: s1,
                        digit: linkDigit,
                        strong: false,
                      ),
                      LinkMark(
                        fromCell: b,
                        toCell: s2,
                        digit: linkDigit,
                        strong: false,
                      ),
                    ],
                  ),
                  narration: NarrationParams(
                    techniqueId: id,
                    slots: <String, Object?>{
                      'pairCells': Coord.labelAll(<int>[a, b]),
                      'pairDigits': pairDigits.join('、'),
                      'strongUnit': link.unitLabel,
                      'linkDigit': linkDigit,
                      'strongCells': link.cellsLabel,
                      'digit': elimDigit,
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
        }
      }
    }
    return results;
  }
}
