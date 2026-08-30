/// 16 项识别器的公共支撑函数（doc 06 §6.1 / §7.1，批次 C）。
///
/// 存在意义：把「单元内取空格 / 取候选位置 / 组装删数 / 安全出口」这四件
/// 每个识别器都要做的事收敛到一处，避免 16 份重复实现导致口径漂移。
///
/// **安全出口 [TechniqueSupport.emit] 是本文件最重要的一条**：
/// 任何结论在离开识别器之前都要过一遍 `SanityGuard`，
/// 一旦发现「删掉的候选正是终局解」就**降级为本步无提示**（返回 `null`），
/// 绝不把有毒结论交给上层（doc 08 风险 1 / P0-QA-03）。
library;

import '../engine/sanity_guard.dart';
import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../model/peers.dart';
import '../model/unit.dart';
import '../narrative/narration_template.dart';
import 'solve_context.dart';
import 'technique_result.dart';

/// 识别器公共支撑（全部为静态纯函数）。
abstract final class TechniqueSupport {
  /// **安全出口**：结论非空且通过 `SanityGuard` 才放行，否则返回 `null`。
  ///
  /// 返回 `null` 的语义 = 「本步无提示」，调用方直接跳过，不得再做任何删除。
  static TechniqueResult? emit(SolveContext ctx, TechniqueResult result) {
    if (result.isEmpty) {
      return null;
    }
    if (!SanityGuard.isResultSafe(ctx.solution, result)) {
      // 命中 E_TECH_001 的语义场景：静默降级，绝不执行删除。
      return null;
    }
    return result;
  }

  /// [cells] 中的空格索引（升序，保持入参顺序）。
  static List<int> blanksIn(SolveContext ctx, List<int> cells) => <int>[
        for (final int index in cells)
          if (ctx.board.isBlank(index)) index,
      ];

  /// [cells] 中候选含 [digit] 的空格索引（保持入参顺序）。
  static List<int> positionsOf(SolveContext ctx, List<int> cells, int digit) => <int>[
        for (final int index in cells)
          if (ctx.board.isBlank(index) && ctx.candidatesAt(index).contains(digit)) index,
      ];

  /// [digit] 是否已在 [cells] 组成的单元内落子。
  static bool digitPlacedIn(SolveContext ctx, List<int> cells, int digit) {
    for (final int index in cells) {
      if (ctx.board.valueAt(index) == digit) {
        return true;
      }
    }
    return false;
  }

  /// 单元内尚未落子的数字（升序）。
  static List<int> unplacedDigitsIn(SolveContext ctx, List<int> cells) => <int>[
        for (int digit = kMinDigit; digit <= kMaxDigit; digit++)
          if (!digitPlacedIn(ctx, cells, digit)) digit,
      ];

  /// 在 [targets] 中删去 [digit]（只保留确实拥有该候选的格），升序去重。
  ///
  /// [excluded] 中的格一律跳过（模式自身的格不得被自己删）。
  static List<Elimination> eliminateDigit(
    SolveContext ctx,
    int digit,
    Iterable<int> targets, {
    Set<int> excluded = const <int>{},
  }) {
    final Set<int> seen = <int>{};
    final List<int> hit = <int>[];
    for (final int index in targets) {
      if (excluded.contains(index) || !seen.add(index)) {
        continue;
      }
      if (ctx.board.isBlank(index) && ctx.candidatesAt(index).contains(digit)) {
        hit.add(index);
      }
    }
    hit.sort();
    return <Elimination>[for (final int index in hit) Elimination(index, digit)];
  }

  /// 在 [targets] 中删去 [digits] 全部数字，按 (格, 数字) 升序。
  static List<Elimination> eliminateDigits(
    SolveContext ctx,
    CandidateSet digits,
    Iterable<int> targets, {
    Set<int> excluded = const <int>{},
  }) {
    final List<Elimination> result = <Elimination>[];
    final List<int> sortedTargets = targets.toSet().toList()..sort();
    for (final int index in sortedTargets) {
      if (excluded.contains(index) || !ctx.board.isBlank(index)) {
        continue;
      }
      final CandidateSet hit = ctx.candidatesAt(index).intersect(digits);
      for (final int digit in hit.digits()) {
        result.add(Elimination(index, digit));
      }
    }
    return result;
  }

  /// 保留 [keep] 之外的候选删除条目（隐性子集用：删去模式格的多余候选）。
  static List<Elimination> retainOnly(
    SolveContext ctx,
    CandidateSet keep,
    Iterable<int> cells,
  ) {
    final List<Elimination> result = <Elimination>[];
    final List<int> sortedCells = cells.toSet().toList()..sort();
    for (final int index in sortedCells) {
      if (!ctx.board.isBlank(index)) {
        continue;
      }
      final CandidateSet extra = ctx.candidatesAt(index).difference(keep);
      for (final int digit in extra.digits()) {
        result.add(Elimination(index, digit));
      }
    }
    return result;
  }

  /// 删数列表 → `r5c2 的 5、r6c2 的 5` 文案。
  static String elimListLabel(Iterable<Elimination> eliminations) =>
      NarrationFormat.elimList(<MapEntry<int, int>>[
        for (final Elimination e in eliminations) MapEntry<int, int>(e.cellIndex, e.digit),
      ]);

  /// 删数列表 → 可视化装配所需的 `cell -> digit` 条目。
  static List<MapEntry<int, int>> elimEntries(Iterable<Elimination> eliminations) =>
      <MapEntry<int, int>>[
        for (final Elimination e in eliminations) MapEntry<int, int>(e.cellIndex, e.digit),
      ];

  /// 填数列表 → 可视化装配所需的 `cell -> digit` 条目。
  static List<MapEntry<int, int>> placeEntries(Iterable<Placement> placements) =>
      <MapEntry<int, int>>[
        for (final Placement p in placements) MapEntry<int, int>(p.cellIndex, p.digit),
      ];

  /// 一组格 × 一个数字 → 可视化「强调候选」条目。
  static List<MapEntry<int, int>> emphasisEntries(Iterable<int> cells, int digit) =>
      <MapEntry<int, int>>[
        for (final int index in cells) MapEntry<int, int>(index, digit),
      ];

  /// 一组格 × 一组数字（按各格实际拥有的候选取交集）→ 可视化「强调候选」条目。
  static List<MapEntry<int, int>> emphasisEntriesOfDigits(
    SolveContext ctx,
    Iterable<int> cells,
    CandidateSet digits,
  ) {
    final List<MapEntry<int, int>> result = <MapEntry<int, int>>[];
    for (final int index in cells) {
      for (final int digit in ctx.candidatesAt(index).intersect(digits).digits()) {
        result.add(MapEntry<int, int>(index, digit));
      }
    }
    return result;
  }

  /// 一组格是否两两互不可见。
  static bool mutuallyUnseen(List<int> cells) {
    for (int i = 0; i < cells.length; i++) {
      for (int j = i + 1; j < cells.length; j++) {
        if (Peers.sees(cells[i], cells[j])) {
          return false;
        }
      }
    }
    return true;
  }

  /// 同时能看到 [cells] 中**全部**格、且候选含 [digit] 的空格（升序）。
  static List<int> commonPeersWithCandidate(
    SolveContext ctx,
    Iterable<int> cells,
    int digit,
  ) => <int>[
        for (final int index in Peers.commonPeers(cells))
          if (ctx.board.isBlank(index) && ctx.candidatesAt(index).contains(digit)) index,
      ];

  /// 一组格所属的**同类**单元编号集合（升序去重）。
  static List<int> unitIdsOfType(UnitType type, Iterable<int> cells) {
    final Set<int> ids = <int>{
      for (final int index in cells) Units.unitIdOf(type, index),
    };
    final List<int> list = ids.toList()..sort();
    return list;
  }

  /// 一组格是否落在同一个 [type] 单元内。
  static bool inSameUnit(UnitType type, Iterable<int> cells) =>
      unitIdsOfType(type, cells).length == 1;

  /// 一组格所在的 2×2 外接矩形角点（可视化 `RegionMark.cornerCells` 用）。
  static List<int> boundingCorners(Iterable<int> cells) {
    final List<int> list = cells.toList(growable: false);
    if (list.isEmpty) {
      return const <int>[];
    }
    int minRow = kBoardSize;
    int maxRow = -1;
    int minCol = kBoardSize;
    int maxCol = -1;
    for (final int index in list) {
      final int row = Coord.rowOf(index);
      final int col = Coord.colOf(index);
      minRow = row < minRow ? row : minRow;
      maxRow = row > maxRow ? row : maxRow;
      minCol = col < minCol ? col : minCol;
      maxCol = col > maxCol ? col : maxCol;
    }
    return <int>[
      Coord.indexOf(minRow, minCol),
      Coord.indexOf(minRow, maxCol),
      Coord.indexOf(maxRow, minCol),
      Coord.indexOf(maxRow, maxCol),
    ];
  }
}
