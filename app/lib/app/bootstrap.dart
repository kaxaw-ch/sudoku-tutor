/// 启动初始化（存档载入/迁移、设置注入、资产预热、崩溃钩子）。
///
/// 批次 E（T-DOM-01）已接入崩溃钩子（`CrashLogService` 本地落盘最近 20 条，
/// 绝不上报）与存档仓储装配。
///
/// 批次 F（T-UI-08）在启动时决定**初始路由**：
/// 读取 `ProgressRepository.load()` 的 `onboardingDone` 字段——
/// 未完成首启引导 → `initialLocation = /onboarding`；已完成 → `/home`。
/// 这是「首启引导不再出现」的最小实现（无 go_router 异步重定向机制，
/// 采用「启动时读档决定初始位置」方案，见 [resolveInitialLocation]）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/app/app.dart';
import 'package:sudoku_tutor/app/providers.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/atomic_file.dart';
import 'package:sudoku_tutor/domain/storage/crash_log_service.dart';
import 'package:sudoku_tutor/domain/storage/json_progress_repository.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';
import 'package:sudoku_tutor/domain/storage/schema_migration.dart';
import 'package:sudoku_tutor/domain/storage/storage_paths.dart';

/// 崩溃日志服务（惰性初始化，避免阻塞首帧）。
Future<CrashLogService>? _crashLogFuture;

/// 初始化崩溃日志服务（路径解析 + 目录就绪）。
Future<CrashLogService> _initCrashLog() async {
  final StoragePaths paths = await StoragePaths.resolve();
  await paths.ensureDirectories();
  return CrashLogService(logsDir: paths.logsDir);
}

/// 依据存档状态决定初始路由（T-UI-08）。
///
/// - `onboardingDone == false`（首启）→ `/onboarding`；
/// - 否则 → `/home`（学习地图）。
/// 提取为纯函数便于单元测试（`test/unit/onboarding/bootstrap_initial_route_test.dart`）。
String resolveInitialLocation(ProgressState state) =>
    state.onboardingDone ? RoutePaths.home : RoutePaths.onboarding;

/// 解析并装配存档仓储（与 `progressRepositoryProvider` 同一装配方式；
/// 启动时解析一次后 override 注入 Provider，全 App 共用同一实例）。
Future<ProgressRepository> _resolveProgressRepository() async {
  final StoragePaths paths = await StoragePaths.resolve();
  await paths.ensureDirectories();
  return JsonProgressRepository(
    paths: paths,
    io: const AtomicFile(),
    migration: SchemaMigration(),
  );
}

/// 启动应用。
///
/// 三层错误捕获（PRD P0-STO-07 底座）：
/// 1. `FlutterError.onError` —— framework 同步错误；
/// 2. `PlatformDispatcher.instance.onError` —— 引擎侧未捕获异步错误；
/// 3. `runZonedGuarded` —— Dart 侧未捕获异步错误。
///
/// 初始化顺序：
/// 1. 崩溃钩子；
/// 2. 解析存档仓储 → 读 `onboardingDone` → 决定初始路由；
/// 3. `runApp`（override 注入已解析仓储，保证引导页/主页读到同一存档）。
Future<void> bootstrap() async {
  runZonedGuarded<void>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      recordError(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack);
      return true;
    };

    // 启动即读档：首启未完成 → 引导页；否则 → 学习地图。
    // 存储解析/读档失败不阻塞启动：回退学习地图并交由各页错误态兜底。
    ProgressRepository? repository;
    String initialLocation = RoutePaths.home;
    try {
      repository = await _resolveProgressRepository();
      final ProgressState state = await repository.load();
      initialLocation = resolveInitialLocation(state);
    } on Object catch (error, stack) {
      recordError(error, stack);
    }

    runApp(
      ProviderScope(
        overrides: <Override>[
          if (repository != null)
            // 启动已解析一次仓储，override 注入避免二次 path_provider 解析。
            progressRepositoryProvider
                .overrideWith((Ref ref) async => repository!),
        ],
        child: SudokuTutorApp(initialLocation: initialLocation),
      ),
    );
  }, recordError);
}

/// 记录一条未捕获异常。
///
/// 异步写入 `CrashLogService`（最近 20 条本地落盘，绝不上报）；
/// 崩溃日志自身的一切失败都被吞掉，绝不引发二次崩溃。
/// debug 模式额外打印，便于本地排障。
void recordError(Object error, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('[未捕获异常] $error');
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }
  unawaited(_recordCrashSafely(error, stack));
}

/// 串行化地落盘一条崩溃日志（全异常吞掉）。
Future<void> _recordCrashSafely(Object error, StackTrace? stack) async {
  try {
    final Future<CrashLogService> future = _crashLogFuture ??= _initCrashLog();
    final CrashLogService service = await future;
    await service.record(
      error,
      stack,
      context: <String, Object?>{
        'deviceInfo': kAppName,
      },
    );
  } on Object {
    // 铁律：崩溃日志失败不得再次触发崩溃回路。
  }
}
