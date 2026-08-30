/// 撤销/重做快照完整性与 100 步上限（批次 B，doc 07 T-CORE-05）。
///
/// 目标：
///  1) 连续操作后 undo 必须精确回到初始态，redo 必须逐态回到对应快照；
///  2) 撤销栈深度不超过 kUndoDepth=100，超出后 FIFO 淘汰最早记录。
///
/// ⚠️ 静态约束：本文件不在当前沙箱执行（无 Flutter/Dart SDK），
/// 由 CI 在客户端运行；详见 `docs/08-QA批次A+B审查.md` §8 验证清单。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

/// 在 [board] 上构造一个"必然改变盘面"的合法 [Move]（避开给定格与幂等操作）。
///
/// 返回 null 表示该格当前无法构造有效移动（理论上不会发生）。
Move? _nextMove(Rng rng, Board board) {
  final int cell = rng.nextInt(kCellCount);
  if (board.isGiven(cell)) {
    return null;
  }
  if (board.isBlank(cell)) {
    int digit = 0;
    for (int d = 1; d <= 9; d++) {
      if ((board.candidateMasks[cell] & (1 << (d - 1))) != 0) {
        digit = d;
        break;
      }
    }
    if (digit == 0) {
      return null;
    }
    return Move.place(cell, digit);
  } else {
    return Move.clear(cell);
  }
}

void main() {
  group('undo/redo 往返一致', () {
    test('50 步操作后 undo 回初始、redo 回各中间态', () {
      final Rng rng = Rng(987654);
      final Board initial = PuzzleGenerator().generateBoard(
        rng,
        targetGivens: 36,
      );
      final Board board = initial.snapshot();
      final UndoStack stack = UndoStack();

      final List<Board> snapshots = <Board>[];
      int applied = 0;
      while (applied < 50) {
        final Move? move = _nextMove(rng, board);
        if (move == null) {
          continue;
        }
        final MoveRecord? record = stack.push(board, move);
        if (record == null) {
          continue; // canApply 未通过，跳过
        }
        snapshots.add(board.snapshot());
        applied++;
      }
      expect(snapshots.length, equals(50),
          reason: '应成功应用 50 步'); // sanity

      // 撤销全部，应回到初始态。
      stack.undoAll(board);
      expect(board, equals(initial), reason: '撤销后应回到初始态');
      expect(stack.canRedo, isTrue);

      // 逐步重做，每步都应等于当时的快照。
      for (int i = 0; i < snapshots.length; i++) {
        stack.redo(board);
        expect(board, equals(snapshots[i]),
            reason: '第 $i 步重做后应等于其快照');
      }
    });

    test('kUndoDepth=100：超出后淘汰最早记录', () {
      final Rng rng = Rng(111222);
      final Board initial = PuzzleGenerator().generateBoard(
        rng,
        targetGivens: 40,
      );
      final Board board = initial.snapshot();
      final UndoStack stack = UndoStack();

      // 先应用 50 步，记录该时刻盘面（最早保留记录的"前一态"）。
      int applied = 0;
      while (applied < 50) {
        final Move? move = _nextMove(rng, board);
        if (move == null || stack.push(board, move) == null) {
          continue;
        }
        applied++;
      }
      final Board after50 = board.snapshot();

      // 再追加 100 步，使总步数远超 100。
      int extra = 0;
      while (extra < 100) {
        final Move? move = _nextMove(rng, board);
        if (move == null || stack.push(board, move) == null) {
          continue;
        }
        extra++;
      }

      // 撤销栈深度不超过 100。
      expect(stack.undoCount, lessThanOrEqualTo(kUndoDepth),
          reason: '撤销栈深度应不超过 kUndoDepth');

      // 撤销全部后应回到"应用 50 步后"的盘面（最早的 50 步已被淘汰）。
      stack.undoAll(board);
      expect(board, equals(after50),
          reason: '超出上限后最早记录被淘汰，撤销应停在保留记录之前');
    });
  });
}
