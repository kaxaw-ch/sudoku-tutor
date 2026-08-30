/// 响应式外壳（P0-UI-01 布局护栏：居中限宽 + 最小窗口 900×640 等比缩放）。
///
/// 规则：
/// - 窗口 ≥ 设计稿（[kDesignWidth]×[kDesignHeight] = 900×640）时：
///   内容**居中限宽**（[maxContentWidth]，默认 640），不再放大；
/// - 窗口 < 设计稿时：按 `min(w/900, h/640)` **等比缩小**整个子树
///   （`Transform.scale`），保持设计稿布局比例，不触发小窗重排。
///
/// 用法：挂在 `MaterialApp.builder` 的最外层（在 `TextScaleClamp` 之上），
/// 使全部页面统一获得「小窗等比缩放」能力。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 响应式外壳。
class ResponsiveShell extends StatelessWidget {
  /// 构造外壳。
  const ResponsiveShell({
    required this.child,
    this.maxContentWidth = kMaxContentWidth,
    super.key,
  });

  /// 设计稿宽度（最小窗口宽度）。
  static const double kDesignWidth = 900;

  /// 设计稿高度（最小窗口高度）。
  static const double kDesignHeight = 640;

  /// 默认内容最大宽度（居中限宽）。
  ///
  /// 桌面横向布局（自由练习：左棋盘 + 加宽操作列）需要 ≥900 宽内容；
  /// 640 会把宽屏内容压成窄条导致横向布局失效（用户实测：全屏后变竖排）。
  static const double kMaxContentWidth = 1200;

  /// 内容最大宽度（大窗口时居中限宽）。
  final double maxContentWidth;

  /// 子树内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double scale = math.min(
      size.width / kDesignWidth,
      size.height / kDesignHeight,
    );

    // 内容（居中 + 限宽）。
    final Widget centered = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );

    // 窗口足够大：仅居中限宽，不缩放。
    if (scale >= 1) {
      return centered;
    }

    // 小窗口：按设计稿比例等比缩放（Alignment.center 保证视觉居中）。
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: SizedBox(
          width: kDesignWidth,
          height: kDesignHeight,
          child: centered,
        ),
      ),
    );
  }
}
