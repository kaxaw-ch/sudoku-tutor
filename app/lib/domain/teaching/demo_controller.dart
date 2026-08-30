/// 原理演示关控制器（T-EDU-02 / P0-EDU-02，S-03）。
///
/// 职责：
/// - 加载 [LessonLevel]（演示关必带 `script.steps`），盘面**只读**逐步播放；
/// - 默认手动「下一步」；另提供自动播放（2s/步，可暂停）、上一步、重播、进度 `n/m`；
/// - 技巧进度条可直接跳到某技巧首次出现的步骤；
/// - **首次进入须完整看完，之后可跳过**：进入时读存档，本关已完成则
///   [DemoState.seenBefore]=true（UI 据此放行跳过）；首次未看完时 UI 拦截返回；
/// - **看完最后一步即算完成**：`next()` 推进到最后一步时调用
///   [LevelCompletionService.recordCompletion]（hintUsed=0、errorCount=0，真实写档）。
///
/// 演示盘面由 [boardAt] 装配（初始盘面 + 应用 `steps[0..currentIndex]`），
/// 应用顺序与 `sudoku_core` 的 `ScriptReplayer` 一致（先删后填 + syncAfterPlace），
/// 保证候选显示与脚本口径一致；UI 层只消费结果，不重复实现任何算法。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/core/core.dart';

import '../curriculum/curriculum_providers.dart';
import '../curriculum/curriculum_repository.dart';
import '../curriculum/level_completion_service.dart';
import '../session/session_providers.dart';
import '../storage/models/level_progress.dart';
import '../storage/models/progress_state.dart';
import '../storage/progress_repository.dart';
import 'teaching_providers.dart';

/// 自动播放步进间隔（P0-EDU-02：2s/步）。
const Duration kDemoAutoStepInterval = Duration(seconds: 2);

/// 快速自动播放间隔（用户要求：每秒两步）。
const Duration kDemoFastStepInterval = Duration(milliseconds: 500);

/// 原理演示关不可变状态。
class DemoState {
  /// 构造演示状态。
  DemoState({
    required this.level,
    required this.currentIndex,
    required this.autoPlaying,
    required this.completed,
    required this.seenBefore,
    required this.elapsedMs,
    this.autoPlayFast = false,
  }) : steps = level.script?.steps ?? const <ScriptStep>[];

  /// 本关数据。
  final LessonLevel level;

  /// 脚本步骤（演示关必有脚本；防御为空）。
  final List<ScriptStep> steps;

  /// 当前展示的步骤索引（0-based；展示 `steps[currentIndex]`）。
  final int currentIndex;

  /// 是否自动播放中。
  final bool autoPlaying;

  /// 是否快速自动播放（每秒两步，`false` = 每 2 秒一步）。
  final bool autoPlayFast;

  /// 本次是否已看完最后一步（看完最后一步即算完成，P0-EDU-08）。
  final bool completed;

  /// 存档中该关此前是否已完成（已完成 → 之后可跳过）。
  final bool seenBefore;

  /// 从进入起累计的演示用时（毫秒）。
  final int elapsedMs;

  /// 总步数。
  int get stepCount => steps.length;

  /// 步骤进度（1-based；`n/m` 中的 n）。
  int get progress => currentIndex + 1;

  /// 当前步骤。
  ScriptStep get currentStep => steps[currentIndex];

  /// 当前步骤旁白（空脚本/缺省时回退标题）。
  String get narration => currentStep.narration?.isNotEmpty == true
      ? NarrationFormat.localizeCoordinates(currentStep.narration!)
      : '（本步为「${currentStep.techniqueId.zhName}」讲解）';

  /// 当前步骤可视化（教学图层 T-UI-07 消费，UI 零推断）。
  VisualHint get currentVisual => currentStep.visual;

  /// 当前步骤技巧。
  TechniqueId get techniqueId => currentStep.techniqueId;

  /// 是否已到最后一格（无下一步可走）。
  bool get atEnd => currentIndex >= stepCount - 1;

  /// 当前是否应拦截退出（首次且未看完 → 必须看完）。
  bool get mustWatchToEnd => !seenBefore && !completed;

  /// 返回替换部分字段后的副本。
  DemoState copyWith({
    int? currentIndex,
    bool? autoPlaying,
    bool? autoPlayFast,
    bool? completed,
    bool? seenBefore,
    int? elapsedMs,
  }) =>
      DemoState(
        level: level,
        currentIndex: currentIndex ?? this.currentIndex,
        autoPlaying: autoPlaying ?? this.autoPlaying,
        autoPlayFast: autoPlayFast ?? this.autoPlayFast,
        completed: completed ?? this.completed,
        seenBefore: seenBefore ?? this.seenBefore,
        elapsedMs: elapsedMs ?? this.elapsedMs,
      );
}

/// 原理演示关控制器（`null` = 尚未加载）。
class DemoController extends Notifier<DemoState?> {
  Timer? _autoTimer;
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _completionRecorded = false;

  /// 当前自动播放速度档（`true` = 每秒两步）。
  bool _fastAutoPlay = false;

  @override
  DemoState? build() {
    ref.onDispose(stopAutoPlay);
    return null;
  }

  // ------------------------------------------------------------ 生命周期

  /// 加载并开始演示本关。
  Future<void> start(String levelId) async {
    stopAutoPlay();
    _completionRecorded = false;
    _startedAt = DateTime.now();
    final CurriculumRepository curriculum =
        ref.read(curriculumRepositoryProvider);
    final LessonLevel level = await curriculum.loadLevel(levelId);
    final ProgressRepository repo =
        await ref.read(progressRepositoryProvider.future);
    final ProgressState progress = await repo.load();
    final bool seenBefore =
        progress.levels[levelId]?.status == LevelStatus.completed;

    // 进入次数 +1（不改变三态与星数）。
    await ref.read(levelCompletionServiceProvider).recordEntry(levelId);

    final List<ScriptStep> steps = level.script?.steps ?? const <ScriptStep>[];
    // 防御：空脚本直接视为看完（避免死锁于「必须看完」）。
    final bool emptyFinished = steps.isEmpty;
    state = DemoState(
      level: level,
      currentIndex: 0,
      autoPlaying: false,
      completed: emptyFinished,
      seenBefore: seenBefore,
      elapsedMs: 0,
    );
    if (emptyFinished) {
      await _complete();
    }
  }

  // ------------------------------------------------------------ 播放控制

  /// 下一步（到达最后一步即算完成并写档）。
  Future<void> next() async {
    final DemoState? current = state;
    if (current == null || current.atEnd) {
      return;
    }
    final int nextIndex = current.currentIndex + 1;
    final bool reachedEnd = nextIndex >= current.stepCount - 1;
    // ⚠️ 先推进步骤，**不在写档前置 completed**：若提前置 true，用户
    // 看完最后一步立即返回，`_complete()` 的写档+invalidate 尚未执行，
    // 学习地图读到旧进度 → 下一关不解锁（用户实测 bug）。
    state = current.copyWith(
      currentIndex: nextIndex,
      elapsedMs: _elapsedNow(),
    );
    if (reachedEnd) {
      // 看完最后一步 → 停止自动播放并写档（hintUsed=0、errorCount=0）。
      // 写档完成（含 invalidate）后才置 completed=true（在 _complete 内）。
      stopAutoPlay();
      await _complete();
    }
  }

  /// 上一步（回看；不影响已完成状态）。
  void previous() {
    final DemoState? current = state;
    if (current == null || current.currentIndex <= 0) {
      return;
    }
    state = current.copyWith(
      currentIndex: current.currentIndex - 1,
      elapsedMs: _elapsedNow(),
    );
  }

  /// 从技巧进度条直接跳到指定步骤。
  ///
  /// 跳转会停止自动播放；跳到最后一步等同于已经观看到结尾并记录完成。
  Future<void> jumpTo(int index) async {
    DemoState? current = state;
    if (current == null || index < 0 || index >= current.stepCount) {
      return;
    }
    stopAutoPlay();
    current = state;
    if (current == null || current.currentIndex == index) {
      return;
    }
    state = current.copyWith(
      currentIndex: index,
      elapsedMs: _elapsedNow(),
    );
    if (index >= current.stepCount - 1) {
      await _complete();
    }
  }

  /// 重播：回到第 1 步并停止自动播放（本次重新观看，清除完成标记）。
  void replay() {
    final DemoState? current = state;
    if (current == null || current.stepCount == 0) {
      return;
    }
    stopAutoPlay();
    // 重播视为重新观看：允许再次看完后写档（否则 _complete 幂等拦截）。
    _completionRecorded = false;
    state = current.copyWith(
      currentIndex: 0,
      autoPlaying: false,
      completed: false,
      elapsedMs: _elapsedNow(),
    );
  }

  /// 切换自动播放（按当前速度档：2s/步 或 0.5s/步）。
  void toggleAutoPlay() {
    final DemoState? current = state;
    if (current == null || current.stepCount == 0) {
      return;
    }
    if (current.autoPlaying) {
      stopAutoPlay();
      return;
    }
    _autoTimer = Timer.periodic(
      _fastAutoPlay ? kDemoFastStepInterval : kDemoAutoStepInterval,
      (Timer timer) {
        // 逐步推进；到达最后一步后由 next() 内部停止。
        next();
      },
    );
    state = current.copyWith(
      autoPlaying: true,
      autoPlayFast: _fastAutoPlay,
      elapsedMs: _elapsedNow(),
    );
  }

  /// 切换自动播放速度（每 2 秒一步 ↔ 每秒两步）。
  ///
  /// 正在播放时立即以新速度重启；未播放时仅切换档位（下次启动生效）。
  void toggleSpeed() {
    _fastAutoPlay = !_fastAutoPlay;
    final DemoState? current = state;
    if (current == null) {
      return;
    }
    if (current.autoPlaying) {
      // 重启计时器以应用新速度。
      stopAutoPlay();
      toggleAutoPlay();
    } else {
      state = current.copyWith(autoPlayFast: _fastAutoPlay);
    }
  }

  /// 停止自动播放（幂等）。
  void stopAutoPlay() {
    _autoTimer?.cancel();
    _autoTimer = null;
    final DemoState? current = state;
    if (current != null && current.autoPlaying) {
      state = current.copyWith(autoPlaying: false, elapsedMs: _elapsedNow());
    }
  }

  // ------------------------------------------------------------ 内部

  /// 已看完最后一步 → 写档一次（幂等）。
  Future<void> _complete() async {
    if (_completionRecorded) {
      return;
    }
    final DemoState? current = state;
    if (current == null) {
      return;
    }
    _completionRecorded = true;
    try {
      await ref.read(levelCompletionServiceProvider).recordCompletion(
            levelId: current.level.id,
            durationMs: current.elapsedMs,
            hintUsed: 0,
            errorCount: 0,
          );
      // 写档后立即标记课程状态失效：返回学习地图时重载最新进度（解锁下一关）。
      ref.invalidate(curriculumStateProvider);
    } on Object {
      // 写档失败不阻塞演示（玩家不被卡死）：completed 仍置 true，
      // 但存档未写 → 下次进入仍须看完（seenBefore 读存档判定）。
    }
    state = current.copyWith(completed: true);
  }

  int _elapsedNow() => DateTime.now().difference(_startedAt).inMilliseconds;

  // ------------------------------------------------------------ 盘面装配

  /// 装配「播放到 [upToStep] 为止」的演示盘面快照。
  ///
  /// 顺序与 core `ScriptReplayer._applyStep` 一致：初始题面 recompute 候选 →
  /// 对每步先删后填（`eliminate` + `forceSetValue` + `syncAfterPlace`），
  /// 保证候选显示与脚本声明口径一致。给定格不改写、不重算。
  static Board boardAt(
    LessonLevel level,
    List<ScriptStep> steps,
    int upToStep,
  ) {
    final Board board = level.toLevelPuzzle().toCore().toGivenBoard();
    CandidateCalculator.recomputeAll(board);
    for (int i = 0; i <= upToStep && i < steps.length; i++) {
      final ScriptStep step = steps[i];
      for (final Elimination e in step.eliminations) {
        if (board.isBlank(e.cellIndex) &&
            board.candidatesAt(e.cellIndex).contains(e.digit)) {
          board.eliminate(e.cellIndex, e.digit);
        }
      }
      for (final Placement p in step.placements) {
        if (!board.isGiven(p.cellIndex)) {
          board.forceSetValue(p.cellIndex, p.digit);
          CandidateCalculator.syncAfterPlace(board, p.cellIndex, p.digit);
        }
      }
    }
    return board.snapshot();
  }
}
