/// 断点序列化服务 —— `GameSession` ↔ `SessionSnapshot` 双向转换
/// （P0-PRA-09 断点续玩，T-DOM-04）。
///
/// 还原策略：
/// 1. 由 `puzzle81 / givenMask81 / solution81` 重建 [Puzzle]（终局解缺失时
///    「核对/提示」降级，仍可续玩）；
/// 2. 由 `board81` 重建盘面值，再**依次重放 undo 栈的 Move**
///    （`MoveApplier.apply` 同时还原候选与回滚数据）；
/// 3. 重放结果与 `board81` 不一致（undo 栈被 100 深度裁剪等极端情况）
///    → 以断点盘面为准兜底：手动笔记用 `noteMasks`、自动候选走全量重算；
/// 4. redo 栈按「断点时刻遗留的重做候选」原样返回，由控制器以
///    pending 队列接管（UndoStack 内部 redo 栈由新的 undo 操作自然重建）。
library;

import 'package:sudoku_tutor/core/core.dart';

import '../domain_error.dart';
import '../storage/models/session_snapshot.dart';
import 'game_session.dart';

/// 断点还原产物（控制器据此重建对局）。
class RestoredSession {
  /// 构造还原产物。
  RestoredSession({
    required this.puzzle,
    required this.board,
    required this.undo,
    required this.redoMoves,
    required this.noteMasks,
    required this.noteMode,
    required this.autoCandidates,
    required this.autoNotesFilled,
    required this.elapsedMs,
    required this.difficulty,
  });

  /// 重建的题目。
  final Puzzle puzzle;

  /// 重放后的当前盘面（值 + givenMask + 候选均已还原）。
  final Board board;

  /// 已按 undo 栈 Move 填充的撤销栈（内部 redo 栈为空）。
  final UndoStack undo;

  /// 断点时刻遗留的重做候选（LIFO，栈顶为最近撤销）。
  final List<Move> redoMoves;

  /// 手动笔记掩码（81）。
  final List<int> noteMasks;

  /// 是否手动笔记模式。
  final bool noteMode;

  /// 自动候选开关。
  final bool autoCandidates;

  /// 是否由“自动笔记”一次性填入候选。
  final bool autoNotesFilled;

  /// 已用时长（毫秒）。
  final int elapsedMs;

  /// 难度档。
  final Difficulty difficulty;
}

/// 断点序列化服务。
abstract final class SessionSerializer {
  /// 对局 → 断点快照。
  static SessionSnapshot toSnapshot(
    GameSession session, {
    int savedAt = 0,
  }) {
    final List<int>? solution = session.solution;
    return SessionSnapshot(
      puzzle81: session.puzzle.givenString,
      board81: session.board.toPuzzleString(),
      elapsedMs: session.elapsedMs,
      noteMasks: session.noteMasks,
      undoStack: session.undoMoves,
      redoStack: session.redoMoves,
      difficultyId: session.difficulty.id,
      savedAt: savedAt,
      solution81: solution?.join(),
      givenMask81: session.board.toGivenMaskString(),
      noteMode: session.noteMode,
      autoCandidates: session.autoCandidates,
      autoNotesFilled: session.autoNotesFilled,
    );
  }

  /// 断点快照 → 可重建对局的状态。
  static RestoredSession restore(SessionSnapshot snapshot) {
    final Difficulty difficulty =
        Difficulty.tryParse(snapshot.difficultyId) ?? Difficulty.beginner;
    final Board given = Board.fromPuzzleString(
      snapshot.puzzle81,
      markGivens: false,
    );
    final List<bool> givenMask = _givenMaskOf(snapshot);
    final List<int>? solution = _solutionOf(snapshot);

    final Puzzle puzzle = Puzzle(
      given: given.toValueList(),
      solution: solution ?? _synthesizeSolution(given),
      givenMask: givenMask,
      difficulty: difficulty,
    );

    // 由题面初始态重建盘面（含 givenMask），再**依次重放 undo 栈**。
    // ⚠️ 不能从 board81 直接重建再重放：重放 place/clear 时盘面已被
    // board81 固化，`MoveApplier.canApply` 会判定幂等不可应用而返回 null，
    // 导致撤销栈还原失败、候选同步丢失。从初始态重放则每个 Move 都
    // 真实生效（候选由 MoveApplier 同步），撤销栈与盘面同步还原。
    final Board board = puzzle.toGivenBoard();
    if (snapshot.autoCandidates) {
      CandidateCalculator.recomputeAll(board);
    } else {
      board.clearAllCandidates();
    }
    final UndoStack undo = UndoStack();
    for (final Move move in snapshot.undoStack) {
      undo.push(board, move);
    }

    // 校验重放结果与断点盘面一致。
    if (board.toPuzzleString() != snapshot.board81) {
      // undo 栈被 100 深度裁剪：以断点盘面为准重建候选。
      final Board exact = Board.fromPuzzleString(
        snapshot.board81,
        markGivens: false,
      );
      for (int i = 0; i < kCellCount; i++) {
        exact.setGiven(i, givenMask[i]);
      }
      if (!snapshot.autoCandidates) {
        for (int i = 0; i < kCellCount; i++) {
          exact.candidateMasks[i] =
              i < snapshot.noteMasks.length ? snapshot.noteMasks[i] : 0;
        }
      } else {
        CandidateCalculator.recomputeAll(exact);
      }
      return RestoredSession(
        puzzle: puzzle,
        board: exact,
        undo: UndoStack(),
        redoMoves: const <Move>[],
        noteMasks: snapshot.noteMasks,
        noteMode: snapshot.noteMode,
        autoCandidates: snapshot.autoCandidates,
        autoNotesFilled: snapshot.autoNotesFilled,
        elapsedMs: snapshot.elapsedMs,
        difficulty: difficulty,
      );
    }

    if (!snapshot.autoCandidates) {
      for (int i = 0; i < kCellCount; i++) {
        board.candidateMasks[i] =
            i < snapshot.noteMasks.length ? snapshot.noteMasks[i] : 0;
      }
    }

    return RestoredSession(
      puzzle: puzzle,
      board: board,
      undo: undo,
      redoMoves: List<Move>.of(snapshot.redoStack),
      noteMasks: snapshot.noteMasks,
      noteMode: snapshot.noteMode,
      autoCandidates: snapshot.autoCandidates,
      autoNotesFilled: snapshot.autoNotesFilled,
      elapsedMs: snapshot.elapsedMs,
      difficulty: difficulty,
    );
  }

  /// 重建 givenMask（快照缺失时按非空推断）。
  static List<bool> _givenMaskOf(SessionSnapshot snapshot) {
    final String? raw = snapshot.givenMask81;
    if (raw != null && raw.length == kCellCount) {
      return <bool>[
        for (final String ch in raw.split('')) ch == '1',
      ];
    }
    final Board given = Board.fromPuzzleString(
      snapshot.puzzle81,
      markGivens: false,
    );
    return <bool>[for (final int v in given.values) v != kEmptyValue];
  }

  /// 重建终局解（缺失返回 `null`）。
  static List<int>? _solutionOf(SessionSnapshot snapshot) {
    final String? raw = snapshot.solution81;
    if (raw == null) {
      return null;
    }
    return <int>[for (final String ch in raw.split('')) int.parse(ch)];
  }

  /// 旧档无终局解时，用回溯求解器补全（旧档题面来自唯一解题库，
  /// 可唯一求解；求解失败抛 `E_IO_001` 而非构造出非法 Puzzle）。
  ///
  /// ⚠️ core 的 `Puzzle` 强制终局解为 81 位 `1..9`，不存在「空解」表达，
  /// 因此这里用求解兜底：续玩时「核对答案」仍可用（不再降级）。
  static List<int> _synthesizeSolution(Board given) {
    const BacktrackingSolver solver = BacktrackingSolver();
    final List<int>? solved = solver.solveFirst(given);
    if (solved == null) {
      throw AppError(
        'E_IO_001',
        '旧档缺少终局解且无法回溯求解，无法恢复本局',
      );
    }
    return solved;
  }
}
