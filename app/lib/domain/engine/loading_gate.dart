/// 加载闸门（P0-ENG-12：>300ms 自动上抛 loading，架构 §7.5）。
///
/// 职责：包裹一个耗时 Future，超过 [kLoadingThreshold]（300ms）
/// 未完成即回调 `onChanged(true)`；任务完成或失败立即回调 `false`。
/// UI 侧据此展示「加载指示 >300ms 出现」（T-UI-04 验收点）。
library;

import 'dart:async';

/// 加载阈值（架构 §7.7 常量）。
const Duration kLoadingThreshold = Duration(milliseconds: 300);

/// 加载闸门。
class LoadingGate {
  /// 构造闸门。
  ///
  /// [onChanged] 在 loading 状态翻转时回调（可注入 Riverpod 状态或测试探针），
  /// 支持稍后赋值（如 provider 装配阶段）。
  LoadingGate({
    this.threshold = kLoadingThreshold,
    this.onChanged,
  });

  /// 阈值（可注入短值加速测试）。
  final Duration threshold;

  /// 状态翻转回调（可变，便于 provider 装配时接线）。
  void Function(bool loading)? onChanged;

  Timer? _timer;
  bool _loading = false;

  /// 当前是否处于 loading。
  bool get isLoading => _loading;

  /// 包裹 [action]，超阈值上抛 loading。
  Future<T> run<T>(Future<T> Function() action) async {
    _cancelTimer();
    _set(false);
    _timer = Timer(threshold, () => _set(true));
    try {
      return await action();
    } finally {
      _cancelTimer();
      _set(false);
    }
  }

  /// 释放内部定时器（Provider dispose / 测试收尾）。
  void dispose() => _cancelTimer();

  void _set(bool value) {
    if (_loading == value) {
      return;
    }
    _loading = value;
    onChanged?.call(value);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
