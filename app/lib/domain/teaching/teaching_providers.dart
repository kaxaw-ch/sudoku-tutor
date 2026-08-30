/// 教学关控制器与配套服务的 Riverpod Providers（批次 F：T-EDU-02/03/04/05）。
///
/// 手写 Provider（架构 §7.1：Provider 集中在 `*_providers.dart`）：
/// - [levelCompletionServiceProvider] —— 关卡完成写档（演示/实操/试炼共用）；
/// - [mistakeDetectorProvider] / [mistakeMessageRepositoryProvider] —— 误操作检测与文案；
/// - [demoControllerProvider] —— 原理演示关状态机；
/// - [practiceControllerProvider] —— 引导实操关状态机（含三级提示 + 误操作挂接）；
/// - [trialControllerProvider] —— 验收试炼关状态机。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../curriculum/level_completion_service.dart';
import '../session/session_providers.dart';
import 'demo_controller.dart';
import 'mistake_detector.dart';
import 'mistake_message_repository.dart';
import 'practice_controller.dart';
import 'trial_controller.dart';

/// 关卡完成服务（教学关完成统一走它写档，stars/hintUsed/errorCount 真实采集）。
final Provider<LevelCompletionService> levelCompletionServiceProvider =
    Provider<LevelCompletionService>(
  (Ref ref) => LevelCompletionService(
    repository: ref.watch(progressRepositoryProvider.future),
  ),
);

/// 误操作检测器（T-EDU-04；去重状态随关卡重置）。
final Provider<MistakeDetector> mistakeDetectorProvider =
    Provider<MistakeDetector>((Ref ref) => MistakeDetector());

/// 误操作文案仓库（默认 rootBundle 读 `assets/text/mistakes_zh.json`）。
final Provider<MistakeMessageRepository> mistakeMessageRepositoryProvider =
    Provider<MistakeMessageRepository>((Ref ref) => MistakeMessageRepository());

/// 原理演示关控制器（`null` = 尚未加载）。
final NotifierProvider<DemoController, DemoState?> demoControllerProvider =
    NotifierProvider<DemoController, DemoState?>(DemoController.new);

/// 引导实操关控制器（`null` = 尚未加载）。
final NotifierProvider<PracticeController, PracticeState?>
    practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeState?>(
        PracticeController.new);

/// 验收试炼关控制器（`null` = 尚未加载）。
final NotifierProvider<TrialController, TrialState?> trialControllerProvider =
    NotifierProvider<TrialController, TrialState?>(TrialController.new);
