/// 引导实操关控制器（T-EDU-03 / P0-EDU-04，S-04）+ 误操作挂接（T-EDU-04）。
///
/// 职责：
/// - 复用自由练习的对局状态机（[GameSessionController]）承载盘面与输入；
/// - **三级提示必须逐级解锁**：复用 [HintService]（scope=teaching，最多三级），
///   服务内部逐级推进不可跳级；任何级别都不直出「某格填几」（HintState 无 Placement）；
/// - **次数不限、不扣分、不消耗资源**：配额传 `HintQuota.unlimited`；
/// - **已用级别保留可回看**：`unlockedHints` 保存全部已解锁提示历史；
/// - **误操作即时纠正**（T-EDU-04）：每次输入经 [MistakeDetector.detect]，
///   命中后发布 [PracticeState.lastMistake] 供 UI 弹窗（2 分钟去重在检测器内）；
/// - 完成：整盘解出 → [LevelCompletionService.recordCompletion]
///   （hintUsed=已用提示次数、errorCount=误操作次数）。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/core/core.dart';

import '../curriculum/curriculum_providers.dart';
import '../curriculum/curriculum_repository.dart';
import '../hint/hint_level.dart';
import '../hint/hint_providers.dart';
import '../hint/hint_service.dart';
import '../hint/hint_state.dart';
import '../session/game_session.dart';
import '../session/game_session_controller.dart';
import '../session/session_providers.dart';
import '../settings/settings_controller.dart';
import '../storage/models/settings_models.dart';
import '../storage/models/teaching_session_snapshot.dart';
import '../storage/progress_repository.dart';
import 'mistake_detector.dart';
import 'teaching_providers.dart';

/// 引导实操关不可变状态。
class PracticeState {
  /// 构造实操状态。
  PracticeState({
    required this.level,
    List<HintState> unlockedHints = const <HintState>[],
    this.currentHint,
    this.lastMistake,
    this.hintUsed = 0,
    this.errorCount = 0,
    this.completed = false,
    this.resumed = false,
  }) : unlockedHints = List<HintState>.unmodifiable(unlockedHints);

  /// 本关数据。
  final LessonLevel level;

  /// 已解锁的全部提示（按级别升序，回看历史）。
  final List<HintState> unlockedHints;

  /// 当前提示（最近一次解锁；面板高亮）。
  final HintState? currentHint;

  /// 最近一次误操作事件（UI 弹窗；弹后须 acknowledge 清除）。
  final MistakeEvent? lastMistake;

  /// 本关已用提示次数。
  final int hintUsed;

  /// 本关误操作次数。
  final int errorCount;

  /// 是否已整盘解出并写档。
  final bool completed;

  /// 是否从本关上次保存的盘面恢复。
  final bool resumed;

  /// 返回替换部分字段后的副本。
  PracticeState copyWith({
    List<HintState>? unlockedHints,
    HintState? currentHint,
    MistakeEvent? lastMistake,
    bool clearMistake = false,
    int? hintUsed,
    int? errorCount,
    bool? completed,
    bool? resumed,
  }) =>
      PracticeState(
        level: level,
        unlockedHints: unlockedHints ?? this.unlockedHints,
        currentHint: currentHint ?? this.currentHint,
        lastMistake: clearMistake ? null : (lastMistake ?? this.lastMistake),
        hintUsed: hintUsed ?? this.hintUsed,
        errorCount: errorCount ?? this.errorCount,
        completed: completed ?? this.completed,
        resumed: resumed ?? this.resumed,
      );
}

/// 引导实操关控制器（`null` = 尚未加载）。
class PracticeController extends Notifier<PracticeState?> {
  StreamSubscription<GameSessionEvent>? _gameSubscription;
  bool _completionRecorded = false;
  bool _disposed = false;
  ProgressRepository? _repository;
  Future<void> _autosaveChain = Future<void>.value();

  @override
  PracticeState? build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _gameSubscription?.cancel();
      _gameSubscription = null;
    });
    return null;
  }

  // ------------------------------------------------------------ 生命周期

  /// 开始本关（加载关卡 → 注入对局状态机 → 重置提示与检测器）。
  Future<void> start(String levelId) async {
    await _autosaveChain;
    _gameSubscription?.cancel();
    _completionRecorded = false;
    ref.read(hintServiceProvider).resetForNewRound();

    final CurriculumRepository curriculum =
        ref.read(curriculumRepositoryProvider);
    final LessonLevel level = await curriculum.loadLevel(levelId);
    final Puzzle puzzle = level.toLevelPuzzle().toCore();
    final SettingsState settings =
        await ref.read(settingsControllerProvider.future);
    final GameSessionController gameCtrl =
        ref.read(gameSessionControllerProvider.notifier);
    final ProgressRepository repository =
        await ref.read(progressRepositoryProvider.future);
    _repository = repository;
    final TeachingSessionSnapshot? saved =
        await repository.loadTeachingSession(levelId);
    bool resumed = false;
    if (saved != null && saved.matches(puzzle)) {
      try {
        gameCtrl.restoreFromSnapshot(
          snapshot: saved.toSessionSnapshot(puzzle),
          settings: settings,
        );
        resumed = true;
      } on Object {
        // 损坏的单关断点只影响本关，清除后从题面重新开始。
        await repository.clearTeachingSession(levelId);
      }
    } else if (saved != null) {
      await repository.clearTeachingSession(levelId);
    }
    if (!resumed) {
      await gameCtrl.startNew(
        difficulty: puzzle.difficulty ?? Difficulty.medium,
        puzzle: puzzle,
        settings: settings,
        clearFreePlaySnapshot: false,
      );
    }

    ref.read(mistakeDetectorProvider).resetForLevel();
    await ref.read(levelCompletionServiceProvider).recordEntry(levelId);

    // 整盘解出 → 写档。
    _gameSubscription = gameCtrl.events.listen((GameSessionEvent event) {
      if (event is GameCompletedEvent) {
        completeIfNeeded();
      }
    });

    state = PracticeState(
      level: level,
      hintUsed: resumed ? saved!.hintUsed : 0,
      errorCount: resumed ? saved!.errorCount : 0,
      resumed: resumed,
    );
  }

  // ------------------------------------------------------------ 提示（三级逐级解锁）

  /// 请求下一级提示（教学 scope 最多三级，逐级解锁由 HintService 保证）。
  ///
  /// 返回 `null` 表示无可用提示 / 已解锁满；成功则计入已用次数并保留历史。
  Future<HintState?> requestHint() async {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    final PracticeState? current = state;
    if (session == null || current == null || session.completed) {
      return null;
    }
    final HintService service = ref.read(hintServiceProvider);
    final HintState? hint = await service.requestNext(
      board: session.board,
      solution: session.solution,
      scope: HintScope.teaching,
      quota: HintQuota.unlimited,
    );
    if (hint == null) {
      return null;
    }
    final bool sceneChanged = current.currentHint != null &&
        current.currentHint!.sceneFingerprint != hint.sceneFingerprint;
    state = current.copyWith(
      unlockedHints: sceneChanged
          ? <HintState>[hint]
          : <HintState>[...current.unlockedHints, hint],
      currentHint: hint,
      hintUsed: current.hintUsed + 1,
    );
    _queueAutosave();
    return hint;
  }

  // ------------------------------------------------------------ 输入（误操作挂接）

  /// 输入一个数字：笔记模式下为笔记切换，否则填数。
  void handleDigit(int digit) {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null) {
      return;
    }
    final int? selected = session.selectedIndex;
    if (selected == null || session.board.isGiven(selected)) {
      return;
    }
    final GameSessionController gameCtrl =
        ref.read(gameSessionControllerProvider.notifier);
    if (session.noteMode) {
      final Move move = session.board.candidatesAt(selected).contains(digit)
          ? Move.removeCandidate(selected, digit)
          : Move.addCandidate(selected, digit);
      _detectMove(session, move);
      gameCtrl.toggleNote(digit);
    } else {
      _detectMove(session, Move.place(selected, digit));
      gameCtrl.inputDigit(digit);
    }
    _afterInput();
  }

  /// 切换指定数字的笔记（长按辅助路径）。
  void handleToggleNote(int digit) {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null) {
      return;
    }
    final int? selected = session.selectedIndex;
    if (selected == null || session.board.isGiven(selected)) {
      return;
    }
    final Move move = session.board.candidatesAt(selected).contains(digit)
        ? Move.removeCandidate(selected, digit)
        : Move.addCandidate(selected, digit);
    _detectMove(session, move);
    ref.read(gameSessionControllerProvider.notifier).toggleNote(digit);
    _afterInput();
  }

  /// 清除选中格（填数或候选）。
  void handleClear() {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null) {
      return;
    }
    final int? selected = session.selectedIndex;
    if (selected == null || session.board.isGiven(selected)) {
      return;
    }
    _detectMove(session, Move.clear(selected));
    ref.read(gameSessionControllerProvider.notifier).clearCell();
    _afterInput();
  }

  /// 撤销（委托对局状态机；撤销属于修正，不检测）。
  void handleUndo() {
    ref.read(gameSessionControllerProvider.notifier).undo();
    _queueAutosave();
  }

  /// 重做（委托对局状态机）。
  void handleRedo() {
    ref.read(gameSessionControllerProvider.notifier).redo();
    _queueAutosave();
  }

  /// 切换笔记模式并保存当前状态。
  void handleToggleNoteMode() {
    ref.read(gameSessionControllerProvider.notifier).toggleNoteMode();
    _queueAutosave();
  }

  /// 一次性填写自动笔记并保存当前状态。
  void handleAutoNotes() {
    ref.read(gameSessionControllerProvider.notifier).autoFillNotes();
    _queueAutosave();
  }

  /// 选中一格（委托对局状态机）。
  void handleSelectCell(int index) =>
      ref.read(gameSessionControllerProvider.notifier).selectCell(index);

  /// 核对答案（只标错不纠正；供实操关参考，错误以弹窗纠正为主）。
  void handleCheckAnswer() =>
      ref.read(gameSessionControllerProvider.notifier).checkAnswer();

  /// 弹窗已展示 → 清除最近误操作标记（避免每次 build 重复弹）。
  void acknowledgeMistake() {
    final PracticeState? current = state;
    if (current != null && current.lastMistake != null) {
      state = current.copyWith(clearMistake: true);
    }
  }

  // ------------------------------------------------------------ 完成

  /// 整盘解出 → 写档（幂等；hintUsed/errorCount 真实采集）。
  Future<void> completeIfNeeded() async {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    final PracticeState? current = state;
    if (session == null || current == null || !session.isSolved) {
      return;
    }
    if (_completionRecorded) {
      return;
    }
    _completionRecorded = true;
    final ProgressRepository? repository = _repository;
    await ref.read(levelCompletionServiceProvider).recordCompletion(
          levelId: current.level.id,
          durationMs: session.elapsedMs,
          hintUsed: current.hintUsed,
          errorCount: current.errorCount,
        );
    await _autosaveChain;
    await repository?.clearTeachingSession(current.level.id);
    if (_disposed) {
      return;
    }
    // 写档后立即标记课程状态失效：返回学习地图时重载最新进度（解锁下一关）。
    ref.invalidate(curriculumStateProvider);
    state = current.copyWith(completed: true);
  }

  // ------------------------------------------------------------ 内部

  /// 检测一次输入并发布误操作事件（2 分钟去重在检测器内）。
  void _detectMove(GameSession session, Move move) {
    final MistakeDetector detector = ref.read(mistakeDetectorProvider);
    final MistakeEvent? event = detector.detect(
      move,
      MistakeContext(
        board: session.board,
        solution: session.solution,
        noteMode: session.noteMode,
        script: state?.level.script,
        targetTechniques: state?.level.techniqueTags ?? const <TechniqueId>{},
      ),
    );
    if (event == null) {
      return;
    }
    final PracticeState? current = state;
    if (current != null) {
      state = current.copyWith(
        lastMistake: event,
        errorCount: current.errorCount + 1,
      );
    }
  }

  /// 输入后检查是否已整盘解出。
  void _afterInput() {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session?.isSolved == true) {
      unawaited(completeIfNeeded());
    } else {
      _queueAutosave();
    }
  }

  /// 等待已排队的自动保存并立即再保存一次，供页面退出/生命周期暂停调用。
  Future<void> saveNow() async {
    await _autosaveChain;
    await _writeSnapshot();
  }

  /// 串行化文件写入，避免连续点按造成旧快照覆盖新快照。
  void _queueAutosave() {
    _autosaveChain = _autosaveChain.then((_) => _writeSnapshot()).catchError(
      (Object _, StackTrace __) {
        // 后台自动保存失败不打断做题；显式退出时 saveNow 会重新尝试并上抛。
      },
    );
  }

  Future<void> _writeSnapshot() async {
    if (_disposed) {
      return;
    }
    final PracticeState? current = state;
    final GameSession? session = ref.read(gameSessionControllerProvider);
    final ProgressRepository? repository = _repository;
    if (current == null ||
        current.completed ||
        session == null ||
        repository == null) {
      return;
    }
    final TeachingSessionSnapshot snapshot = TeachingSessionSnapshot(
      levelId: current.level.id,
      puzzle81: session.puzzle.givenString,
      board81: session.board.toPuzzleString(),
      elapsedMs: session.elapsedMs,
      noteMasks: List<int>.of(session.noteMasks),
      noteMode: session.noteMode,
      autoCandidates: session.autoCandidates,
      autoNotesFilled: session.autoNotesFilled,
      hintUsed: current.hintUsed,
      errorCount: current.errorCount,
      savedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await repository.saveTeachingSession(snapshot);
  }
}
