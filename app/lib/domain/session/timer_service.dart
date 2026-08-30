/// 对局计时服务（P0-PRA-08，T-DOM-04）。
///
/// 职责：
/// - 自由练习对局计时（毫秒累计，节拍默认 200ms 对齐 UI 显示）；
/// - **失焦/锁屏自动暂停**：由 UI 层监听 `AppLifecycleState` 后调用
///   [pause]（domain 不依赖 Widget 生命周期，职责分离）；
/// - **手动暂停**：`pause()` 后 `isRunning=false`，UI 层据此遮挡盘面
///   （`pause_overlay` 属 T-UI-04，本服务只暴露状态）；
/// - 计时仅在自由练习启用；教学/试炼关由各自控制器决定不启动本服务。
///
/// 纯 Dart 实现（`dart:async`），无 Flutter 依赖，可单测。
library;

import 'dart:async';

/// 计时服务。
class TimerService {
  /// 构造计时服务；[tick] 为节拍间隔（测试可注入长节拍验证「不空转」）。
  TimerService({this.tick = const Duration(milliseconds: 200)});

  /// 节拍间隔。
  final Duration tick;

  Timer? _timer;
  int _elapsedMs = 0;
  bool _running = false;
  bool _started = false;
  DateTime? _lastTick;
  final StreamController<int> _controller = StreamController<int>.broadcast();

  /// 是否正在计时。
  bool get isRunning => _running;

  /// 是否已启动过（区别于「从未启动」；[isPaused] 依赖它）。
  bool get isStarted => _started;

  /// 当前累计毫秒。
  int get elapsedMs => _elapsedMs;

  /// 暂停状态（已启动过且当前未计时）。
  ///
  /// ⚠️ 不依赖 `_elapsedMs > 0`：手动暂停瞬间累计值可能仍为 0
  /// （毫秒粒度对齐前），但遮挡盘面与否只取决于「启动过 + 未运行」。
  bool get isPaused => _started && !_running;

  /// 计时变化流（毫秒，节拍粒度）。
  Stream<int> get elapsedStream => _controller.stream;

  /// 启动/恢复计时。
  ///
  /// 已在计时时重复调用为幂等（不叠加 Timer）。
  void start() {
    if (_running) {
      return;
    }
    _running = true;
    _started = true;
    _lastTick = DateTime.now();
    _timer = Timer.periodic(tick, _onTick);
  }

  /// 暂停计时（失焦/锁屏/手动暂停共用入口）。
  void pause() {
    if (!_running) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    _flush();
    _running = false;
  }

  /// 重置计时（新局开始时）；[elapsedMs] 可指定初值（续玩恢复）。
  void reset({int elapsedMs = 0}) {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _started = false;
    _elapsedMs = elapsedMs;
    _controller.add(elapsedMs);
  }

  /// 释放资源（Provider dispose / 测试收尾）。
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }

  /// 节拍回调：按真实流逝时间累加（避免累积漂移）。
  void _onTick(Timer timer) {
    final DateTime now = DateTime.now();
    final DateTime? last = _lastTick;
    _lastTick = now;
    if (last == null) {
      return;
    }
    _elapsedMs += now.difference(last).inMilliseconds;
    _controller.add(_elapsedMs);
  }

  /// 把节拍内的残留时间也刷进累计值（暂停瞬间保证精确）。
  void _flush() {
    final DateTime? last = _lastTick;
    _lastTick = null;
    if (last == null) {
      return;
    }
    _elapsedMs += DateTime.now().difference(last).inMilliseconds;
  }
}
