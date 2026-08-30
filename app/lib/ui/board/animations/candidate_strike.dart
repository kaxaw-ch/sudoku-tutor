/// 教学候选划除动画（T-UI-07 / P0-EDU-03）。
///
/// 候选划除：在候选数字上画一条由左上到右下的划除线。
/// 动画让划除线从起点**逐渐画出**（进度 0..1 控制线长），
/// 模拟「这一候选被划掉」的书写过程。
///
/// 本文件只提供动画定义与划线端点计算（纯数值/几何），
/// 不参与绘制；绘制方消费 [strikeProgressAt]/[strikeSegmentAt] 的结果。
library;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show Listenable;

/// 划除动画时长（250ms，与高亮节奏一致）。
const Duration kCandidateStrikeDuration = Duration(milliseconds: 250);

/// 划除曲线：easeOut，让划线先快后慢。
const Curve kCandidateStrikeCurve = Curves.easeOut;

/// 由动画进度 `t∈[0,1]` 计算划除线完成比例（0..1，已缓动）。
double strikeProgressAt(double t) =>
    kCandidateStrikeCurve.transform(t.clamp(0.0, 1.0));

/// 计算划除线在候选小格矩形 [rect] 内、生长到 [progress] 时的线段。
///
/// - 划线方向固定为「左上 → 右下」（划过数字）；
/// - 返回 `(start, end)`；[progress]=0 时线长为 0（不可见）。
(Offset, Offset) strikeSegmentAt({
  required Rect rect,
  required double progress,
}) {
  final double p = progress.clamp(0.0, 1.0);
  final Offset start =
      Offset(rect.left + rect.width * 0.18, rect.top + rect.height * 0.82);
  final Offset end =
      Offset(rect.right - rect.width * 0.18, rect.top + rect.height * 0.18);
  return (start, start + (end - start) * p);
}

/// 候选划除动画控制器（单次 forward）。
///
/// 用法：`forward()` 播一次；[progress] 为当前划线比例。
class CandidateStrikeController {
  /// 构造控制器；[vsync] 由宿主 Widget 提供。
  CandidateStrikeController({required TickerProvider vsync})
      : _controller = AnimationController(
          vsync: vsync,
          duration: kCandidateStrikeDuration,
        );

  final AnimationController _controller;

  /// 供 [AnimatedBuilder] 监听的 Listenable。
  Listenable get listenable => _controller;

  /// 是否正在播放。
  bool get isAnimating => _controller.isAnimating;

  /// 当前划线比例（0..1，已缓动）。
  double get progress => strikeProgressAt(_controller.value);

  /// 开始划线。
  void forward() => _controller.forward(from: 0);

  /// 立即到完成态（比例 1）。
  void complete() => _controller.value = 1;

  /// 重置回起点（比例 0）。
  void reset() => _controller.value = 0;

  /// 释放底层控制器。
  void dispose() => _controller.dispose();
}
