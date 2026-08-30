/// T-UI-06 · 音效与震动封装 no-op 降级测试（P0-UI-09）。
///
/// 覆盖：默认关闭、桌面平台 no-op、加载失败降级、移动端震动开启、
/// 所有路径都不抛异常。
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/widgets/sound_service.dart';

/// 假播放器：任何加载/播放都抛异常（验证降级不崩溃）。
class _ThrowingAudioPlayer extends AudioPlayer {
  @override
  Future<void> setSource(Source source) async {
    throw StateError('占位素材不可用');
  }

  @override
  Future<void> play(
    Source source, {
    double? balance,
    AudioContext? ctx,
    PlayerMode? mode,
    Duration? position,
    double? volume,
  }) async {
    throw StateError('播放失败');
  }

  @override
  Future<void> stop() async {}
}

/// 假播放器：成功路径（验证移动端 supported 分支）。
class _OkAudioPlayer extends AudioPlayer {
  @override
  Future<void> setSource(Source source) async {}

  @override
  Future<void> play(
    Source source, {
    double? balance,
    AudioContext? ctx,
    PlayerMode? mode,
    Duration? position,
    double? volume,
  }) async {}

  @override
  Future<void> stop() async {}
}

void main() {
  // AudioPlayer / HapticFeedback 依赖 ServicesBinding，测试环境需先初始化。
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();

  // audioplayers 构造时经 MethodChannel 初始化 GlobalAudioScope 与播放器
  // 实例；测试环境无平台实现，mock 掉这两个通道。
  setUp(() {
    for (final String channel in <String>[
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (MethodCall call) async => null,
      );
    }
  });
  tearDown(() {
    for (final String channel in <String>[
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        null,
      );
    }
  });

  test('默认关闭：soundOn 为 false，init 后不加载、播放 no-op', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final SoundService service = SoundService(
      soundOn: false,
      player: _ThrowingAudioPlayer(), // 若被调用必然抛异常。
    );
    await service.init();
    expect(service.soundOn, isFalse);
    // 全部播放路径不抛异常。
    service.playClick();
    service.playSuccess();
    service.playError();
    service.playHint();
    service.playToggle();
    service.hapticTap();
    service.hapticError();
  });

  test('桌面平台（Windows）：soundOn 即使为 true 也 no-op', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final SoundService service = SoundService(
      soundOn: true,
      player: _ThrowingAudioPlayer(),
    );
    await service.init();
    expect(service.platformSupported, isFalse, reason: '桌面端不支持音效');
    service.playClick();
    service.playSuccess();
  });

  test('移动端加载失败（占位素材缺失）→ 降级 no-op，不抛异常', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final SoundService service = SoundService(
      soundOn: true,
      player: _ThrowingAudioPlayer(),
    );
    await service.init();
    // init 捕获异常后 _supported=false，播放静默。
    service.playClick();
    service.playError();
  });

  test('移动端正常路径：supported=true 且播放不抛', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final SoundService service = SoundService(
      soundOn: true,
      player: _OkAudioPlayer(),
    );
    await service.init();
    expect(service.platformSupported, isTrue);
    service.playClick();
    service.playSuccess();
  });

  test('震动：桌面 no-op，移动端开启且不抛', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final SoundService desktop = SoundService(hapticOn: true);
    desktop.hapticTap();
    desktop.hapticError();
    debugDefaultTargetPlatformOverride = null;

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final SoundService mobile = SoundService(hapticOn: true);
    mobile.hapticTap();
    mobile.hapticError();
    debugDefaultTargetPlatformOverride = null;
  });

  test('setSoundOn(false) 停用后播放 no-op', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final SoundService service = SoundService(
      soundOn: true,
      player: _OkAudioPlayer(),
    );
    await service.init();
    service.setSoundOn(false);
    expect(service.soundOn, isFalse);
    service.playClick(); // 不抛。
  });
}
