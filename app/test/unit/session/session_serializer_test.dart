/// T-DOM-04 · 断点序列化往返一致测试（P0-PRA-09）。
///
/// 覆盖：`SessionSnapshot` JSON 往返、`GameSession → toSnapshot → restore`
/// 盘面/候选/笔记/撤销栈逐项一致；无 solution 旧档降级可续玩。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/session_serializer.dart';
import 'package:sudoku_tutor/domain/storage/models/session_snapshot.dart';

/// 测试用唯一解题（取自题库 easy 档第 10 题）。
final Puzzle testPuzzle = Puzzle(
  given: <int>[
    for (final String ch
        in '59.43..8...3..97....6....4..649.7..82798....18.5..3..7..8.25...731.....5.5.......'
            .split(''))
      ch == '.' ? 0 : int.parse(ch),
  ],
  solution: <int>[
    for (final String ch
        in '597432186483169752126578349364917528279856431815243967948725613731684295652391874'
            .split(''))
      int.parse(ch),
  ],
);

/// 构造一个含已填数 + 手动笔记 + 撤销栈的对局。
GameSession buildSession({bool noteMode = false, int elapsedMs = 60000}) {
  final Board board = testPuzzle.toGivenBoard();
  CandidateCalculator.recomputeAll(board);
  final UndoStack undo = UndoStack();
  final List<int> blanks = board.blankCells();
  final int fillCell = blanks[0];
  final int noteCell = blanks[1];
  // 填一格 + 给另一格记一个笔记。
  undo.push(board, Move.place(fillCell, 1));
  undo.push(board, Move.addCandidate(noteCell, 3));
  return GameSession(
    puzzle: testPuzzle,
    board: board.snapshot(),
    difficulty: Difficulty.medium,
    noteMasks: <int>[...board.candidateMasks],
    noteMode: noteMode,
    autoCandidates: !noteMode,
    selectedIndex: null,
    errorCells: const <int>{4},
    elapsedMs: elapsedMs,
    paused: false,
    completed: false,
    wrongCount: 2,
    correctCount: 3,
    usedHints: 1,
    markErrors: true,
    highlightSameDigit: true,
    undoMoves: <Move>[
      for (final MoveRecord r in undo.history()) r.move,
    ],
  );
}

void main() {
  test('SessionSnapshot JSON 序列化往返一致', () {
    final GameSession session = buildSession();
    final SessionSnapshot snapshot = SessionSerializer.toSnapshot(
      session,
      savedAt: 123456,
    );

    // 自定义字段。
    expect(snapshot.puzzle81, testPuzzle.givenString);
    expect(snapshot.difficultyId, 'medium');
    expect(snapshot.savedAt, 123456);
    expect(snapshot.solution81, testPuzzle.solutionString);
    expect(snapshot.noteMode, isFalse);
    expect(snapshot.autoCandidates, isTrue);

    final SessionSnapshot decoded = SessionSnapshot.fromJson(snapshot.toJson());
    expect(decoded.puzzle81, snapshot.puzzle81);
    expect(decoded.board81, snapshot.board81);
    expect(decoded.elapsedMs, snapshot.elapsedMs);
    expect(decoded.noteMasks, snapshot.noteMasks);
    expect(decoded.difficultyId, snapshot.difficultyId);
    expect(decoded.savedAt, snapshot.savedAt);
    expect(decoded.solution81, snapshot.solution81);
    expect(decoded.givenMask81, snapshot.givenMask81);
    expect(decoded.noteMode, snapshot.noteMode);
    expect(decoded.autoCandidates, snapshot.autoCandidates);
    // Move 列表逐项一致。
    expect(decoded.undoStack.length, snapshot.undoStack.length);
    for (int i = 0; i < snapshot.undoStack.length; i++) {
      expect(decoded.undoStack[i], snapshot.undoStack[i]);
    }
  });

  test('toSnapshot → restore：盘面/候选/笔记/撤销栈一致', () {
    final GameSession session = buildSession(noteMode: true, elapsedMs: 5000);
    final SessionSnapshot snapshot = SessionSerializer.toSnapshot(session);

    final RestoredSession restored = SessionSerializer.restore(snapshot);
    // 盘面值一致。
    expect(restored.board.toPuzzleString(), session.board.toPuzzleString());
    // givenMask 一致。
    expect(
        restored.board.toGivenMaskString(), session.board.toGivenMaskString());
    // 候选逐格一致（重放撤销栈还原）。
    for (int i = 0; i < 81; i++) {
      expect(
        restored.board.candidateMasks[i],
        session.board.candidateMasks[i],
        reason: '格 $i 候选应一致',
      );
    }
    // 笔记掩码一致。
    expect(restored.noteMasks, session.noteMasks);
    // 时间与难度一致。
    expect(restored.elapsedMs, session.elapsedMs);
    expect(restored.difficulty, session.difficulty);
    // 撤销能力：restored 的 undo 栈非空且可撤销。
    expect(restored.undo.canUndo, isTrue);
  });

  test('restore 后重放栈与原始栈行为一致（撤销一步盘面同步）', () {
    final GameSession session = buildSession();
    final SessionSnapshot snapshot = SessionSerializer.toSnapshot(session);
    final RestoredSession restored = SessionSerializer.restore(snapshot);

    // 原始会话对应的 board：当前盘面 = 撤销栈应用后的结果。
    final Board replay = testPuzzle.toGivenBoard();
    CandidateCalculator.recomputeAll(replay);
    for (final Move move in snapshot.undoStack) {
      MoveApplier.apply(replay, move);
    }
    expect(restored.board.toPuzzleString(), replay.toPuzzleString());

    // restored 撤销一步后与「原始盘面少一步」一致。
    restored.undo.undo(restored.board);
    final Board replayAfterUndo = testPuzzle.toGivenBoard();
    CandidateCalculator.recomputeAll(replayAfterUndo);
    final List<Move> moves =
        snapshot.undoStack.sublist(0, snapshot.undoStack.length - 1);
    for (final Move move in moves) {
      MoveApplier.apply(replayAfterUndo, move);
    }
    expect(restored.board.toPuzzleString(), replayAfterUndo.toPuzzleString());
  });

  test('无终局解的旧档（solution81 缺失）可续玩（回溯补全终局解）', () {
    final SessionSnapshot legacy = SessionSnapshot(
      puzzle81: testPuzzle.givenString,
      board81: testPuzzle.givenString,
      elapsedMs: 1000,
      difficultyId: 'beginner',
    );
    final RestoredSession restored = SessionSerializer.restore(legacy);
    // core 的 Puzzle 强制 81 位终局解，旧档缺 solution81 时由回溯求解补全，
    // 因此核对答案仍可用（不再降级）。
    expect(
      restored.puzzle.solution,
      testPuzzle.solution,
      reason: '旧档无终局解时回溯补全唯一解',
    );
    expect(restored.board.toPuzzleString(), testPuzzle.givenString);
    // 仍可继续对局（盘面可用）。
    expect(restored.undo.canUndo, isFalse);
  });
}
