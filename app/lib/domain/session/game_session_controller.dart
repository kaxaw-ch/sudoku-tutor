/// 对局状态机控制器（P0-PRA-02~09，T-DOM-04）。
///
/// 职责：在 `sudoku_core` 的 `Board / Move / UndoStack` 之上驱动一局
/// 自由练习的全部玩法规则，并向 UI 发布不可变的 [GameSession]。
///
/// 关键设计：
/// - **候选单一事实源 = `Board.candidateMasks`**：自动候选模式由
///   `MoveApplier` 自动同步；手动笔记模式用 `Move.addCandidate /
///   removeCandidate` 编辑同一掩码；一次性自动笔记作为整盘原子 Move，
///   三者全部入撤销栈（撤销/重做天然覆盖笔记）；
/// - **自动候选与手动笔记互斥**：开启自动候选（或退出笔记模式且
///   autoCandidates=true）时全量重算候选（清空手动笔记），并广播
///   [AutoSwitchClearedNotesEvent] 供 UI 弹窗提示；
/// - **redo 栈双轨**：正常对局用 `UndoStack` 内部 redo；断点恢复后
///   遗留的重做候选由 `_pendingRedo` 队列接管（二者不冲突，
///   UndoStack 内部 redo 由新的 undo 自然重建，详见 SessionSerializer）；
/// - **退出自动保存**：`saveSnapshot()` 写入 `SessionSnapshot`
///   （题面/盘面/笔记/用时/撤销栈/重做栈/难度/终局解），支持续玩；
/// - **自由练习不支持多局并存**：自由练习 `startNew` 覆盖旧断点；
///   教学关复用状态机时保留自由练习断点，并使用独立的教学盘面快照。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/core/core.dart';

import '../storage/models/settings_models.dart';
import '../storage/progress_repository.dart';
import '../storage/models/session_snapshot.dart';
import 'check_answer_service.dart';
import 'game_session.dart';
import 'session_providers.dart';
import 'session_serializer.dart';
import 'timer_service.dart';

/// 对局事件（UI 层订阅，用于弹窗提示等交互反馈）。
sealed class GameSessionEvent {
  /// 构造事件。
  const GameSessionEvent();
}

/// 切回自动候选时清空了手动笔记（UI 层弹窗提示「已清空手动笔记」）。
class AutoSwitchClearedNotesEvent extends GameSessionEvent {
  /// 构造事件；[clearedCount] 为被清空的笔记个数（0 表示重算而非逐个清）。
  const AutoSwitchClearedNotesEvent(this.clearedCount);

  /// 被清空的笔记个数。
  final int clearedCount;
}

/// 本局已完整解出。
class GameCompletedEvent extends GameSessionEvent {
  /// 构造事件。
  const GameCompletedEvent();
}

/// 盘面填满后自动核验未通过。
class GameAutoCheckFailedEvent extends GameSessionEvent {
  /// 构造事件。
  const GameAutoCheckFailedEvent(this.wrongCount);

  /// 本次自动核验发现的错误格数量。
  final int wrongCount;
}

/// 断点已保存。
class SessionSavedEvent extends GameSessionEvent {
  /// 构造事件。
  const SessionSavedEvent();
}

/// 对局控制器（Riverpod `Notifier<GameSession?>`；`null` = 无对局）。
class GameSessionController extends Notifier<GameSession?> {
  // ------------------------------------------------------------ 内部状态

  Puzzle? _puzzle;
  Board? _board;
  UndoStack? _undo;
  Difficulty _difficulty = Difficulty.beginner;
  bool _noteMode = false;
  bool _autoCandidates = false;
  bool _autoNotesFilled = false;
  bool _markErrors = true;
  bool _highlightSameDigit = true;
  bool _recordStats = true;
  int? _selected;
  Set<int> _errorCells = <int>{};
  int _wrongCount = 0;
  int _correctCount = 0;
  int _usedHints = 0;
  bool _completed = false;

  /// 断点恢复后遗留的重做候选（LIFO）。
  List<Move> _pendingRedo = <Move>[];

  late final TimerService _timer = TimerService();

  final StreamController<GameSessionEvent> _events =
      StreamController<GameSessionEvent>.broadcast(sync: true);

  /// 对局事件流（UI 订阅）。
  Stream<GameSessionEvent> get events => _events.stream;

  /// 对局计时服务（UI 显示/暂停遮挡消费）。
  TimerService get timer => _timer;

  @override
  GameSession? build() {
    // 计时服务独立运行；按“显示秒”变化主动发布状态，避免 UI 只能在下一次
    // 点击或输入导致页面重建时才看到新时间。200ms 内部节拍仍用于准确累计，
    // 页面最多每秒重建一次。
    final StreamSubscription<int> timerSubscription =
        _timer.elapsedStream.listen(_handleTimerElapsed);
    // Provider 销毁时释放资源：取消周期计时器、关闭事件流。
    // ⚠️ 缺失会导致 flutter_test 报「Timer still pending」& 事件流泄漏。
    ref.onDispose(() {
      unawaited(timerSubscription.cancel());
      _timer.dispose();
      _events.close();
    });
    return null;
  }

  // ------------------------------------------------------------ 局生命周期

  /// 开始一局新对局（覆盖式，UI 层须先二次确认）。
  Future<void> startNew({
    required Difficulty difficulty,
    required Puzzle puzzle,
    required SettingsState settings,
    bool clearFreePlaySnapshot = true,
    bool recordStats = true,
  }) async {
    final Board board = puzzle.toGivenBoard();
    if (settings.autoCandidates) {
      CandidateCalculator.recomputeAll(board);
    } else {
      board.clearAllCandidates();
    }
    _puzzle = puzzle;
    _board = board;
    _undo = UndoStack();
    _difficulty = difficulty;
    _noteMode = false;
    _autoCandidates = settings.autoCandidates;
    _autoNotesFilled = false;
    _markErrors = settings.markErrors;
    _highlightSameDigit = settings.highlightSameDigit;
    _recordStats = recordStats;
    _selected = null;
    _errorCells = <int>{};
    _wrongCount = 0;
    _correctCount = 0;
    _usedHints = 0;
    _completed = false;
    _pendingRedo = <Move>[];
    _timer.reset();
    _timer.start();
    _publish();
    // 自由练习新局会覆盖自由练习断点；教学关复用状态机时不应清除它。
    if (clearFreePlaySnapshot) {
      final ProgressRepository repo = await _repository();
      await repo.clearSession();
    }
  }

  /// 若有断点则恢复续玩；返回是否成功恢复。
  Future<bool> restoreIfAny({required SettingsState settings}) async {
    final ProgressRepository repo = await _repository();
    final SessionSnapshot? snapshot = await repo.loadSession();
    if (snapshot == null) {
      return false;
    }
    restoreFromSnapshot(snapshot: snapshot, settings: settings);
    return true;
  }

  /// 从指定快照恢复运行时状态，不读写任何存档文件。
  ///
  /// 教学关用轻量盘面快照调用本方法，其撤销/重做栈为空，因此恢复后
  /// 只能从当前盘面继续，不会还原之前的操作过程。
  void restoreFromSnapshot({
    required SessionSnapshot snapshot,
    required SettingsState settings,
  }) {
    final RestoredSession restored = SessionSerializer.restore(snapshot);
    _puzzle = restored.puzzle;
    _board = restored.board;
    _undo = restored.undo;
    _difficulty = restored.difficulty;
    _noteMode = restored.noteMode;
    _autoCandidates = restored.autoCandidates;
    _autoNotesFilled = restored.autoNotesFilled;
    _markErrors = settings.markErrors;
    _highlightSameDigit = settings.highlightSameDigit;
    _recordStats = true;
    _selected = null;
    _errorCells = <int>{};
    _wrongCount = 0;
    _correctCount = 0;
    _usedHints = 0;
    _completed = false;
    _pendingRedo = restored.redoMoves;
    _timer.reset(elapsedMs: restored.elapsedMs);
    _timer.start();
    _refreshErrorCells();
    _publish();
  }

  /// 保存断点（退出自由练习时，P0-PRA-09）。
  Future<void> saveSnapshot() async {
    if (_board == null) {
      return;
    }
    _timer.pause();
    _publish();
    final GameSession current = state!;
    final SessionSnapshot snapshot = SessionSerializer.toSnapshot(
      current,
      savedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    final ProgressRepository repo = await _repository();
    await repo.saveSession(snapshot);
    _events.add(const SessionSavedEvent());
  }

  /// 放弃当前对局并清除断点（UI 层「重新开始/退出」用）。
  Future<void> discardSession({bool clearSavedSnapshot = true}) async {
    _timer.pause();
    _timer.reset();
    if (clearSavedSnapshot) {
      final ProgressRepository repo = await _repository();
      await repo.clearSession();
    }
    _board = null;
    _puzzle = null;
    _undo = null;
    _pendingRedo = <Move>[];
    _selected = null;
    state = null;
  }

  // ------------------------------------------------------------ 输入

  /// 选中一格（`null` = 取消选中）。
  void selectCell(int? index) {
    if (index != null && index >= 0 && index < kCellCount) {
      _selected = index;
    } else {
      _selected = null;
    }
    _publish();
  }

  /// 输入一个数字：笔记模式下记为笔记，否则填数。
  void inputDigit(int digit) {
    if (_noteMode) {
      toggleNote(digit);
      return;
    }
    final int? selected = _selected;
    final Board? board = _board;
    if (selected == null || board == null || board.isGiven(selected)) {
      return;
    }
    if (!_applyMove(Move.place(selected, digit))) {
      return;
    }
    _updateErrorOnFill(selected, digit);
    _maybeComplete();
    _publish();
  }

  /// 切换一格的手动笔记（有则删、无则加）。
  void toggleNote(int digit) {
    final int? selected = _selected;
    final Board? board = _board;
    if (selected == null || board == null) {
      return;
    }
    if (board.isGiven(selected) || board.isFilled(selected)) {
      return;
    }
    final Move move = board.candidatesAt(selected).contains(digit)
        ? Move.removeCandidate(selected, digit)
        : Move.addCandidate(selected, digit);
    if (_applyMove(move)) {
      _publish();
    }
  }

  /// 清空选中格的填数。
  void clearCell() {
    final int? selected = _selected;
    final Board? board = _board;
    if (selected == null || board == null || board.isGiven(selected)) {
      return;
    }
    if (!board.isFilled(selected) && board.candidatesAt(selected).mask == 0) {
      return; // 无可清除内容（幂等，不入栈）。
    }
    if (board.isFilled(selected)) {
      if (!_applyMove(Move.clear(selected))) {
        return;
      }
      _errorCells.remove(selected);
    } else {
      // 只清空该格候选（含手动笔记）。
      final int mask = board.candidatesAt(selected).mask;
      for (int d = 1; d <= 9; d++) {
        if ((mask & (1 << (d - 1))) != 0) {
          _applyMove(Move.removeCandidate(selected, d));
        }
      }
    }
    _maybeComplete();
    _publish();
  }

  /// 切换笔记模式（主路径：笔记模式键）。
  void toggleNoteMode() {
    _noteMode = !_noteMode;
    if (_noteMode) {
      _autoNotesFilled = false;
    }
    // 退出笔记模式且自动候选开启 → 清空手动笔记并重算候选。
    if (!_noteMode && _autoCandidates) {
      _clearNotesForAuto();
    }
    _publish();
  }

  /// 全局设置变化：开启/关闭自动候选（P0-PRA-07 互斥）。
  void setAutoCandidates(bool value) {
    if (_autoCandidates == value) {
      return;
    }
    _autoCandidates = value;
    _autoNotesFilled = false;
    if (value) {
      // 从手动笔记切回自动候选 → 退出笔记模式并清空手动笔记（互斥）。
      _noteMode = false;
      _clearNotesForAuto();
    } else if (!_noteMode) {
      _board?.clearAllCandidates();
    }
    _publish();
  }

  /// 一次性为当前盘面全部空格填写合法候选数，不改变全局自动候选设置。
  ///
  /// 填写后仍处于普通填数模式；用户可直接点数字落子，也可切换到笔记模式
  /// 手动删改候选。整次填写作为一个原子操作进入撤销栈，一次撤销即可恢复
  /// 点击前的全部候选；该状态会随断点保存并在续玩时恢复。
  void autoFillNotes() {
    final Board? board = _board;
    if (board == null) {
      return;
    }
    final bool applied = _applyMove(Move.autoFillCandidates());
    _noteMode = false;
    if (applied || CandidateCalculator.isConsistent(board)) {
      _autoNotesFilled = true;
    }
    _publish();
  }

  /// 撤销一步。
  void undo() {
    final Board? board = _board;
    final UndoStack? undo = _undo;
    if (board == null || undo == null || !undo.canUndo) {
      return;
    }
    final MoveRecord? record = undo.undo(board);
    if (record?.move.type == MoveType.autoFillCandidates) {
      _autoNotesFilled = false;
    }
    if (_autoCandidates || _autoNotesFilled) {
      CandidateCalculator.recomputeAll(board);
    }
    _refreshErrorCells();
    _publish();
  }

  /// 重做一步。
  void redo() {
    final Board? board = _board;
    final UndoStack? undo = _undo;
    if (board == null || undo == null) {
      return;
    }
    final bool hadCandidateMarks =
        board.candidateMasks.any((int mask) => mask != 0);
    final MoveRecord? record;
    if (undo.canRedo) {
      record = undo.redo(board);
    } else if (_pendingRedo.isNotEmpty) {
      final Move move = _pendingRedo.removeLast();
      record = undo.push(board, move);
    } else {
      return;
    }
    if (record == null) {
      return;
    }
    if (record.move.type == MoveType.autoFillCandidates) {
      _autoNotesFilled = true;
      _noteMode = false;
    }
    if (_autoCandidates || _autoNotesFilled) {
      CandidateCalculator.recomputeAll(board);
    } else if (!hadCandidateMarks) {
      board.clearAllCandidates();
    }
    _refreshErrorCells();
    _publish();
  }

  /// 重置本局：盘面回到题面初始态，撤销/重做栈清空（P0-PRA-02）。
  void resetRound() {
    final Board? board = _board;
    final UndoStack? undo = _undo;
    if (board == null || undo == null) {
      return;
    }
    undo.resetGame(board); // resetToGivens + 候选全量重算 + 清空两栈。
    _autoNotesFilled = false;
    if (!_autoCandidates) {
      board.clearAllCandidates();
    }
    _noteMode = false;
    _selected = null;
    _errorCells = <int>{};
    _pendingRedo = <Move>[];
    _wrongCount = 0;
    _correctCount = 0;
    _usedHints = 0;
    _completed = false;
    _timer.reset();
    _timer.start();
    _publish();
  }

  /// 核对答案：只标错、不纠正、不透露空格，并计入统计（P0-PRA-03）。
  CheckResult checkAnswer() {
    final Board? board = _board;
    if (board == null) {
      return const CheckResult(
        wrongCells: <int>{},
        correctCount: 0,
        wrongCount: 0,
      );
    }
    final List<int>? solution = _puzzle?.solution;
    final CheckResult result = CheckAnswerService.check(board, solution);
    _errorCells = result.wrongCells;
    _wrongCount += result.wrongCount;
    _correctCount = result.correctCount;
    _publish();
    return result;
  }

  /// 只暂停当前对局。
  ///
  /// 与 [togglePause] 分开，供生命周期通知调用。重复的 inactive / hidden
  /// 通知必须保持幂等，不能意外把已经暂停的对局恢复。
  void pause() {
    if (!_timer.isRunning) {
      return;
    }
    _timer.pause();
    _publish();
  }

  /// 只恢复当前对局；已完成的对局永远不能重新启动计时。
  void resume() {
    if (_completed || !_timer.isStarted || _timer.isRunning) {
      return;
    }
    _timer.start();
    _publish();
  }

  /// 手动切换暂停/恢复（UI 层暂停遮挡盘面）。
  void togglePause() {
    if (_timer.isRunning) {
      pause();
    } else {
      resume();
    }
  }

  /// 记录一次已消耗的提示（配额消费计数）。
  void markHintUsed() {
    _usedHints++;
    _publish();
  }

  // ------------------------------------------------------------ 内部

  /// 计时跨入新的一秒时发布快照，驱动计时 UI 无交互自动刷新。
  void _handleTimerElapsed(int elapsedMs) {
    final GameSession? current = state;
    if (_board == null ||
        current == null ||
        current.elapsedMs ~/ 1000 == elapsedMs ~/ 1000) {
      return;
    }
    _publish();
  }

  /// 读取存储仓储（Provider 装配）。
  Future<ProgressRepository> _repository() =>
      ref.read(progressRepositoryProvider.future);

  /// 应用一个 Move（入撤销栈、清遗留重做链）；返回是否成功。
  bool _applyMove(Move move) {
    final Board? board = _board;
    final UndoStack? undo = _undo;
    if (board == null || undo == null) {
      return false;
    }
    final bool hadCandidateMarks =
        board.candidateMasks.any((int mask) => mask != 0);
    final MoveRecord? record = undo.push(board, move);
    if (record == null) {
      return false;
    }
    if (move.type.changesValue &&
        !_autoCandidates &&
        !_autoNotesFilled &&
        !hadCandidateMarks) {
      board.clearAllCandidates();
    }
    _pendingRedo = <Move>[]; // 新操作使断点遗留重做链失效。
    return true;
  }

  /// 填数后的即时错误标红（只描边不填底；依据终局解）。
  void _updateErrorOnFill(int index, int digit) {
    if (!_markErrors) {
      _errorCells.remove(index);
      return;
    }
    final List<int>? solution = _puzzle?.solution;
    if (solution != null && solution.isNotEmpty && solution[index] != digit) {
      _errorCells.add(index);
    } else {
      _errorCells.remove(index);
    }
  }

  /// 撤销/重做后按当前盘面重建错误格，避免已撤回数字仍残留红框。
  void _refreshErrorCells() {
    final Board? board = _board;
    final List<int>? solution = _puzzle?.solution;
    if (!_markErrors || board == null || solution == null || solution.isEmpty) {
      _errorCells = <int>{};
      return;
    }
    _errorCells = <int>{
      for (int i = 0; i < kCellCount; i++)
        if (!board.isGiven(i) &&
            board.isFilled(i) &&
            board.valueAt(i) != solution[i])
          i,
    };
  }

  /// 盘面填满后自动核验：有错则全部标出；全部正确才完成。
  void _maybeComplete() {
    final Board? board = _board;
    if (board == null || !board.isFull || _completed) {
      return;
    }
    final List<int>? solution = _puzzle?.solution;
    if (solution != null && solution.isNotEmpty) {
      final CheckResult result = CheckAnswerService.check(board, solution);
      _errorCells = result.wrongCells;
      _correctCount = result.correctCount;
      if (result.wrongCount > 0) {
        _wrongCount += result.wrongCount;
        _events.add(GameAutoCheckFailedEvent(result.wrongCount));
        return;
      }
      if (Validator.isValidSolution(solution) &&
          result.correctCount == kCellCount) {
        _completed = true;
        _timer.pause();
        _events.add(const GameCompletedEvent());
      }
    } else {
      // 无终局解（旧断点降级）：填满即完成。
      if (Validator.isComplete(board)) {
        _completed = true;
        _timer.pause();
        _events.add(const GameCompletedEvent());
      }
    }
  }

  /// 切回自动候选：清空手动笔记 + 全量重算，并广播事件。
  void _clearNotesForAuto() {
    final Board? board = _board;
    if (board != null) {
      CandidateCalculator.recomputeAll(board);
    }
    _events.add(AutoSwitchClearedNotesEvent(0));
  }

  /// 把内部状态装配为不可变 [GameSession] 发布。
  void _publish() {
    final Puzzle? puzzle = _puzzle;
    final Board? board = _board;
    final UndoStack? undo = _undo;
    if (puzzle == null || board == null || undo == null) {
      state = null;
      return;
    }
    state = GameSession(
      puzzle: puzzle,
      board: board.snapshot(),
      difficulty: _difficulty,
      noteMasks: List<int>.of(board.candidateMasks),
      noteMode: _noteMode,
      autoCandidates: _autoCandidates,
      autoNotesFilled: _autoNotesFilled,
      selectedIndex: _selected,
      errorCells: Set<int>.of(_errorCells),
      elapsedMs: _timer.elapsedMs,
      // 计时器在通关后也会停止，但“已完成”不等于“用户暂停”。否则通关
      // 动画关闭后会错误地残留暂停遮罩，并允许重新启动已完成局的计时。
      paused: !_completed && _timer.isPaused,
      completed: _completed,
      wrongCount: _wrongCount,
      correctCount: _correctCount,
      usedHints: _usedHints,
      markErrors: _markErrors,
      highlightSameDigit: _highlightSameDigit,
      recordStats: _recordStats,
      undoMoves: <Move>[
        for (final MoveRecord record in undo.history()) record.move,
      ],
      // 恢复后的 pending 分支位于栈底；本轮 undo 产生的内部 redo 位于栈顶。
      redoMoves: <Move>[
        ..._pendingRedo,
        for (final MoveRecord record in undo.redoHistory()) record.move,
      ],
    );
  }
}
