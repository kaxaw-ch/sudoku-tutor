/// 索引 ↔ 行/列/宫换算与单元编号常量（架构文档 §7.1）。
///
/// 索引口径：格索引统一 `0..80`，`index = row * 9 + col`；
/// 对外文案统一 `r{row+1}c{col+1}`。
library;

import '../util/core_error.dart';

/// 棋盘边长。
const int kBoardSize = 9;

/// 宫边长。
const int kBoxSize = 3;

/// 格子总数。
const int kCellCount = 81;

/// 单元（行/列/宫）总数：9 行 + 9 列 + 9 宫。
const int kUnitCount = 27;

/// 坐标换算静态工具。
abstract final class Coord {
  /// 格索引所在行号（0 起）。
  static int rowOf(int index) => index ~/ kBoardSize;

  /// 格索引所在列号（0 起）。
  static int colOf(int index) => index % kBoardSize;

  /// 格索引所在宫号（0 起，从左到右、从上到下）。
  static int boxOf(int index) =>
      (index ~/ (kBoardSize * kBoxSize)) * kBoxSize +
      (index % kBoardSize) ~/ kBoxSize;

  /// 由行列号求格索引。
  static int indexOf(int row, int col) => row * kBoardSize + col;

  /// 格索引的人类可读标签，形如 `r2c3`。
  static String label(int index) => 'r${rowOf(index) + 1}c${colOf(index) + 1}';

  /// 一组格索引的人类可读标签，形如 `r2c3、r7c8`。
  static String labelAll(Iterable<int> indices) => indices.map(label).join('、');

  /// 面向玩家的中文坐标，形如 `第 2 行第 3 列`。
  ///
  /// [label] 保留给日志、指纹与开发工具；教学文本和提示应使用本方法，
  /// 避免把 `r2c3` 这类内部记号暴露给普通玩家。
  static String zhLabel(int index) =>
      '第 ${rowOf(index) + 1} 行第 ${colOf(index) + 1} 列';

  /// 一组格索引的中文坐标，形如 `第 2 行第 3 列、第 7 行第 8 列`。
  static String zhLabelAll(Iterable<int> indices) =>
      indices.map(zhLabel).join('、');

  /// 第 [row] 行的 9 个格索引（升序）。
  static List<int> cellsOfRow(int row) =>
      List<int>.generate(kBoardSize, (int c) => indexOf(row, c),
          growable: false);

  /// 第 [col] 列的 9 个格索引（升序）。
  static List<int> cellsOfCol(int col) =>
      List<int>.generate(kBoardSize, (int r) => indexOf(r, col),
          growable: false);

  /// 第 [box] 宫的 9 个格索引（升序）。
  static List<int> cellsOfBox(int box) {
    final int rowStart = (box ~/ kBoxSize) * kBoxSize;
    final int colStart = (box % kBoxSize) * kBoxSize;
    return List<int>.generate(
      kBoardSize,
      (int i) => indexOf(rowStart + i ~/ kBoxSize, colStart + i % kBoxSize),
      growable: false,
    );
  }

  /// 校验格索引合法性，非法抛 `E_BOARD_005`。
  static void requireIndex(int index) {
    if (index < 0 || index >= kCellCount) {
      throw CoreException(
          CoreErrorCode.boardIndexRange, 'index=$index 超出 0..80');
    }
  }

  /// 校验单元编号合法性，非法抛 `E_BOARD_005`。
  static void requireUnitId(int id) {
    if (id < 0 || id >= kBoardSize) {
      throw CoreException(CoreErrorCode.boardIndexRange, 'unitId=$id 超出 0..8');
    }
  }
}
