/// 棋盘 Painter —— 哑渲染（P0-UI-02）。
///
/// 输入只有 [BoardViewModel]（纯数据）+ [BoardGeometry]（几何），
/// **不含任何业务判断**：所有高亮/错误/候选/标记位置由 ViewModel 给出，
/// MarkRole 的视觉由 `TeachingPalette.styleOf`（E-1 已交付）决定。
///
/// 绘制层级（自底向上）：
/// 1. 弱高亮底（同行列宫 / 相同数字强高亮 / 选中格）；
/// 2. 提示与教学高亮（MarkRole 双通道）；
/// 3. 数字与候选数（3×3 微排布）；
/// 4. 错误标红（**只描边不填底**）；
/// 5. 当前棋盘主题的三层级格线（宫粗 / 行列中 / 候选格细）+ 圆角外框。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/session_rules.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';
import 'package:sudoku_tutor/ui/theme/teaching_palette.dart';

import 'board_geometry.dart';
import 'board_view_model.dart';

/// 棋盘绘制器。
class BoardPainter extends CustomPainter {
  /// 构造绘制器；[palette] 为棋盘主题配色（由 Widget 从 BuildContext 注入）。
  BoardPainter({
    required this.geometry,
    required this.viewModel,
    required this.palette,
    this.shakeOffset = 0,
    this.selectionPulse = 0,
  });

  /// 棋盘几何。
  final BoardGeometry geometry;

  /// 渲染数据。
  final BoardViewModel viewModel;

  /// 棋盘主题配色。
  final BoardPalette palette;

  /// 错误抖动水平偏移（像素，由动画驱动，0 = 静止）。
  final double shakeOffset;

  /// 选中格脉冲强度（0..1，由 Widget 动画驱动）。
  final double selectionPulse;

  // ------------------------------------------------------------ 线宽常量

  /// 宫线宽（粗）。
  static const double kBoxLineWidth = 2.0;

  /// 行列线宽（中）。
  static const double kCellLineWidth = 0.8;

  /// 候选微格分隔线宽（细）。
  static const double kCandidateGridLineWidth = 0.3;

  /// 外框线宽。
  static const double kOuterLineWidth = 2.5;

  /// 棋盘圆角半径。
  static const double kBoardCornerRadius = 10;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(shakeOffset, 0);

    // 所有格底、高亮、数字与格线都裁切在圆角棋盘内，最后单独绘制外框。
    canvas.save();
    canvas.clipRRect(_boardRRect);

    _paintBackground(canvas);
    _paintWeakHighlights(canvas);
    _paintHintHighlights(canvas);
    _paintHintRegions(canvas);
    _paintDigitsAndCandidates(canvas);
    _paintHintMarks(canvas);
    _paintErrors(canvas);
    _paintGridLines(canvas);

    canvas.restore();
    _paintOuterBorder(canvas);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.viewModel != viewModel ||
      oldDelegate.shakeOffset != shakeOffset ||
      oldDelegate.selectionPulse != selectionPulse ||
      oldDelegate.palette != palette;

  // ------------------------------------------------------------ 绘制

  /// 棋盘底色。
  void _paintBackground(Canvas canvas) {
    canvas.drawRRect(
      _boardRRect,
      Paint()..color = palette.boardBackground,
    );
  }

  /// 弱高亮（同行列宫 + 相同数字强高亮 + 选中格）。
  void _paintWeakHighlights(Canvas canvas) {
    for (int index = 0; index < 81; index++) {
      final Rect rect = geometry.cellRectAt(index);
      Color? fill;
      if (viewModel.selectedIndex == index) {
        fill = Color.lerp(
          palette.selectionFill,
          palette.selectionPulseFill,
          selectionPulse,
        );
      } else if (viewModel.sameDigitHighlights[index] ==
          SameDigitHighlight.strongFilled) {
        fill = palette.sameDigitFill;
      } else if (viewModel.peerHighlight.contains(index)) {
        fill = palette.peerFill;
      }
      if (fill != null) {
        canvas.drawRect(rect, Paint()..color = fill);
      }
      if (viewModel.selectedIndex == index) {
        _strokeRect(
          canvas,
          rect.deflate(1.5),
          Color.lerp(
            palette.selection,
            Colors.white,
            selectionPulse * 0.35,
          )!,
          2.2 + selectionPulse,
        );
      }
    }
  }

  /// 提示/教学高亮（MarkRole 双通道，TeachingPalette.styleOf）。
  void _paintHintHighlights(Canvas canvas) {
    for (final CellMark mark in viewModel.hintCells) {
      final Rect rect = geometry.cellRectAt(mark.index);
      final MarkRoleStyle style = TeachingPalette.styleOf(mark.role);
      _paintCellMark(canvas, rect, style);
    }
  }

  /// 提示/教学区域描边（RegionMark 虚线框，如隐式唯一的行/列区域）。
  void _paintHintRegions(Canvas canvas) {
    for (final RegionMark region in viewModel.hintRegions) {
      final List<Rect> rects = <Rect>[
        for (final int index in region.cornerCells) geometry.cellRectAt(index),
      ];
      if (rects.isEmpty) {
        continue;
      }
      final Rect bounds = rects.reduce(
        (Rect a, Rect b) => a.expandToInclude(b),
      );
      final MarkRoleStyle style = TeachingPalette.styleOf(region.role);
      final Rect outline = bounds.inflate(4);
      if (region.dashed) {
        _dashedRect(canvas, outline, style.color, 1.5);
      } else {
        _strokeRect(canvas, outline, style.color, 1.5);
      }
    }
  }

  /// 单个 CellMark 的绘制（填充 + 形状通道）。
  void _paintCellMark(Canvas canvas, Rect rect, MarkRoleStyle style) {
    // 颜色通道：半透明填充。
    canvas.drawRect(
      rect,
      Paint()..color = style.color.withValues(alpha: 0.18),
    );
    // 形状通道。
    switch (style.shape) {
      case ShapeCode.solidThickBorder:
        _strokeRect(canvas, rect, style.color, 3.0);
      case ShapeCode.solidThinBorder:
        _strokeRect(canvas, rect, style.color, 1.5);
      case ShapeCode.dashedBorder:
        _dashedRect(canvas, rect, style.color, 1.5);
      case ShapeCode.dashedBorderWithCornerDot:
        _dashedRect(canvas, rect, style.color, 1.5);
        _paintCornerDot(canvas, rect, style.color);
      case ShapeCode.cornerDot:
        _paintCornerDot(canvas, rect, style.color);
      case ShapeCode.diagonalHatch:
        _paintHatch(canvas, rect, style.color);
      case ShapeCode.plainFill:
      // 已用半透明填充表达，无需额外形状。
      case ShapeCode.none:
      case ShapeCode.solidLink:
      case ShapeCode.dashedLink:
      case ShapeCode.strikeThrough:
        break;
    }
  }

  /// 数字与候选数。
  void _paintDigitsAndCandidates(Canvas canvas) {
    for (int index = 0; index < 81; index++) {
      final Rect rect = geometry.cellRectAt(index);
      final int value = viewModel.values[index];
      if (value != kEmptyValue) {
        _paintDigit(
          canvas,
          '$value',
          rect.center,
          _digitStyle(index, value),
        );
      } else {
        _paintCandidates(canvas, index, rect);
      }
    }
  }

  /// 单格数字样式（给定/玩家/错误）。
  TextStyle _digitStyle(int index, int value) {
    final bool isGiven = viewModel.givenMask[index];
    final bool isError =
        viewModel.markErrors && viewModel.errorCells.contains(index);
    final bool isSelected = viewModel.selectedIndex == index;
    final bool isSameStrong =
        viewModel.sameDigitHighlights[index] == SameDigitHighlight.strongFilled;
    final Color color = isSelected
        ? Colors.white
        : isError
            ? GamePalette.error
            : isSameStrong
                ? palette.sameDigit
                : isGiven
                    ? palette.givenDigit
                    : palette.playerDigit;
    return TextStyle(
      color: color,
      fontSize: math.max(0.001, geometry.cellSize * 0.56),
      fontWeight: isSameStrong ? FontWeight.w700 : FontWeight.w600,
      height: 1,
    );
  }

  /// 单格候选数（3×3 微排布）。
  void _paintCandidates(Canvas canvas, int index, Rect rect) {
    final int mask = viewModel.candidateMasks[index];
    if (mask == 0) {
      return;
    }
    final bool noteMode = viewModel.noteMode;
    for (int digit = 1; digit <= 9; digit++) {
      if ((mask & (1 << (digit - 1))) == 0) {
        continue;
      }
      final Offset center = geometry.candidateCenter(index, digit);
      final bool isWeakCandidate = viewModel.sameDigitHighlights[index] ==
              SameDigitHighlight.weakCandidate &&
          viewModel.selectedValue == digit;
      final bool isSelected = viewModel.selectedIndex == index;
      // 提示候选标记：emphasize 加粗着色；strike 划除。
      final CandidateMark? mark = _hintCandidateMark(index, digit);
      final Color color = isSelected
          ? Colors.white
          : mark?.kind == CandidateMarkKind.emphasize
              ? TeachingPalette.pattern
              : isWeakCandidate
                  ? palette.sameDigit
                  : palette.candidate;
      _paintDigit(
        canvas,
        '$digit',
        center,
        TextStyle(
          color: color,
          fontSize:
              math.max(0.001, geometry.cellSize * (noteMode ? 0.30 : 0.26)),
          fontWeight: (isSelected ||
                  isWeakCandidate ||
                  mark?.kind == CandidateMarkKind.emphasize)
              ? FontWeight.w800
              : FontWeight.w400,
          height: 1,
        ),
      );
      if (mark?.kind == CandidateMarkKind.strike) {
        _paintStrike(
          canvas,
          geometry.candidateCellRect(index, digit),
          GamePalette.error,
        );
      }
    }
  }

  /// 提示/教学候选标记（strike / emphasize）。
  void _paintHintMarks(Canvas canvas) {
    for (final CandidateMark mark in viewModel.hintCandidateMarks) {
      final int mask = viewModel.candidateMasks[mark.cellIndex];
      if (mark.cellIndex >= 0 &&
          mark.cellIndex < 81 &&
          (mask & (1 << (mark.digit - 1))) != 0) {
        // 候选绘制阶段已处理 emphasize/strike；这里补区域标记。
      }
    }
  }

  /// 错误标红（只描边不填底）。
  void _paintErrors(Canvas canvas) {
    if (!viewModel.markErrors) {
      return;
    }
    for (final int index in viewModel.errorCells) {
      _strokeRect(
        canvas,
        geometry.cellRectAt(index).deflate(1.5),
        GamePalette.error,
        2.0,
      );
    }
  }

  /// 三层级格线（宫粗 / 行列中 / 候选格细）。
  void _paintGridLines(Canvas canvas) {
    final Paint line = Paint()
      ..color = palette.boxGridLine
      ..strokeWidth = kBoxLineWidth;
    final Paint thin = Paint()
      ..color = palette.cellGridLine
      ..strokeWidth = kCellLineWidth;

    for (int k = 1; k < 9; k++) {
      final double x = geometry.gridLine(k);
      if (k % 3 == 0) {
        canvas.drawLine(Offset(x, geometry.gridLine(0)),
            Offset(x, geometry.gridLine(9)), line);
        canvas.drawLine(Offset(geometry.gridLine(0), x),
            Offset(geometry.gridLine(9), x), line);
      } else {
        canvas.drawLine(Offset(x, geometry.gridLine(0)),
            Offset(x, geometry.gridLine(9)), thin);
        canvas.drawLine(Offset(geometry.gridLine(0), x),
            Offset(geometry.gridLine(9), x), thin);
      }
    }

    // 候选微格细分隔线（细）：仅在有候选的格内绘制。
    final Paint candidateGrid = Paint()
      ..color = palette.candidateGridLine
      ..strokeWidth = kCandidateGridLineWidth;
    for (int index = 0; index < 81; index++) {
      if (viewModel.values[index] != kEmptyValue ||
          viewModel.candidateMasks[index] == 0) {
        continue;
      }
      final Rect rect = geometry.cellRectAt(index);
      for (int step = 1; step < 3; step++) {
        final double dx = rect.left + rect.width * step / 3;
        final double dy = rect.top + rect.height * step / 3;
        canvas.drawLine(
            Offset(dx, rect.top), Offset(dx, rect.bottom), candidateGrid);
        canvas.drawLine(
            Offset(rect.left, dy), Offset(rect.right, dy), candidateGrid);
      }
    }
  }

  /// 当前棋盘主题的深色圆角外框。
  void _paintOuterBorder(Canvas canvas) {
    canvas.drawRRect(
      _boardRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = kOuterLineWidth
        ..color = palette.outerGridLine,
    );
  }

  RRect get _boardRRect => RRect.fromRectAndRadius(
        Rect.fromLTWH(
          geometry.origin,
          geometry.origin,
          geometry.boardExtent,
          geometry.boardExtent,
        ),
        const Radius.circular(kBoardCornerRadius),
      );

  // ------------------------------------------------------------ 工具

  /// 绘制一个居中的文字。
  void _paintDigit(Canvas canvas, String text, Offset center, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  /// 实线矩形描边。
  void _strokeRect(Canvas canvas, Rect rect, Color color, double width) {
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  /// 虚线矩形描边。
  void _dashedRect(Canvas canvas, Rect rect, Color color, double width) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width;
    const double dash = 6;
    const double gap = 4;
    void dashLine(Offset a, Offset b) {
      final double distance = (b - a).distance;
      final Offset unit = (b - a) / distance;
      double traveled = 0;
      while (traveled < distance) {
        final double end = math.min(traveled + dash, distance);
        canvas.drawLine(
          a + unit * traveled,
          a + unit * end,
          paint,
        );
        traveled = end + gap;
      }
    }

    dashLine(rect.topLeft, rect.topRight);
    dashLine(rect.topRight, rect.bottomRight);
    dashLine(rect.bottomRight, rect.bottomLeft);
    dashLine(rect.bottomLeft, rect.topLeft);
  }

  /// 圆点角标（右上角）。
  void _paintCornerDot(Canvas canvas, Rect rect, Color color) {
    canvas.drawCircle(
      Offset(rect.right - 3, rect.top + 3),
      2.5,
      Paint()..color = color,
    );
  }

  /// 斜纹填充（鳍格形状通道，简化为半透明条纹）。
  void _paintHatch(Canvas canvas, Rect rect, Color color) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    const double spacing = 7;
    for (double d = -rect.height; d < rect.width; d += spacing) {
      canvas.drawLine(
        Offset(rect.left + d, rect.bottom),
        Offset(rect.left + d + rect.height, rect.top),
        paint,
      );
    }
  }

  /// 候选划除线（strike）。
  void _paintStrike(Canvas canvas, Rect rect, Color color) {
    canvas.drawLine(
      rect.bottomLeft.translate(2, -2),
      rect.topRight.translate(-2, 2),
      Paint()
        ..color = color
        ..strokeWidth = 1.2,
    );
  }

  /// 取某格某数字的提示候选标记。
  CandidateMark? _hintCandidateMark(int index, int digit) {
    for (final CandidateMark mark in viewModel.hintCandidateMarks) {
      if (mark.cellIndex == index && mark.digit == digit) {
        return mark;
      }
    }
    return null;
  }
}
