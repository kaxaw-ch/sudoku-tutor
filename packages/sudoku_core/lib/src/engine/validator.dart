/// 盘面合法性校验与冲突检测（PRD P0-ENG-02）。
library;

import 'package:meta/meta.dart';

import '../model/board.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../model/unit.dart';
import '../util/core_error.dart';

/// 一处冲突：同一单元内两格填了相同数字。
@immutable
class Conflict {
  /// 构造一处冲突。
  const Conflict({
    required this.indexA,
    required this.indexB,
    required this.digit,
    required this.unitType,
    required this.unitId,
  });

  /// 冲突格 A（索引较小者）。
  final int indexA;

  /// 冲突格 B（索引较大者）。
  final int indexB;

  /// 冲突数字。
  final int digit;

  /// 冲突所在单元类型。
  final UnitType unitType;

  /// 冲突所在单元编号。
  final int unitId;

  /// 简体中文描述，如「第 3 行 内 r3c1 与 r3c7 同为 5」。
  String get zhDescription =>
      '${Units.of(unitType, unitId).zhLabel} 内 ${Coord.label(indexA)} 与 '
      '${Coord.label(indexB)} 同为 $digit';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conflict &&
          other.indexA == indexA &&
          other.indexB == indexB &&
          other.digit == digit &&
          other.unitType == unitType &&
          other.unitId == unitId);

  @override
  int get hashCode => Object.hash(indexA, indexB, digit, unitType, unitId);

  @override
  String toString() => 'Conflict($zhDescription)';
}

/// 盘面校验静态工具（全部纯函数，不修改盘面）。
abstract final class Validator {
  /// 在格 [index] 填入 [digit] 是否合法（同行/列/宫无重复）。
  ///
  /// 不考虑该格自身当前值；若该格已填同一数字，仍视为合法。
  static bool isValidPlacement(Board board, int index, int digit) {
    Coord.requireIndex(index);
    Digit.requireDigit(digit);
    for (final Unit unit in Units.unitsOfCell(index)) {
      for (final int cell in unit.cells) {
        if (cell != index && board.values[cell] == digit) {
          return false;
        }
      }
    }
    return true;
  }

  /// [isValidPlacement] 的行列版本。
  static bool isValidPlacementAt(Board board, int row, int col, int digit) =>
      isValidPlacement(board, Coord.indexOf(row, col), digit);

  /// 找出盘面上全部冲突（按单元遍历，同一对格子只上报一次）。
  static List<Conflict> findConflicts(Board board) {
    final List<Conflict> conflicts = <Conflict>[];
    for (final Unit unit in Units.all) {
      // firstIndexOfDigit[d] 记录该单元内数字 d 第一次出现的格索引。
      final List<int> firstIndexOfDigit = List<int>.filled(kMaxDigit + 1, -1);
      for (final int cell in unit.cells) {
        final int value = board.values[cell];
        if (value == kEmptyValue) {
          continue;
        }
        final int first = firstIndexOfDigit[value];
        if (first == -1) {
          firstIndexOfDigit[value] = cell;
        } else {
          conflicts.add(
            Conflict(
              indexA: first < cell ? first : cell,
              indexB: first < cell ? cell : first,
              digit: value,
              unitType: unit.type,
              unitId: unit.id,
            ),
          );
        }
      }
    }
    return conflicts;
  }

  /// 盘面是否存在冲突。
  static bool hasConflict(Board board) {
    for (final Unit unit in Units.all) {
      int seen = 0;
      for (final int cell in unit.cells) {
        final int value = board.values[cell];
        if (value == kEmptyValue) {
          continue;
        }
        final int bit = 1 << (value - 1);
        if ((seen & bit) != 0) {
          return true;
        }
        seen |= bit;
      }
    }
    return false;
  }

  /// 参与冲突的全部格索引（升序、去重）。
  static Set<int> conflictCells(Board board) {
    final Set<int> cells = <int>{};
    for (final Conflict conflict in findConflicts(board)) {
      cells
        ..add(conflict.indexA)
        ..add(conflict.indexB);
    }
    return cells;
  }

  /// 盘面是否自洽（无冲突，允许有空格）。
  static bool isConsistent(Board board) => !hasConflict(board);

  /// 盘面是否已完成（填满 81 格且无冲突）。
  static bool isComplete(Board board) => board.isFull && !hasConflict(board);

  /// 校验盘面自洽，不自洽抛 `E_BOARD_003`。
  static void requireConsistent(Board board) {
    final List<Conflict> conflicts = findConflicts(board);
    if (conflicts.isNotEmpty) {
      throw CoreException(CoreErrorCode.boardInconsistent, conflicts.first.zhDescription);
    }
  }

  /// 校验一组数值是否为合法终局解（81 格填满且无冲突）。
  static bool isValidSolution(List<int> values) {
    if (values.length != kCellCount) {
      return false;
    }
    for (final int value in values) {
      if (value < kMinDigit || value > kMaxDigit) {
        return false;
      }
    }
    for (final Unit unit in Units.all) {
      int seen = 0;
      for (final int cell in unit.cells) {
        final int bit = 1 << (values[cell] - 1);
        if ((seen & bit) != 0) {
          return false;
        }
        seen |= bit;
      }
    }
    return true;
  }
}
