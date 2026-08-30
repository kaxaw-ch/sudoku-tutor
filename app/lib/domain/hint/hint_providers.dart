/// 提示服务 Riverpod Providers（架构 §7.1：Provider 集中在 `*_providers.dart`）。
///
/// `hintServiceProvider` 把 `EngineFacade.scanHint` 注入 [HintService]，
/// 自由练习/教学场景共享同一实例；新对局开始前调用
/// `resetForNewRound()`（配额与逐级解锁进度重置）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/engine_providers.dart';
import 'hint_service.dart';

/// 提示服务（分级提示 / 配额 / 逐级解锁）。
final Provider<HintService> hintServiceProvider = Provider<HintService>(
  (Ref ref) => HintService(scan: ref.watch(engineFacadeProvider).scanHint),
);
