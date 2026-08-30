/// 单元（行/列/宫）抽象与遍历器。
library;

import 'package:meta/meta.dart';

import 'coord.dart';

/// 单元类型。
enum UnitType {
  /// 行。
  row('row', '行'),

  /// 列。
  col('col', '列'),

  /// 宫。
  box('box', '宫');

  const UnitType(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文名称（用于讲解文案拼接）。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static UnitType? tryParse(String id) {
    for (final UnitType value in UnitType.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 一个单元：类型 + 编号 + 所含 9 个格索引。
@immutable
class Unit {
  const Unit._(this.type, this.id, this.cells);

  /// 单元类型。
  final UnitType type;

  /// 单元编号（0..8）。
  final int id;

  /// 单元内 9 个格索引（升序，不可变）。
  final List<int> cells;

  /// 人类可读标签：`第 2 行` / `第 3 列` / `第 5 宫`。
  String get zhLabel => '第 ${id + 1} ${type.zhName}';

  /// 该单元是否包含格 [index]。
  bool contains(int index) => cells.contains(index);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Unit && other.type == type && other.id == id);

  @override
  int get hashCode => Object.hash(type, id);

  @override
  String toString() => 'Unit(${type.id}#$id)';
}

/// 27 个单元的静态预计算表与查询工具。
abstract final class Units {
  static final List<Unit> _rows = List<Unit>.generate(
    kBoardSize,
    (int i) => Unit._(UnitType.row, i, Coord.cellsOfRow(i)),
    growable: false,
  );

  static final List<Unit> _cols = List<Unit>.generate(
    kBoardSize,
    (int i) => Unit._(UnitType.col, i, Coord.cellsOfCol(i)),
    growable: false,
  );

  static final List<Unit> _boxes = List<Unit>.generate(
    kBoardSize,
    (int i) => Unit._(UnitType.box, i, Coord.cellsOfBox(i)),
    growable: false,
  );

  static final List<Unit> _all = List<Unit>.unmodifiable(<Unit>[..._rows, ..._cols, ..._boxes]);

  /// 全部 27 个单元（行 9 → 列 9 → 宫 9）。
  static List<Unit> get all => _all;

  /// 全部 9 个行单元。
  static List<Unit> get rows => _rows;

  /// 全部 9 个列单元。
  static List<Unit> get cols => _cols;

  /// 全部 9 个宫单元。
  static List<Unit> get boxes => _boxes;

  /// 按类型与编号取单元。
  static Unit of(UnitType type, int id) {
    Coord.requireUnitId(id);
    return switch (type) {
      UnitType.row => _rows[id],
      UnitType.col => _cols[id],
      UnitType.box => _boxes[id],
    };
  }

  /// 格 [index] 所属的 3 个单元（行、列、宫）。
  static List<Unit> unitsOfCell(int index) {
    Coord.requireIndex(index);
    return <Unit>[
      _rows[Coord.rowOf(index)],
      _cols[Coord.colOf(index)],
      _boxes[Coord.boxOf(index)],
    ];
  }

  /// 格 [index] 在给定类型单元中的编号。
  static int unitIdOf(UnitType type, int index) => switch (type) {
        UnitType.row => Coord.rowOf(index),
        UnitType.col => Coord.colOf(index),
        UnitType.box => Coord.boxOf(index),
      };
}
