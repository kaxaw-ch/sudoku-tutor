/// 棋盘测试共享辅助（T-UI-02）。
library;

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';

/// 测试用唯一解题（取自题库 easy 档第 10 题；格 0 = 5，含 3×3 候选微排布样例）。
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

/// 构造一个含若干已填数、可选选中/错误/笔记的对局。
GameSession buildSession({
  int? selectedIndex,
  Set<int> errorCells = const <int>{},
  bool noteMode = false,
  bool markErrors = true,
  bool highlightSameDigit = true,
}) {
  final Board board = testPuzzle.toGivenBoard();
  CandidateCalculator.recomputeAll(board);
  final List<int> blanks = board.blankCells();
  if (blanks.length >= 2) {
    board.place(blanks[0], 1);
    board.place(blanks[1], 2);
  }
  if (noteMode && blanks.length >= 3) {
    board.addCandidate(blanks[2], 3);
  }
  CandidateCalculator.recomputeAll(board);
  return GameSession(
    puzzle: testPuzzle,
    board: board.snapshot(),
    difficulty: Difficulty.medium,
    noteMasks: List<int>.of(board.candidateMasks),
    noteMode: noteMode,
    autoCandidates: !noteMode,
    selectedIndex: selectedIndex,
    errorCells: errorCells,
    elapsedMs: 0,
    paused: false,
    completed: false,
    wrongCount: 0,
    correctCount: 0,
    usedHints: 0,
    markErrors: markErrors,
    highlightSameDigit: highlightSameDigit,
  );
}

/// 装配渲染数据。
BoardViewModel buildViewModel({
  int? selectedIndex,
  Set<int> errorCells = const <int>{},
  bool noteMode = false,
  bool markErrors = true,
  bool highlightSameDigit = true,
  VisualHint? hintVisual,
}) =>
    BoardViewModel.fromSession(
      buildSession(
        selectedIndex: selectedIndex,
        errorCells: errorCells,
        noteMode: noteMode,
        markErrors: markErrors,
        highlightSameDigit: highlightSameDigit,
      ),
      hintVisual: hintVisual,
    );
