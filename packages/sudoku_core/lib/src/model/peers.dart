/// 每格 20 个 peer 与 3 个所属单元的静态预计算表。
///
/// peer 定义：与目标格同行、同列或同宫，且不是目标格本身的格子，共 20 个。
library;

import 'coord.dart';
import 'unit.dart';

/// peer 关系静态工具（首次访问时惰性构表）。
abstract final class Peers {
  /// 每格的 peer 数量（固定 20）。
  static const int peerCount = 20;

  static final List<List<int>> _peers = _buildPeers();

  static List<List<int>> _buildPeers() {
    return List<List<int>>.generate(
      kCellCount,
      (int index) {
        final Set<int> set = <int>{};
        for (final Unit unit in Units.unitsOfCell(index)) {
          set.addAll(unit.cells);
        }
        set.remove(index);
        final List<int> list = set.toList()..sort();
        return List<int>.unmodifiable(list);
      },
      growable: false,
    );
  }

  /// 格 [index] 的 20 个 peer（升序、不可变）。
  static List<int> peersOf(int index) {
    Coord.requireIndex(index);
    return _peers[index];
  }

  /// 给定类型与编号的单元所含 9 个格索引。
  static List<int> unitOf(UnitType type, int id) => Units.of(type, id).cells;

  /// 两格是否互相「看得见」（同行/同列/同宫且不同格）。
  ///
  /// 直接按坐标判定，O(1) 且不依赖预计算表。
  static bool sees(int a, int b) {
    if (a == b) {
      return false;
    }
    return Coord.rowOf(a) == Coord.rowOf(b) ||
        Coord.colOf(a) == Coord.colOf(b) ||
        Coord.boxOf(a) == Coord.boxOf(b);
  }

  /// 一组格的公共可见格集合（每个返回的格都能被 [cells] 中所有格看到）。
  ///
  /// 结果不包含 [cells] 自身，升序返回。供 XY 翼 / XYZ 翼 / W 翼等复用。
  static List<int> commonPeers(Iterable<int> cells) {
    final List<int> source = cells.toList(growable: false);
    if (source.isEmpty) {
      return const <int>[];
    }
    final List<int> result = <int>[];
    for (int index = 0; index < kCellCount; index++) {
      if (source.contains(index)) {
        continue;
      }
      bool visibleByAll = true;
      for (final int cell in source) {
        if (!sees(index, cell)) {
          visibleByAll = false;
          break;
        }
      }
      if (visibleByAll) {
        result.add(index);
      }
    }
    return result;
  }

  /// 格 [index] 所属 3 个单元的编号：`[rowId, colId, boxId]`。
  static List<int> unitIdsOf(int index) {
    Coord.requireIndex(index);
    return <int>[Coord.rowOf(index), Coord.colOf(index), Coord.boxOf(index)];
  }
}
