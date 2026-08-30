/// 验收试炼关控制器（T-EDU-05 / P0-EDU-06/07，S-05、C-06）。
///
/// 职责：
/// - 盘面从章节试炼池抽取（[PuzzleBankRepository.loadPool]，优先抽
///   「技巧标注包含本关目标技巧」的题；池缺失时回退关卡自带题面）；
/// - 顶部标明「本关需用到：XX 技巧」——来自试炼池 `targetTechniques`
///   与关卡 `techniqueTags` 的并集；
/// - **提示按钮置灰**（UI 层处理），本控制器不提供提示入口；
/// - **系统不校验玩家是否使用了目标技巧**（C-06），通关 = 完整解出整盘；
/// - **不限次数、不重置整关**：错误只计数、不 reset 盘面；
/// - **连续失败 3 次**弹出「回看本技巧原理演示」入口
///   （`showReviewOffer` + `reviewDemoLevelId`=同章第一个演示关）；
/// - 结算：整盘解出 → [LevelCompletionService.recordCompletion]
///   （hintUsed=0、errorCount=累计错误数）。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/core/core.dart';

import '../curriculum/curriculum_providers.dart';
import '../curriculum/curriculum_repository.dart';
import '../puzzle_bank/puzzle_bank_repository.dart';
import '../session/game_session.dart';
import '../session/game_session_controller.dart';
import '../session/session_providers.dart';
import '../settings/settings_controller.dart';
import '../storage/models/settings_models.dart';
import 'mistake_detector.dart';
import 'teaching_providers.dart';

/// 连续失败多少次后弹出「回看原理演示」入口（P0-EDU-07）。
const int kTrialFailuresBeforeReviewOffer = 3;

/// 验收试炼关不可变状态。
class TrialState {
  /// 构造试炼状态。
  TrialState({
    required this.level,
    required this.puzzle,
    required Set<TechniqueId> targetTechniques,
    this.consecutiveFailures = 0,
    this.showReviewOffer = false,
    this.reviewDemoLevelId,
    this.errorCount = 0,
    this.completed = false,
  }) : targetTechniques = Set<TechniqueId>.unmodifiable(targetTechniques);

  /// 本关数据（kind=trial）。
  final LessonLevel level;

  /// 从题池抽出的本局题目。
  final Puzzle puzzle;

  /// 顶部展示的目标技巧（题池标注 ∪ 关卡标签）。
  final Set<TechniqueId> targetTechniques;

  /// 连续失败次数（连续错误输入计数，正确输入归零）。
  final int consecutiveFailures;

  /// 是否已触发「回看原理演示」弹窗。
  final bool showReviewOffer;

  /// 回看的演示关 id（同章第一个 demo 关；找不到为 `null`）。
  final String? reviewDemoLevelId;

  /// 本关累计错误次数。
  final int errorCount;

  /// 是否已整盘解出并写档。
  final bool completed;

  /// 是否达到弹出回看入口的条件。
  bool get shouldOfferReview =>
      consecutiveFailures >= kTrialFailuresBeforeReviewOffer;

  /// 目标技巧中文名（顿号连接）。
  String get targetTechniqueLabel =>
      targetTechniques.map((TechniqueId t) => t.zhName).join('、');

  /// 返回替换部分字段后的副本。
  TrialState copyWith({
    int? consecutiveFailures,
    bool? showReviewOffer,
    String? reviewDemoLevelId,
    int? errorCount,
    bool? completed,
  }) =>
      TrialState(
        level: level,
        puzzle: puzzle,
        targetTechniques: targetTechniques,
        consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
        showReviewOffer: showReviewOffer ?? this.showReviewOffer,
        reviewDemoLevelId: reviewDemoLevelId ?? this.reviewDemoLevelId,
        errorCount: errorCount ?? this.errorCount,
        completed: completed ?? this.completed,
      );
}

/// 验收试炼关控制器（`null` = 尚未加载）。
class TrialController extends Notifier<TrialState?> {
  StreamSubscription<GameSessionEvent>? _gameSubscription;
  bool _completionRecorded = false;

  @override
  TrialState? build() {
    ref.onDispose(() {
      _gameSubscription?.cancel();
      _gameSubscription = null;
    });
    return null;
  }

  // ------------------------------------------------------------ 生命周期

  /// 开始本关：加载关卡 → 从题池抽题 → 注入对局状态机。
  Future<void> start(String levelId) async {
    _gameSubscription?.cancel();
    _completionRecorded = false;

    final CurriculumRepository curriculum =
        ref.read(curriculumRepositoryProvider);
    final LessonLevel level = await curriculum.loadLevel(levelId);
    final Puzzle puzzle = await _pickFromPool(level);
    final SettingsState settings =
        await ref.read(settingsControllerProvider.future);
    final GameSessionController gameCtrl =
        ref.read(gameSessionControllerProvider.notifier);
    await gameCtrl.startNew(
      difficulty: puzzle.difficulty ?? Difficulty.medium,
      puzzle: puzzle,
      settings: settings,
      clearFreePlaySnapshot: false,
    );

    // 目标技巧：题池标注 ∪ 关卡标签。
    final Set<TechniqueId> targets = <TechniqueId>{
      ...level.techniqueTags,
    };
    try {
      final TrialPool pool =
          await ref.read(puzzleBankRepositoryProvider).loadPool(level.chapter);
      targets.addAll(pool.targetTechniques);
    } on Object {
      // 池缺失不阻塞开局，仅用关卡标签。
    }

    final String? reviewDemoId = await _findReviewDemoLevel(level.id);

    ref.read(mistakeDetectorProvider).resetForLevel();
    await ref.read(levelCompletionServiceProvider).recordEntry(levelId);

    _gameSubscription = gameCtrl.events.listen((GameSessionEvent event) {
      if (event is GameCompletedEvent) {
        completeIfNeeded();
      }
    });

    state = TrialState(
      level: level,
      puzzle: puzzle,
      targetTechniques: targets,
      reviewDemoLevelId: reviewDemoId,
    );
  }

  // ------------------------------------------------------------ 输入（错误→失败计数）

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
      _recordFailureIfMistake(session, move);
      gameCtrl.toggleNote(digit);
    } else {
      _recordFailureIfMistake(session, Move.place(selected, digit));
      gameCtrl.inputDigit(digit);
    }
    _afterInput();
  }

  /// 切换指定数字的笔记。
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
    _recordFailureIfMistake(session, move);
    ref.read(gameSessionControllerProvider.notifier).toggleNote(digit);
    _afterInput();
  }

  /// 清除选中格。
  void handleClear() {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null) {
      return;
    }
    final int? selected = session.selectedIndex;
    if (selected == null || session.board.isGiven(selected)) {
      return;
    }
    _recordFailureIfMistake(session, Move.clear(selected));
    ref.read(gameSessionControllerProvider.notifier).clearCell();
    _afterInput();
  }

  /// 撤销（委托对局状态机；不重置失败计数）。
  void handleUndo() => ref.read(gameSessionControllerProvider.notifier).undo();

  /// 重做。
  void handleRedo() => ref.read(gameSessionControllerProvider.notifier).redo();

  /// 选中一格。
  void handleSelectCell(int index) =>
      ref.read(gameSessionControllerProvider.notifier).selectCell(index);

  /// 核对答案（试炼关可参考错误位置）。
  void handleCheckAnswer() =>
      ref.read(gameSessionControllerProvider.notifier).checkAnswer();

  /// 玩家选择「继续挑战」→ 收起回看入口并清零失败计数。
  void acknowledgeReviewOffer() {
    final TrialState? current = state;
    if (current != null) {
      state = current.copyWith(
        showReviewOffer: false,
        consecutiveFailures: 0,
      );
    }
  }

  // ------------------------------------------------------------ 完成

  /// 整盘解出即通关（C-06：不校验技巧使用），写档一次（幂等）。
  Future<void> completeIfNeeded() async {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    final TrialState? current = state;
    if (session == null || current == null || !session.isSolved) {
      return;
    }
    if (_completionRecorded) {
      return;
    }
    _completionRecorded = true;
    await ref.read(levelCompletionServiceProvider).recordCompletion(
          levelId: current.level.id,
          durationMs: session.elapsedMs,
          hintUsed: 0,
          errorCount: current.errorCount,
        );
    // 写档后立即标记课程状态失效：返回学习地图时重载最新进度（解锁下一关）。
    ref.invalidate(curriculumStateProvider);
    state = current.copyWith(completed: true);
  }

  // ------------------------------------------------------------ 内部

  /// 从题池抽题：优先技巧标注含目标技巧的题；池缺失/为空回退关卡题面。
  Future<Puzzle> _pickFromPool(LessonLevel level) async {
    final TrialPool pool;
    try {
      pool =
          await ref.read(puzzleBankRepositoryProvider).loadPool(level.chapter);
    } on Object {
      return level.toLevelPuzzle().toCore();
    }
    if (pool.puzzles.isEmpty) {
      return level.toLevelPuzzle().toCore();
    }
    for (final Puzzle p in pool.puzzles) {
      if (p.techniques.any(level.techniqueTags.contains)) {
        return p;
      }
    }
    return pool.puzzles.first;
  }

  /// 同章第一个演示关 id（回看入口；找不到返回 `null`）。
  Future<String?> _findReviewDemoLevel(String levelId) async {
    final LevelIndex index = await ref.read(curriculumIndexProvider.future);
    final LevelEntry? entry = index.byId(levelId);
    if (entry == null) {
      return null;
    }
    for (final LevelEntry e in index.allLevels) {
      if (e.chapter == entry.chapter && e.kind == LevelKind.demo) {
        return e.id;
      }
    }
    return null;
  }

  /// 检测输入：命中错误 → 失败计数 +1（到达阈值置 showReviewOffer）；
  /// 未命中错误 → 失败计数归零。试炼关不启用 (c) 抢先填数（C-06）。
  void _recordFailureIfMistake(GameSession session, Move move) {
    final MistakeDetector detector = ref.read(mistakeDetectorProvider);
    final MistakeEvent? event = detector.detect(
      move,
      MistakeContext(
        board: session.board,
        solution: session.solution,
        noteMode: session.noteMode,
        script: state?.level.script,
        targetTechniques: state?.level.techniqueTags ?? const <TechniqueId>{},
        enablePrematureFill: false,
      ),
    );
    final TrialState? current = state;
    if (current == null) {
      return;
    }
    if (event == null) {
      state = current.copyWith(consecutiveFailures: 0);
      return;
    }
    final int failures = current.consecutiveFailures + 1;
    state = current.copyWith(
      consecutiveFailures: failures,
      errorCount: current.errorCount + 1,
      showReviewOffer: current.showReviewOffer ||
          failures >= kTrialFailuresBeforeReviewOffer,
    );
  }

  /// 输入后检查是否已整盘解出。
  void _afterInput() {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session?.isSolved == true) {
      completeIfNeeded();
    }
  }
}
