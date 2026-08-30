/// **严格共轭对（强链）** 图：W 翼与简单涂色的共同底座。
///
/// 定义（doc 06 §6.2，本项目**只认这一种强链**）：
/// 若某个单元（行/列/宫）内，数字 `d` 的候选**恰好出现在 2 个空格**，
/// 则这 2 格构成数字 `d` 的一条共轭对（强链）——二者必有且只有一个为 `d`。
///
/// **明确不实现**（doc 08 风险 1，越界即误删）：
/// - grouped strong link（区块强链）；
/// - ALS / AHS 强链；
/// - 单元内出现 3 次及以上的弱链关系。
/// 上述形态一律不产生边，从而不会被 W 翼 / 涂色识别为链路。
library;

import '../model/coord.dart';
import '../model/digit.dart';
import '../model/unit.dart';
import 'solve_context.dart';

/// 一条共轭对（强链）边。
class ConjugateLink {
  /// 构造一条强链边。
  const ConjugateLink({
    required this.a,
    required this.b,
    required this.digit,
    required this.unitType,
    required this.unitId,
  });

  /// 端点 A（较小索引）。
  final int a;

  /// 端点 B（较大索引）。
  final int b;

  /// 承载数字。
  final int digit;

  /// 产生该强链的单元类型。
  final UnitType unitType;

  /// 产生该强链的单元编号。
  final int unitId;

  /// 单元中文标签，如 `第 2 行`。
  String get unitLabel => Units.of(unitType, unitId).zhLabel;

  /// 两端格的中文标签，如 `r2c3、r2c8`。
  String get cellsLabel => '${Coord.label(a)}、${Coord.label(b)}';

  /// [index] 是否为本边端点。
  bool touches(int index) => index == a || index == b;

  /// 取 [index] 的对端；[index] 不是端点时返回 -1。
  int otherEnd(int index) {
    if (index == a) {
      return b;
    }
    if (index == b) {
      return a;
    }
    return -1;
  }

  @override
  String toString() => 'ConjugateLink(${Coord.label(a)}=$digit=${Coord.label(b)}'
      '@${unitType.id}#$unitId)';
}

/// 某个数字的共轭对图（不可变，按需构建）。
class ConjugateGraph {
  ConjugateGraph._(this.digit, this.links, this._adjacency);

  /// 为 [digit] 构建共轭对图。
  factory ConjugateGraph.build(SolveContext ctx, int digit) {
    Digit.requireDigit(digit);
    final List<ConjugateLink> links = <ConjugateLink>[];
    final Set<String> seen = <String>{};

    for (final Unit unit in Units.all) {
      final List<int> positions = <int>[
        for (final int index in unit.cells)
          if (ctx.board.isBlank(index) && ctx.candidatesAt(index).contains(digit)) index,
      ];
      // 铁律：**恰好 2 个**才算强链；1 个是隐性唯一数，≥3 个不构成强链。
      if (positions.length != 2) {
        continue;
      }
      final int a = positions[0] < positions[1] ? positions[0] : positions[1];
      final int b = positions[0] < positions[1] ? positions[1] : positions[0];
      final String key = '$a-$b';
      if (!seen.add(key)) {
        // 同一对格可能同时同行同宫，去重后仍记录首次出现的单元。
        continue;
      }
      links.add(
        ConjugateLink(
          a: a,
          b: b,
          digit: digit,
          unitType: unit.type,
          unitId: unit.id,
        ),
      );
    }

    final Map<int, List<ConjugateLink>> adjacency = <int, List<ConjugateLink>>{};
    for (final ConjugateLink link in links) {
      (adjacency[link.a] ??= <ConjugateLink>[]).add(link);
      (adjacency[link.b] ??= <ConjugateLink>[]).add(link);
    }
    return ConjugateGraph._(
      digit,
      List<ConjugateLink>.unmodifiable(links),
      adjacency,
    );
  }

  /// 图承载的数字。
  final int digit;

  /// 全部强链边。
  final List<ConjugateLink> links;

  final Map<int, List<ConjugateLink>> _adjacency;

  /// 是否不含任何强链。
  bool get isEmpty => links.isEmpty;

  /// 全部端点格（升序）。
  List<int> nodes() {
    final List<int> list = _adjacency.keys.toList()..sort();
    return List<int>.unmodifiable(list);
  }

  /// 与 [index] 相连的强链边（无边时返回空列表）。
  List<ConjugateLink> linksAt(int index) =>
      _adjacency[index] ?? const <ConjugateLink>[];

  /// [index] 通过强链直连的对端格（升序）。
  List<int> neighboursOf(int index) {
    final List<int> list = <int>[
      for (final ConjugateLink link in linksAt(index)) link.otherEnd(index),
    ]..sort();
    return list;
  }

  /// 全部连通分量的**双色染色**结果。
  ///
  /// 每个分量返回一份 `格索引 -> 颜色(0/1)` 映射；只返回节点数 ≥ 2 的分量。
  /// 遍历顺序按最小起点索引升序，保证结果可复现。
  List<Map<int, int>> colouredComponents() {
    final List<Map<int, int>> components = <Map<int, int>>[];
    final Set<int> visited = <int>{};
    for (final int start in nodes()) {
      if (visited.contains(start)) {
        continue;
      }
      final Map<int, int> colours = <int, int>{start: 0};
      final List<int> queue = <int>[start];
      visited.add(start);
      while (queue.isNotEmpty) {
        final int current = queue.removeAt(0);
        final int nextColour = 1 - colours[current]!;
        for (final int neighbour in neighboursOf(current)) {
          if (colours.containsKey(neighbour)) {
            continue;
          }
          colours[neighbour] = nextColour;
          visited.add(neighbour);
          queue.add(neighbour);
        }
      }
      if (colours.length >= 2) {
        components.add(Map<int, int>.unmodifiable(colours));
      }
    }
    return components;
  }

  @override
  String toString() => 'ConjugateGraph(digit=$digit,links=${links.length})';
}
