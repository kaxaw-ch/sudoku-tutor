/// 撤销/重做栈（深度 100）+ 重置本局（P0-ENG-05）。
///
/// 语义约定：
/// - 每次 [UndoStack.push] 应用一个 [Move] 并压入撤销栈，**同时清空重做栈**
///   （标准编辑器语义：产生新分支后旧的重做链失效）；
/// - 撤销栈超过 [kUndoDepth] 时丢弃**最早**的一条（先进先出淘汰）；
/// - [UndoStack.resetGame] 把盘面恢复到题面初始态并清空两个栈。
library;

import '../model/board.dart';
import 'candidate_calculator.dart';
import 'move.dart';
import 'move_applier.dart';

/// 撤销栈深度上限（PRD P0-ENG-05）。
const int kUndoDepth = 100;

/// 撤销/重做栈。
///
/// 本类只管理历史，不持有盘面；盘面由调用方传入，便于跨 Isolate 场景下
/// 由业务层决定盘面的所有权。
class UndoStack {
  /// 构造一个空栈；[depth] 仅供测试调小，生产一律用默认 [kUndoDepth]。
  UndoStack({this.depth = kUndoDepth}) : assert(depth > 0, 'depth 必须为正数');

  /// 深度上限。
  final int depth;

  final List<MoveRecord> _undo = <MoveRecord>[];
  final List<MoveRecord> _redo = <MoveRecord>[];

  /// 当前可撤销的步数。
  int get undoCount => _undo.length;

  /// 当前可重做的步数。
  int get redoCount => _redo.length;

  /// 是否可以撤销。
  bool get canUndo => _undo.isNotEmpty;

  /// 是否可以重做。
  bool get canRedo => _redo.isNotEmpty;

  /// 撤销栈中最近一条记录；栈空返回 `null`。
  MoveRecord? get lastRecord => _undo.isEmpty ? null : _undo.last;

  /// 只读的历史视图（由旧到新）。
  List<MoveRecord> history() => List<MoveRecord>.unmodifiable(_undo);

  /// 只读的重做历史（栈顶在列表末尾）。
  List<MoveRecord> redoHistory() => List<MoveRecord>.unmodifiable(_redo);

  /// 应用一个操作并入栈。
  ///
  /// 返回本次应用产生的回滚记录；若 [move] 在当前盘面上无效
  /// （见 `MoveApplier.canApply`），**不改动盘面也不入栈**并返回 `null`。
  MoveRecord? push(Board board, Move move) {
    if (!MoveApplier.canApply(board, move)) {
      return null;
    }
    final MoveRecord record = MoveApplier.apply(board, move);
    _undo.add(record);
    _redo.clear();
    _trim();
    return record;
  }

  /// 撤销一步；无可撤销时返回 `null`。
  MoveRecord? undo(Board board) {
    if (_undo.isEmpty) {
      return null;
    }
    final MoveRecord record = _undo.removeLast();
    MoveApplier.revert(board, record);
    _redo.add(record);
    return record;
  }

  /// 重做一步；无可重做时返回 `null`。
  MoveRecord? redo(Board board) {
    if (_redo.isEmpty) {
      return null;
    }
    final MoveRecord pending = _redo.removeLast();
    final MoveRecord record = MoveApplier.reapply(board, pending.move);
    _undo.add(record);
    _trim();
    return record;
  }

  /// 连续撤销 [steps] 步，返回实际撤销的步数。
  int undoAll(Board board, {int? steps}) {
    final int target = steps ?? _undo.length;
    int done = 0;
    while (done < target && _undo.isNotEmpty) {
      undo(board);
      done++;
    }
    return done;
  }

  /// 重置本局：盘面回到题面初始态、候选全量重算、两栈清空。
  ///
  /// 注意：`Board.resetToGivens` 只清非给定格的值与全部候选，
  /// 因此必须紧跟一次 [CandidateCalculator.recomputeAll] 才是合法初始态。
  void resetGame(Board board) {
    board.resetToGivens();
    CandidateCalculator.recomputeAll(board);
    clear();
  }

  /// 清空撤销与重做栈（不改动盘面）。
  void clear() {
    _undo.clear();
    _redo.clear();
  }

  /// 仅清空重做分支，保留当前盘面与撤销历史。
  void clearRedo() => _redo.clear();

  /// 裁剪超出深度上限的最早记录。
  void _trim() {
    while (_undo.length > depth) {
      _undo.removeAt(0);
    }
  }

  @override
  String toString() => 'UndoStack(undo=${_undo.length}, redo=${_redo.length}, '
      'depth=$depth)';
}
