/// 教学高亮渐入渐出动画（T-UI-07 / P0-EDU-03）。
///
/// 多色高亮 **150–250ms 渐变**（PRD P0-UI-03/09 的视觉节奏）：
/// - 进入：150ms 渐入（透明度 0 → 1）；
/// - 保持；
/// - 退出：200ms 渐出（1 → 0，供步骤切换时平滑过渡）。
///
/// 本文件只提供**动画定义与驱动**（时长/曲线/进度值），
/// 不参与任何绘制；绘制方（`TeachingOverlayPainter`）只消费数值，
/// 保持「UI 零推断、哑渲染」口径。
library;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart' show Listenable;

/// 渐入时长（150ms，落在验收区间 150–250ms）。
const Duration kHighlightFadeIn = Duration(milliseconds: 150);

/// 渐出时长（200ms，落在验收区间 150–250ms）。
const Duration kHighlightFadeOut = Duration(milliseconds: 200);

/// 渐入曲线：先快后慢（easeOut），让高亮快速浮现后平稳停下。
const Curve kHighlightFadeInCurve = Curves.easeOut;

/// 渐出曲线：缓慢消失。
const Curve kHighlightFadeOutCurve = Curves.easeIn;

/// 由动画进度 `t∈[0,1]` 计算当前透明度（0..1）。
///
/// [t] 为「进入阶段」的 0..1（渐入用）；返回经曲线缓动后的透明度。
double highlightOpacityAt(double t) =>
    kHighlightFadeInCurve.transform(t.clamp(0.0, 1.0));

/// 渐出阶段：由 `t∈[0,1]` 计算剩余透明度（1 → 0）。
double highlightFadeOutAt(double t) =>
    1.0 - kHighlightFadeOutCurve.transform(t.clamp(0.0, 1.0));

/// 高亮动画控制器（一次进入→保持→退出）。
///
/// 用法：`forward()` 播进入；步骤切换时调 [fadeOut] 播退出；
/// [opacity] 为当前应绘制的透明度。
class HighlightFadeController {
  /// 构造控制器；[vsync] 由宿主 Widget 提供。
  HighlightFadeController({required TickerProvider vsync})
      : _fadeIn = AnimationController(
          vsync: vsync,
          duration: kHighlightFadeIn,
        ),
        _fadeOut = AnimationController(
          vsync: vsync,
          duration: kHighlightFadeOut,
        );

  final AnimationController _fadeIn;
  final AnimationController _fadeOut;

  /// 供 [AnimatedBuilder] 监听的合并 Listenable（两个 controller）。
  Listenable get listenable =>
      Listenable.merge(<Listenable>[_fadeIn, _fadeOut]);

  /// 是否正在播放。
  bool get isAnimating => _fadeIn.isAnimating || _fadeOut.isAnimating;

  /// 当前透明度（0..1）。
  double get opacity {
    if (_fadeOut.isAnimating || _fadeOut.value > 0) {
      return highlightFadeOutAt(_fadeOut.value);
    }
    return highlightOpacityAt(_fadeIn.value);
  }

  /// 开始渐入。
  void fadeIn() {
    _fadeOut.value = 0;
    _fadeIn.forward(from: 0);
  }

  /// 开始渐出；完成后回到透明。
  void fadeOut() {
    _fadeOut.forward(from: 0);
  }

  /// 立即到完成态（透明度 1）。
  void complete() {
    _fadeIn.value = 1;
    _fadeOut.value = 0;
  }

  /// 释放底层控制器。
  void dispose() {
    _fadeIn.dispose();
    _fadeOut.dispose();
  }
}
