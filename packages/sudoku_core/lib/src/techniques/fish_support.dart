/// Fish 族（X 翼 / 剑鱼 / 鳍形 X 翼）的行列对称扫描支撑。
///
/// Fish 族的行基与列基算法完全对称，只差一个「(线号, 交叉号) → 格索引」的换算。
/// 本文件把该换算与单元类型抽出，令 3 个识别器各自只写一份算法。
library;

import '../model/coord.dart';
import '../model/unit.dart';
import 'solve_context.dart';

/// Fish 的基集方向。
enum FishOrientation {
  /// 行为基集、列为覆盖集。
  rowBase('rowBase'),

  /// 列为基集、行为覆盖集。
  colBase('colBase');

  const FishOrientation(this.id);

  /// 稳定标识。
  final String id;

  /// 另一方向。
  FishOrientation get flipped =>
      this == FishOrientation.rowBase ? FishOrientation.colBase : FishOrientation.rowBase;
}

/// Fish 族方向换算与扫描（全部为静态纯函数）。
abstract final class FishSupport {
  /// 基集单元类型。
  static UnitType baseType(FishOrientation orientation) =>
      orientation == FishOrientation.rowBase ? UnitType.row : UnitType.col;

  /// 覆盖集单元类型。
  static UnitType coverType(FishOrientation orientation) =>
      orientation == FishOrientation.rowBase ? UnitType.col : UnitType.row;

  /// 由「基线号 [line] + 覆盖线号 [cross]」求格索引。
  static int cellAt(FishOrientation orientation, int line, int cross) =>
      orientation == FishOrientation.rowBase
          ? Coord.indexOf(line, cross)
          : Coord.indexOf(cross, line);

  /// 格 [index] 在基集方向上的线号。
  static int lineOf(FishOrientation orientation, int index) =>
      orientation == FishOrientation.rowBase ? Coord.rowOf(index) : Coord.colOf(index);

  /// 格 [index] 在覆盖集方向上的线号。
  static int crossOf(FishOrientation orientation, int index) =>
      orientation == FishOrientation.rowBase ? Coord.colOf(index) : Coord.rowOf(index);

  /// 基线 [line] 上候选含 [digit] 的**覆盖线号**列表（升序）。
  static List<int> crossPositions(
    SolveContext ctx,
    FishOrientation orientation,
    int line,
    int digit,
  ) {
    final List<int> result = <int>[];
    for (int cross = 0; cross < kBoardSize; cross++) {
      final int index = cellAt(orientation, line, cross);
      if (ctx.board.isBlank(index) && ctx.candidatesAt(index).contains(digit)) {
        result.add(cross);
      }
    }
    return result;
  }

  /// 覆盖线 [cross] 上、排除基线集合 [excludedLines] 之外、候选含 [digit] 的格（升序）。
  static List<int> coverTargets(
    SolveContext ctx,
    FishOrientation orientation,
    int cross,
    int digit,
    Set<int> excludedLines,
  ) {
    final List<int> result = <int>[];
    for (int line = 0; line < kBoardSize; line++) {
      if (excludedLines.contains(line)) {
        continue;
      }
      final int index = cellAt(orientation, line, cross);
      if (ctx.board.isBlank(index) && ctx.candidatesAt(index).contains(digit)) {
        result.add(index);
      }
    }
    result.sort();
    return result;
  }

  /// 基集单元的中文标签，如 `第 2 行与第 8 行`。
  static String baseUnitsLabel(FishOrientation orientation, Iterable<int> lines) =>
      _unitsLabel(baseType(orientation), lines);

  /// 覆盖集单元的中文标签，如 `第 3 列与第 8 列`。
  static String coverUnitsLabel(FishOrientation orientation, Iterable<int> crosses) =>
      _unitsLabel(coverType(orientation), crosses);

  /// 覆盖集单元的中文量词，`列` 或 `行`。
  static String coverTypeLabel(FishOrientation orientation) =>
      coverType(orientation).zhName;

  static String _unitsLabel(UnitType type, Iterable<int> ids) {
    final List<String> labels = <String>[
      for (final int id in ids) Units.of(type, id).zhLabel,
    ];
    if (labels.isEmpty) {
      return '';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    return '${labels.sublist(0, labels.length - 1).join('、')}与${labels.last}';
  }
}
