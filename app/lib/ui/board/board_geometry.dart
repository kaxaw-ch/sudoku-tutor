/// 棋盘几何 —— 格索引 ↔ 像素换算、候选数 3×3 微排布定位（P0-UI-02）。
///
/// 纯几何工具（不依赖任何状态）：给定画布 [size] 与 [padding]，
/// 按「正方形 9×9 + 等比内边距」布局，全部换算收敛到一处，
/// Painter / 手势 / 候选定位共用本文件，避免坐标口径漂移。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 棋盘几何。
class BoardGeometry {
  /// 构造几何。
  ///
  /// [size] 为画布尺寸（宽高不必相等，取短边做棋盘）；[padding] 为内边距。
  BoardGeometry({required this.size, this.padding = 12.0}) {
    assert(size.width > 0 && size.height > 0);
  }

  /// 画布尺寸。
  final Size size;

  /// 棋盘内边距（相对短边）。
  final double padding;

  /// 棋盘实际边长（短边减去两侧内边距）。
  ///
  /// 防御：极端小尺寸（如布局被压缩时）下归零而非负值，
  /// 避免 `cellSize`/字号等派生量为负导致渲染断言崩溃。
  double get boardExtent =>
      math.max(0.0, math.min(size.width, size.height) - padding * 2);

  /// 单格边长。
  double get cellSize => boardExtent / 9;

  /// 棋盘左上角原点（居中）。
  double get origin => (math.min(size.width, size.height) - boardExtent) / 2;

  /// 第 [k] 条格线（0..9）的像素位置。
  double gridLine(int k) => origin + k * cellSize;

  /// 格 (row, col) 的矩形。
  Rect cellRect(int row, int col) => Rect.fromLTWH(
        gridLine(col),
        gridLine(row),
        cellSize,
        cellSize,
      );

  /// 格 [index]（0..80）的矩形。
  Rect cellRectAt(int index) => cellRect(index ~/ 9, index % 9);

  /// 由画布坐标反查格索引；落在棋盘外返回 `null`。
  int? indexAt(Offset offset) {
    final double localX = offset.dx - origin;
    final double localY = offset.dy - origin;
    if (localX < 0 ||
        localY < 0 ||
        localX >= boardExtent ||
        localY >= boardExtent) {
      return null;
    }
    final int col = (localX ~/ cellSize).clamp(0, 8);
    final int row = (localY ~/ cellSize).clamp(0, 8);
    return row * 9 + col;
  }

  /// 格 [index] 内候选数字 [digit]（1..9）的 3×3 微排布中心。
  ///
  /// 小格坐标：`digit` 行 = `(digit-1) ~/ 3`、列 = `(digit-1) % 3`。
  Offset candidateCenter(int index, int digit) {
    final Rect rect = cellRectAt(index);
    final double step = rect.width / 3;
    final int row = (digit - 1) ~/ 3;
    final int col = (digit - 1) % 3;
    return Offset(
      rect.left + step * (col + 0.5),
      rect.top + step * (row + 0.5),
    );
  }

  /// 格 [index] 内候选数字 [digit] 对应的 3×3 小格矩形（细分隔线绘制用）。
  Rect candidateCellRect(int index, int digit) {
    final Rect rect = cellRectAt(index);
    final double step = rect.width / 3;
    final int row = (digit - 1) ~/ 3;
    final int col = (digit - 1) % 3;
    return Rect.fromLTWH(
      rect.left + step * col,
      rect.top + step * row,
      step,
      step,
    );
  }
}
