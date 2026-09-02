/// 教学图层绘制器（T-UI-07 / P0-EDU-03、P0-UI-03/09）。
///
/// ⚠️ **哑渲染铁律**：本 painter 只消费 [VisualHint] 的
/// `cells / regions / links / candidateMarks` 四类标记 + [TeachingOverlayProgress]
/// 动画数值，**不自行计算候选、不读取任何盘面**（UI 零推断，架构 §6.4 / D4）。
/// 所有坐标换算经 [BoardGeometry] 的 `cellRectAt/candidateCenter` 完成，
/// 数据来源唯一：VisualHint。
///
/// 视觉口径：`MarkRole → 颜色 + 形状` 双通道一律来自
/// [TeachingPalette.styleOf]（E-1 已交付，色觉友好）。
///
/// 动画（由宿主 Widget 驱动并喂数值，本 painter 不持有 Animation）：
/// - 多色高亮：透明度由 [TeachingOverlayProgress.highlightOpacity] 控制
///   （对应 `highlight_fade.dart` 的 150–250ms 渐变）；
/// - 虚线矩形：虚线偏移由 [TeachingOverlayProgress.dashOffset] 控制（可流动）；
/// - 连线：长度由 [TeachingOverlayProgress.linkGrow] 控制
///   （对应 `link_grow.dart` 的 200–400ms 缓动生长）；
/// - 候选划除：划线长度由 [TeachingOverlayProgress.strike] 控制
///   （对应 `candidate_strike.dart` 的划除动画）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/ui/theme/teaching_palette.dart';

import 'animations/candidate_strike.dart';
import 'animations/link_grow.dart';
import 'board_geometry.dart';

/// 教学图层动画进度（纯数值输入，painter 哑渲染）。
@immutable
class TeachingOverlayProgress {
  /// 构造动画进度。
  const TeachingOverlayProgress({
    this.highlightOpacity = 1,
    this.linkGrow = 1,
    this.strike = 1,
    this.dashOffset = 0,
  });

  /// 高亮透明度（0..1；1 = 完全显现）。
  final double highlightOpacity;

  /// 连线生长比例（0..1；1 = 完整线段）。
  final double linkGrow;

  /// 候选划除比例（0..1；1 = 划线完成）。
  final double strike;

  /// 虚线矩形 dash 偏移（像素；>0 即开始流动）。
  final double dashOffset;

  /// 静止完成态（golden 测试 / 初始渲染用）。
  static const TeachingOverlayProgress steady = TeachingOverlayProgress();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeachingOverlayProgress &&
          other.highlightOpacity == highlightOpacity &&
          other.linkGrow == linkGrow &&
          other.strike == strike &&
          other.dashOffset == dashOffset);

  @override
  int get hashCode => Object.hash(
        highlightOpacity,
        linkGrow,
        strike,
        dashOffset,
      );
}

/// 教学图层绘制器。
class TeachingOverlayPainter extends CustomPainter {
  /// 构造绘制器。
  TeachingOverlayPainter({
    required this.geometry,
    required this.visual,
    this.progress = TeachingOverlayProgress.steady,
  });

  /// 棋盘几何。
  final BoardGeometry geometry;

  /// 可视化数据（坐标唯一来源）。
  final VisualHint visual;

  /// 动画进度。
  final TeachingOverlayProgress progress;

  // ------------------------------------------------------------ 线宽

  static const double _kRegionDashWidth = 1.6;
  static const double _kRegionInset = 2.5;
  static const double _kLinkWidth = 2.2;
  static const double _kStrikeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    // 1) 区域描边（虚线矩形，可流动）——最底层，避免盖住高亮。
    _paintRegions(canvas);
    // 2) 高亮格（多色 + 形状双通道）。
    _paintCellMarks(canvas);
    // 3) 连线（生长动画）。
    _paintLinks(canvas);
    // 4) 候选标记（划除 / 强调 / 目标）——最顶层。
    _paintCandidateMarks(canvas);
  }

  @override
  bool shouldRepaint(covariant TeachingOverlayPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.visual != visual ||
      oldDelegate.progress != progress;

  // ------------------------------------------------------------ 区域

  /// 绘制区域描边（RegionMark）。
  void _paintRegions(Canvas canvas) {
    for (final RegionMark region in visual.regions) {
      if (region.cornerCells.isEmpty) {
        continue;
      }
      final Rect sourceRect = regionRectFor(region.cornerCells);
      // 区域边框不能与九宫格线或棋盘外框共线，否则虚线会被粗网格线
      // 切碎、染黑。按区域短边限制缩进，极小棋盘也不会产生反向矩形。
      final double inset = math.min(
        _kRegionInset,
        math.min(sourceRect.width, sourceRect.height) * 0.08,
      );
      final Rect rect = sourceRect.deflate(inset);
      final MarkRoleStyle style = TeachingPalette.styleOf(region.role);
      if (region.dashed) {
        _paintDashedRect(
          canvas,
          rect,
          style.color,
          _kRegionDashWidth,
          dashOffset: progress.dashOffset,
        );
      } else {
        _paintSolidRect(canvas, rect, style.color, _kRegionDashWidth);
      }
    }
  }

  /// 由角点格索引计算包围矩形（min/max 行列 → 像素矩形）。
  ///
  /// 公开供测试断言「坐标完全来自 VisualHint 的 cornerCells」。
  Rect regionRectFor(List<int> cornerCells) {
    if (cornerCells.isEmpty) {
      return Rect.zero;
    }
    int minRow = 8, maxRow = 0, minCol = 8, maxCol = 0;
    for (final int index in cornerCells) {
      final int row = index ~/ 9;
      final int col = index % 9;
      if (row < minRow) minRow = row;
      if (row > maxRow) maxRow = row;
      if (col < minCol) minCol = col;
      if (col > maxCol) maxCol = col;
    }
    final Rect topLeft = geometry.cellRect(minRow, minCol);
    final Rect bottomRight = geometry.cellRect(maxRow, maxCol);
    return Rect.fromLTRB(
      topLeft.left,
      topLeft.top,
      bottomRight.right,
      bottomRight.bottom,
    );
  }

  // ------------------------------------------------------------ 高亮格

  /// 绘制高亮格（颜色 + 形状双通道）。
  void _paintCellMarks(Canvas canvas) {
    for (final CellMark mark in visual.cells) {
      final Rect rect = geometry.cellRectAt(mark.index);
      final MarkRoleStyle style = TeachingPalette.styleOf(mark.role);
      _paintCellMark(canvas, rect, style, mark);
    }
  }

  /// 单个 CellMark：半透明填充（受 highlightOpacity 调制）+ 形状通道。
  void _paintCellMark(
    Canvas canvas,
    Rect rect,
    MarkRoleStyle style,
    CellMark mark,
  ) {
    final double alpha = (0.18 * progress.highlightOpacity).clamp(0.0, 0.5);
    canvas.drawRect(
        rect, Paint()..color = style.color.withValues(alpha: alpha));

    switch (style.shape) {
      case ShapeCode.solidThickBorder:
        _paintSolidRect(canvas, rect, style.color, 3.0);
      case ShapeCode.solidThinBorder:
        _paintSolidRect(canvas, rect, style.color, 1.5);
      case ShapeCode.dashedBorder:
        _paintDashedRect(
          canvas,
          rect,
          style.color,
          1.5,
          dashOffset: progress.dashOffset,
        );
      case ShapeCode.dashedBorderWithCornerDot:
        _paintDashedRect(
          canvas,
          rect,
          style.color,
          1.5,
          dashOffset: progress.dashOffset,
        );
        _paintCornerDot(canvas, rect, style.color);
      case ShapeCode.cornerDot:
        _paintCornerDot(canvas, rect, style.color);
      case ShapeCode.diagonalHatch:
        _paintHatch(canvas, rect, style.color);
      case ShapeCode.plainFill:
      case ShapeCode.none:
      case ShapeCode.solidLink:
      case ShapeCode.dashedLink:
      case ShapeCode.strikeThrough:
        break;
    }

    // focusDigits 的候选字形由底层 BoardPainter 直接加粗着色；这里不再
    // 叠加圆点或边框，避免遮挡候选数字。
  }

  // ------------------------------------------------------------ 连线

  /// 绘制连线（LinkMark，生长动画）。
  void _paintLinks(Canvas canvas) {
    for (final LinkMark link in visual.links) {
      final Offset from = geometry.cellRectAt(link.fromCell).center;
      final Offset to = geometry.cellRectAt(link.toCell).center;
      final Offset end = lineEndAt(
        from: from,
        to: to,
        progress: progress.linkGrow,
      );
      if (link.strong) {
        // 强链：实线，绿色（chainStrong 语义）。
        canvas.drawLine(
          from,
          end,
          Paint()
            ..color = TeachingPalette.chainStrong
            ..strokeWidth = _kLinkWidth
            ..strokeCap = StrokeCap.round,
        );
      } else {
        // 弱链：虚线，灰绿（chainWeak 语义），随 dashOffset 流动。
        _dashLineBetween(
          canvas,
          from,
          end,
          Paint()
            ..color = TeachingPalette.chainWeak
            ..strokeWidth = _kLinkWidth,
          dash: 6,
          gap: 4,
          offset: progress.dashOffset,
        );
      }
      // 线上小标：承载数字。
      if (progress.linkGrow >= 0.9) {
        _paintLinkDigit(canvas, from, to, link.digit);
      }
    }
  }

  /// 连线中点上的数字小标。
  void _paintLinkDigit(Canvas canvas, Offset from, Offset to, int digit) {
    final Offset mid = (from + to) / 2;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: '$digit',
        style: TextStyle(
          color: Colors.white,
          fontSize: geometry.cellSize * 0.22,
          fontWeight: FontWeight.w700,
          backgroundColor: TeachingPalette.pattern,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      mid - Offset(painter.width / 2, painter.height / 2),
    );
  }

  // ------------------------------------------------------------ 候选标记

  /// 绘制候选标记（CandidateMark）。
  void _paintCandidateMarks(Canvas canvas) {
    for (final CandidateMark mark in visual.candidateMarks) {
      final Rect cell = geometry.candidateCellRect(mark.cellIndex, mark.digit);
      switch (mark.kind) {
        case CandidateMarkKind.strike:
          // 划除动画：划线长度随 progress.strike。
          final (Offset start, Offset end) =
              strikeSegmentAt(rect: cell, progress: progress.strike);
          if (progress.strike > 0.02) {
            canvas.drawLine(
              start,
              end,
              Paint()
                ..color = TeachingPalette.elimination
                ..strokeWidth = _kStrikeWidth
                ..strokeCap = StrokeCap.round,
            );
          }
        case CandidateMarkKind.emphasize:
          // 候选字形已由 BoardPainter 加粗着色，上层无需重复绘制。
          continue;
        case CandidateMarkKind.target:
          // 结论目标：琥珀色圆点角标，与红色划除线区分。
          canvas.drawCircle(
            Offset(cell.right - 1.5, cell.top + 1.5),
            2.0,
            Paint()..color = TeachingPalette.target,
          );
      }
    }
  }

  // ------------------------------------------------------------ 工具

  /// 实线矩形描边。
  void _paintSolidRect(Canvas canvas, Rect rect, Color color, double width) {
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  /// 虚线矩形描边（dash 偏移实现流动）。
  void _paintDashedRect(
    Canvas canvas,
    Rect rect,
    Color color,
    double width, {
    required double dashOffset,
  }) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = width;
    const double dash = 6;
    const double gap = 4;
    void dashLine(Offset a, Offset b) {
      _dashLineBetween(
        canvas,
        a,
        b,
        paint,
        dash: dash,
        gap: gap,
        offset: dashOffset,
      );
    }

    dashLine(rect.topLeft, rect.topRight);
    dashLine(rect.topRight, rect.bottomRight);
    dashLine(rect.bottomRight, rect.bottomLeft);
    dashLine(rect.bottomLeft, rect.topLeft);
  }

  /// 两点间绘制流动虚线线段。
  void _dashLineBetween(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint, {
    required double dash,
    required double gap,
    required double offset,
  }) {
    final double distance = (b - a).distance;
    if (distance <= 0) {
      return;
    }
    final Offset unit = (b - a) / distance;
    double traveled = -offset % (dash + gap);
    while (traveled < distance) {
      final double start = traveled < 0 ? 0 : traveled;
      final double end = math.min(start + dash, distance);
      if (start < distance) {
        canvas.drawLine(a + unit * start, a + unit * end, paint);
      }
      traveled += dash + gap;
    }
  }

  /// 圆点角标（右上角）。
  void _paintCornerDot(Canvas canvas, Rect rect, Color color) {
    canvas.drawCircle(
      Offset(rect.right - 3, rect.top + 3),
      2.5,
      Paint()..color = color,
    );
  }

  /// 斜纹填充（鳍格形状通道）。
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
}
