/// 教学连线生长动画（T-UI-07 / P0-EDU-03）。
///
/// 连线（共轭对/链）**生长 200–400ms 缓动**：从起点格中心出发，
/// 沿终点方向按进度 t 截取线段，模拟「从一端画出到另一端」。
///
/// 本文件只提供动画定义与线段截取计算（纯数值/几何），
/// 不参与绘制；绘制方消费 [growProgressAt]/[segmentBetween] 的结果。
library;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show Listenable;

/// 生长时长（300ms，落在验收区间 200–400ms）。
const Duration kLinkGrowDuration = Duration(milliseconds: 300);

/// 生长曲线：easeInOutCubic，先慢后快再慢，让连线「画出来」更自然。
const Curve kLinkGrowCurve = Curves.easeInOutCubic;

/// 由动画进度 `t∈[0,1]` 计算连线生长比例（0..1，已缓动）。
double growProgressAt(double t) => kLinkGrowCurve.transform(t.clamp(0.0, 1.0));

/// 计算生长到 [progress]（0..1）时的线段端点。
///
/// - 返回 `(start, end)`：起点恒为 [from]；终点为沿 `from→to` 方向
///   截取 `progress` 比例的坐标。
/// - [progress] 为 0 时线段退化为起点（不可见）；为 1 时覆盖整条。
Offset lineEndAt({
  required Offset from,
  required Offset to,
  required double progress,
}) {
  final double p = progress.clamp(0.0, 1.0);
  return from + (to - from) * p;
}

/// 连线生长动画控制器（单次 forward）。
///
/// 用法：`forward()` 播一次；[progress] 为当前生长比例。
class LinkGrowController {
  /// 构造控制器；[vsync] 由宿主 Widget 提供。
  LinkGrowController({required TickerProvider vsync})
      : _controller = AnimationController(
          vsync: vsync,
          duration: kLinkGrowDuration,
        );

  final AnimationController _controller;

  /// 供 [AnimatedBuilder] 监听的 Listenable。
  Listenable get listenable => _controller;

  /// 是否正在播放。
  bool get isAnimating => _controller.isAnimating;

  /// 当前生长比例（0..1，已缓动）。
  double get progress => growProgressAt(_controller.value);

  /// 开始生长。
  void forward() => _controller.forward(from: 0);

  /// 立即到完成态（比例 1）。
  void complete() => _controller.value = 1;

  /// 重置回起点（比例 0）。
  void reset() => _controller.value = 0;

  /// 释放底层控制器。
  void dispose() => _controller.dispose();
}
