/// 音效与震动封装（P0-UI-09，T-UI-06）。
///
/// 职责：
/// - 极简音效（3–5 个 CC0 素材，`assets/audio/*.ogg`，**默认关闭**）；
/// - **不支持平台自动 no-op**（风险 A-05）：桌面端（Windows）与未知平台
///   一律不初始化 audioplayers，任何播放/加载异常静默吞掉，绝不阻塞对局；
/// - 震动走 Flutter 内置 `HapticFeedback`，移动端默认开，桌面端 no-op。
///
/// 素材说明：`assets/audio/` 当前为**占位符**（见该目录 README.md），
/// 因 `SettingsState.soundOn` 默认 `false`，即使误开启也会在
/// 加载/播放失败时降级 no-op，不影响交付。
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 音效服务。
class SoundService {
  /// 构造服务。
  ///
  /// [soundOn] 默认 false（P0-UI-09 默认关闭）；[hapticOn] 移动端默认开。
  /// [player] 可注入（测试用假播放器验证降级路径）。
  SoundService({
    bool soundOn = false,
    bool hapticOn = true,
    AudioPlayer? player,
  })  : _soundOn = soundOn,
        _hapticOn = hapticOn,
        _player = player ?? AudioPlayer();

  /// 音效素材文件名（不含扩展名，`.ogg`）。
  static const List<String> assetNames = <String>[
    'click',
    'success',
    'error',
    'hint',
    'toggle',
  ];

  final AudioPlayer _player;
  bool _soundOn;
  final bool _hapticOn;
  bool _initialized = false;
  bool _supported = false;

  /// 音效是否开启。
  bool get soundOn => _soundOn;

  /// 当前平台是否支持音效（仅 Android / iOS）。
  bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 是否移动端（震动仅在移动端生效）。
  bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 初始化音效（仅当开启音效且平台支持时真正加载）。
  Future<void> init() async {
    if (!_soundOn) {
      _supported = false;
      return;
    }
    if (!platformSupported) {
      _supported = false; // 桌面/未知平台 no-op。
      return;
    }
    _supported = true;
    try {
      for (final String name in assetNames) {
        await _player.setSource(AssetSource('audio/$name.ogg'));
      }
      _initialized = true;
    } on Object {
      // 占位素材加载失败 → 降级 no-op（验收允许）。
      _supported = false;
    }
  }

  /// 切换音效开关（false 时停止播放并降级）。
  void setSoundOn(bool value) {
    _soundOn = value;
    if (!value) {
      unawaited(_player.stop());
      _supported = false;
    }
  }

  /// 落子/按钮点击。
  void playClick() => _play('click');

  /// 正确反馈。
  void playSuccess() => _play('success');

  /// 错误反馈。
  void playError() => _play('error');

  /// 提示出牌。
  void playHint() => _play('hint');

  /// 笔记/擦除等模式切换。
  void playToggle() => _play('toggle');

  /// 轻震动（点击反馈，移动端默认开）。
  void hapticTap() {
    if (!_hapticOn || !isMobile) {
      return;
    }
    try {
      HapticFeedback.selectionClick();
    } on Object {
      // 平台不支持震动 → no-op。
    }
  }

  /// 重震动（错误反馈）。
  void hapticError() {
    if (!_hapticOn || !isMobile) {
      return;
    }
    try {
      HapticFeedback.heavyImpact();
    } on Object {
      // no-op。
    }
  }

  /// 释放资源。
  void dispose() {
    unawaited(_player.dispose());
  }

  /// 播放一个音效（全部失败静默）。
  void _play(String name) {
    if (!_soundOn || !_supported || !_initialized) {
      return;
    }
    try {
      unawaited(_player.play(AssetSource('audio/$name.ogg')));
    } on Object {
      // no-op。
    }
  }
}
