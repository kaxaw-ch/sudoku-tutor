/// 引擎服务 Riverpod Providers（架构 §7.1：Provider 集中在 `*_providers.dart`）。
///
/// 手写 Provider（本项目不用 codegen）：
/// - `engineFacadeProvider` —— 业务层/UI 消费的唯一入口；
/// - `engineLoadingProvider` —— `LoadingGate` 的 loading 状态桥（UI 观察用）；
/// - `isolateEngineServiceProvider` / `loadingGateProvider` —— 底层，dispose 挂载。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine_facade.dart';
import 'isolate_engine_service.dart';
import 'loading_gate.dart';

/// 加载闸门（>300ms 上抛 loading）。
final Provider<LoadingGate> loadingGateProvider = Provider<LoadingGate>(
  (Ref ref) {
    final LoadingGate gate = LoadingGate();
    ref.onDispose(gate.dispose);
    return gate;
  },
);

/// 常驻 Isolate 引擎服务。
final Provider<IsolateEngineService> isolateEngineServiceProvider =
    Provider<IsolateEngineService>(
  (Ref ref) {
    final IsolateEngineService service = IsolateEngineService();
    ref.onDispose(() => service.dispose());
    return service;
  },
);

/// 引擎 loading 状态（UI 据此展示「加载指示 >300ms 出现」）。
class EngineLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// 设置 loading 状态。
  void set(bool value) => state = value;
}

/// 引擎 loading 状态 Provider。
final NotifierProvider<EngineLoadingNotifier, bool> engineLoadingProvider =
    NotifierProvider<EngineLoadingNotifier, bool>(EngineLoadingNotifier.new);

/// 引擎门面（评级 / 生成 / 提示扫描的统一入口）。
final Provider<EngineFacade> engineFacadeProvider = Provider<EngineFacade>(
  (Ref ref) {
    final LoadingGate gate = ref.watch(loadingGateProvider);
    final EngineFacade facade = EngineFacade(
      service: ref.watch(isolateEngineServiceProvider),
      loadingGate: gate,
    );
    // 把 loading 状态桥接到 Riverpod（供 UI 观察与 T-UI-04 加载指示测试）。
    gate.onChanged =
        (bool loading) => ref.read(engineLoadingProvider.notifier).set(loading);
    return facade;
  },
);
