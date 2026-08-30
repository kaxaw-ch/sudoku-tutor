/// 对局不可变状态 `GameSession`（P0-PRA-02~09，T-DOM-04）。
///
/// 一局自由练习的所有对外可见状态，全部字段 `final`；
/// [board] 为发布时刻的**深拷贝快照**（`Board.snapshot()`），
/// 保证「旧 state 一经发布即不再变化」的不可变语义。
library;

import 'package:sudoku_tutor/core/core.dart';

/// 一局对局的只读视图。
class GameSession {
  /// 构造对局视图（内部由 `GameSessionController` 装配）。
  const GameSession({
    required this.puzzle,
    required this.board,
    required this.difficulty,
    required this.noteMasks,
    required this.noteMode,
    required this.autoCandidates,
    this.autoNotesFilled = false,
    required this.selectedIndex,
    required this.errorCells,
    required this.elapsedMs,
    required this.paused,
    required this.completed,
    required this.wrongCount,
    required this.correctCount,
    required this.usedHints,
    required this.markErrors,
    required this.highlightSameDigit,
    this.undoMoves = const <Move>[],
    this.redoMoves = const <Move>[],
  });

  /// 题目（题面 + givenMask + 终局解 + 标注）。
  final Puzzle puzzle;

  /// 当前盘面快照（81 值 + givenMask + 候选掩码）。
  final Board board;

  /// 难度档。
  final Difficulty difficulty;

  /// 手动笔记掩码（81 位，`1 << (digit-1)`；0 = 无笔记）。
  final List<int> noteMasks;

  /// 是否处于笔记模式（手动笔记开关）。
  final bool noteMode;

  /// 自动候选数开关（与手动笔记互斥，P0-PRA-07）。
  final bool autoCandidates;

  /// 是否由用户点击“自动笔记”一次性填入了全盘合法候选。
  final bool autoNotesFilled;

  /// 当前选中格（`null` = 未选中）。
  final int? selectedIndex;

  /// 核对答案标记出的错误格（只描边不填底，P0-PRA-03）。
  final Set<int> errorCells;

  /// 已用时长（毫秒，仅自由练习计时）。
  final int elapsedMs;

  /// 是否手动暂停（暂停时 UI 遮挡盘面，P0-PRA-08）。
  final bool paused;

  /// 本局是否已完整解出。
  final bool completed;

  /// 累计错误次数（核对答案/即时冲突计入，P0-PRA-03 统计）。
  final int wrongCount;

  /// 累计正确次数。
  final int correctCount;

  /// 已用提示次数（配额消费计数）。
  final int usedHints;

  /// 错误标红开关（设置快照，P0-PRA-05）。
  final bool markErrors;

  /// 相同数字高亮开关（设置快照，P0-PRA-07）。
  final bool highlightSameDigit;

  /// 撤销栈的 Move 序列（由旧到新；断点序列化用，P0-PRA-09）。
  final List<Move> undoMoves;

  /// 重做栈的 Move 序列（由旧到新）。
  final List<Move> redoMoves;

  /// 终局解（可能为 `null`：导入的旧断点无 solution 时降级）。
  List<int>? get solution => puzzle.solution.isEmpty ? null : puzzle.solution;

  /// 某数字在全盘出现的次数（「已出现 9 次的数字置灰」用，P0-UI-04）。
  ///
  /// 含题面给定格与玩家已填格；返回 81 个数字 1..9 的计数表。
  List<int> digitCounts() {
    final List<int> counts = List<int>.filled(10, 0);
    for (int i = 0; i < kCellCount; i++) {
      final int v = board.values[i];
      if (v != kEmptyValue) {
        counts[v]++;
      }
    }
    return counts;
  }

  /// 某数字是否已出现 9 次（键盘置灰但仍可点）。
  bool digitFullyPlaced(int digit) {
    Digit.requireDigit(digit);
    return digitCounts()[digit] >= 9;
  }

  /// 是否已完成（盘面填满且与终局解一致）。
  bool get isSolved => completed || Validator.isComplete(board);

  /// 返回替换部分字段后的副本（快照 board 以保不可变语义）。
  GameSession copyWith({
    Board? board,
    List<int>? noteMasks,
    bool? noteMode,
    bool? autoCandidates,
    bool? autoNotesFilled,
    int? selectedIndex,
    Set<int>? errorCells,
    int? elapsedMs,
    bool? paused,
    bool? completed,
    int? wrongCount,
    int? correctCount,
    int? usedHints,
    bool? markErrors,
    bool? highlightSameDigit,
    List<Move>? undoMoves,
    List<Move>? redoMoves,
  }) =>
      GameSession(
        puzzle: puzzle,
        board: (board ?? this.board).snapshot(),
        difficulty: difficulty,
        noteMasks: noteMasks ?? this.noteMasks,
        noteMode: noteMode ?? this.noteMode,
        autoCandidates: autoCandidates ?? this.autoCandidates,
        autoNotesFilled: autoNotesFilled ?? this.autoNotesFilled,
        selectedIndex: selectedIndex,
        errorCells: errorCells ?? this.errorCells,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        paused: paused ?? this.paused,
        completed: completed ?? this.completed,
        wrongCount: wrongCount ?? this.wrongCount,
        correctCount: correctCount ?? this.correctCount,
        usedHints: usedHints ?? this.usedHints,
        markErrors: markErrors ?? this.markErrors,
        highlightSameDigit: highlightSameDigit ?? this.highlightSameDigit,
        undoMoves: undoMoves ?? this.undoMoves,
        redoMoves: redoMoves ?? this.redoMoves,
      );
}
