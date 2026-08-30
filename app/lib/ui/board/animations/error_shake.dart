/// 错误抖动控制器（P0-UI-02 动画，核对答案标红时触发）。
///
/// 使用：页面持有 `ErrorShakeController` 传给 [SudokuBoardView]，
/// 核对出错的回调里调用 [trigger]，棋盘即播放 ~450ms 水平抖动
/// （位移在 `BoardPainter.shakeOffset` 处消费）。
library;

import 'package:flutter/foundation.dart';

/// 抖动触发控制器。
class ErrorShakeController extends ValueNotifier<int> {
  /// 构造控制器（初始信号 0）。
  ErrorShakeController() : super(0);

  /// 触发一次抖动（内部自增信号，[SudokuBoardView] 监听变化）。
  void trigger() => value++;
}
