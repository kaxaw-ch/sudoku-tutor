/// T-TEC-16 简单涂色（Simple Colouring，rank 160，T2 档）。
///
/// 做法：对某个数字 `d`，把**严格共轭对**（单元内 `d` 恰好出现 2 次）
/// 连成的连通分量做双色染色（色 A / 色 B），二者必有且只有一色为真。
/// 在此基础上只实现两条规则（doc 06 §6.2，本期 scope）：
///
/// - **规则二 · 色链陷阱（Colour Trap）**：某个**链外**格同时看得到
///   一个色 A 格与一个色 B 格 → 无论哪色为真该格都不可能是 `d`，删去它的 `d`。
/// - **规则四 · 同色矛盾（Colour Wrap）**：**同色**的两格落在同一单元里
///   （即互相可见）→ 该色若为真会造成同一单元出现两个 `d`，故该色整体为假，
///   删去该色全部格的 `d`。
///
/// **明确不实现 / 不得上报**（doc 08 风险 1）：
/// - 多重涂色（Multi-Colouring / 3D Medusa）：只在**单个连通分量**内推理，
///   跨分量组合一律不看；
/// - 非严格共轭对连边（区块强链 / ALS 强链）：由 [ConjugateGraph] 在建图阶段拦截；
/// - 节点数 < 2 的分量（无链可染）；
/// - 两色**同时**自相矛盾（盘面本身已崩）时静默跳过，不做任何删除；
/// - 规则二的目标格若属于链本身，一律排除（链上格由规则四负责）。
library;

import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../narrative/narration_params.dart';
import '../visual/link_mark.dart';
import '../visual/visual_hint.dart';
import 'conjugate_pairs.dart';
import 'solve_context.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_result.dart';
import 'technique_support.dart';

/// 简单涂色识别器（只含规则二与规则四）。
final class SimpleColouringTechnique extends TechniqueBase {
  /// 构造识别器。
  const SimpleColouringTechnique();

  /// 规则二的中文标签（讲解占位符 `{ruleLabel}`）。
  static const String ruleTrapLabel = '规则二·色链陷阱';

  /// 规则四的中文标签（讲解占位符 `{ruleLabel}`）。
  static const String ruleWrapLabel = '规则四·同色矛盾';

  @override
  TechniqueId get id => TechniqueId.simpleColouring;

  @override
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1}) {
    final List<TechniqueResult> results = <TechniqueResult>[];
    if (limit <= 0 || !isEnabledIn(ctx)) {
      return results;
    }

    for (int digit = kMinDigit; digit <= kMaxDigit; digit++) {
      final ConjugateGraph graph = ConjugateGraph.build(ctx, digit);
      if (graph.isEmpty) {
        continue;
      }
      for (final Map<int, int> colours in graph.colouredComponents()) {
        final List<int> colourA = _cellsOfColour(colours, 0);
        final List<int> colourB = _cellsOfColour(colours, 1);
        if (colourA.isEmpty || colourB.isEmpty) {
          // 理论上不会发生（分量至少一条边），保险起见跳过。
          continue;
        }
        final List<LinkMark> links = _linksOf(graph, colours);

        // ---- 规则二：色链陷阱 ----
        final TechniqueResult? trap = _tryTrap(
          ctx,
          digit: digit,
          colours: colours,
          colourA: colourA,
          colourB: colourB,
          links: links,
        );
        if (trap != null) {
          results.add(trap);
          if (results.length >= limit) {
            return results;
          }
        }

        // ---- 规则四：同色矛盾 ----
        final TechniqueResult? wrap = _tryWrap(
          ctx,
          digit: digit,
          colourA: colourA,
          colourB: colourB,
          links: links,
        );
        if (wrap != null) {
          results.add(wrap);
          if (results.length >= limit) {
            return results;
          }
        }
      }
    }
    return results;
  }

  /// 规则二：链外格同时看到两色 → 删去该格的 [digit]。
  TechniqueResult? _tryTrap(
    SolveContext ctx, {
    required int digit,
    required Map<int, int> colours,
    required List<int> colourA,
    required List<int> colourB,
    required List<LinkMark> links,
  }) {
    final List<int> targets = <int>[];
    for (final int index in ctx.cellsWithCandidate(digit)) {
      if (colours.containsKey(index)) {
        // 链上格不由规则二处理（避免与规则四口径重叠）。
        continue;
      }
      if (_seesAny(ctx, index, colourA) && _seesAny(ctx, index, colourB)) {
        targets.add(index);
      }
    }
    final List<Elimination> eliminations = TechniqueSupport.eliminateDigit(
      ctx,
      digit,
      targets,
      excluded: colours.keys.toSet(),
    );
    if (eliminations.isEmpty) {
      return null;
    }
    return TechniqueSupport.emit(
      ctx,
      _build(
        ctx,
        digit: digit,
        ruleLabel: ruleTrapLabel,
        colourA: colourA,
        colourB: colourB,
        links: links,
        eliminations: eliminations,
      ),
    );
  }

  /// 规则四：同色两格互相可见 → 该色整体为假，删去该色全部格的 [digit]。
  TechniqueResult? _tryWrap(
    SolveContext ctx, {
    required int digit,
    required List<int> colourA,
    required List<int> colourB,
    required List<LinkMark> links,
  }) {
    final bool conflictA = _hasSelfConflict(ctx, colourA);
    final bool conflictB = _hasSelfConflict(ctx, colourB);
    if (conflictA == conflictB) {
      // 都不冲突 → 规则四不成立；
      // 都冲突 → 盘面本身已自相矛盾，静默跳过（绝不删数）。
      return null;
    }
    final List<int> falseColour = conflictA ? colourA : colourB;
    final List<Elimination> eliminations =
        TechniqueSupport.eliminateDigit(ctx, digit, falseColour);
    if (eliminations.isEmpty) {
      return null;
    }
    return TechniqueSupport.emit(
      ctx,
      _build(
        ctx,
        digit: digit,
        ruleLabel: ruleWrapLabel,
        colourA: colourA,
        colourB: colourB,
        links: links,
        eliminations: eliminations,
      ),
    );
  }

  /// 组装结论（可视化 + 讲解参数）。
  TechniqueResult _build(
    SolveContext ctx, {
    required int digit,
    required String ruleLabel,
    required List<int> colourA,
    required List<int> colourB,
    required List<LinkMark> links,
    required List<Elimination> eliminations,
  }) {
    final CandidateSet focus = CandidateSet.single(digit);
    return TechniqueResult(
      techniqueId: id,
      eliminations: eliminations,
      visual: VisualHint.assemble(
        // 双色分别复用强链/弱链两种角色标记（颜色 + 形状双通道）。
        chainStrongCells: colourA,
        chainWeakCells: colourB,
        focusDigits: focus,
        emphasized: <MapEntry<int, int>>[
          ...TechniqueSupport.emphasisEntries(colourA, digit),
          ...TechniqueSupport.emphasisEntries(colourB, digit),
        ],
        eliminated: TechniqueSupport.elimEntries(eliminations),
        links: links,
      ),
      narration: NarrationParams(
        techniqueId: id,
        slots: <String, Object?>{
          'digit': digit,
          'ruleLabel': ruleLabel,
          'colourCells': '色A ${Coord.labelAll(colourA)}／'
              '色B ${Coord.labelAll(colourB)}',
          'elimList': TechniqueSupport.elimListLabel(eliminations),
        },
      ),
    );
  }

  /// 取染色映射中颜色为 [colour] 的格（升序）。
  static List<int> _cellsOfColour(Map<int, int> colours, int colour) {
    final List<int> list = <int>[
      for (final MapEntry<int, int> entry in colours.entries)
        if (entry.value == colour) entry.key,
    ]..sort();
    return list;
  }

  /// [index] 是否能看到 [cells] 中任意一格。
  static bool _seesAny(SolveContext ctx, int index, List<int> cells) {
    for (final int cell in cells) {
      if (ctx.sees(index, cell)) {
        return true;
      }
    }
    return false;
  }

  /// 同色格之间是否存在「互相可见」（即同一单元出现两次同色）。
  static bool _hasSelfConflict(SolveContext ctx, List<int> cells) {
    for (int i = 0; i < cells.length; i++) {
      for (int j = i + 1; j < cells.length; j++) {
        if (ctx.sees(cells[i], cells[j])) {
          return true;
        }
      }
    }
    return false;
  }

  /// 分量内的强链连线（只画属于本分量的边）。
  static List<LinkMark> _linksOf(ConjugateGraph graph, Map<int, int> colours) =>
      <LinkMark>[
        for (final ConjugateLink link in graph.links)
          if (colours.containsKey(link.a) && colours.containsKey(link.b))
            LinkMark(
              fromCell: link.a,
              toCell: link.b,
              digit: link.digit,
              strong: true,
            ),
      ];
}
