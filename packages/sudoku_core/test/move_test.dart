/// 操作应用 / 撤销栈单测（doc 07 T-CORE-04）。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

const String kEmptySample =
    '.................................................................................';

void main() {
  group('Move 值对象与序列化', () {
    test('工厂构造与 label', () {
      expect(Move.place(40, 7).label, equals('r5c5 填数 7'));
      expect(Move.clear(40).label, equals('r5c5 清除'));
      expect(Move.addCandidate(40, 3).label, equals('r5c5 标记候选 3'));
      expect(Move.autoFillCandidates().label, equals('自动填写候选'));
    });

    test('clear 的 digit 必须为 0', () {
      expect(
        () => Move(type: MoveType.clear, cellIndex: 0, digit: 5),
        throwsA(isA<CoreException>()),
      );
    });

    test('toJson / fromJson 往返', () {
      for (final Move move in <Move>[
        Move.place(40, 7),
        Move.clear(40),
        Move.addCandidate(40, 3),
        Move.removeCandidate(40, 2),
        Move.autoFillCandidates(),
      ]) {
        final Move back = Move.fromJson(move.toJson());
        expect(back, equals(move));
      }
    });

    test('未知类型反序列化抛 E_IMPORT_001', () {
      expect(
        () => Move.fromJson(<String, Object?>{'type': 'nope', 'cellIndex': 0}),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_IMPORT_001')),
      );
    });
  });

  group('MoveApplier', () {
    test('place 后本格值更新且候选清空', () {
      final Board board = Board.fromPuzzleString(kEmptySample);
      CandidateCalculator.recomputeAll(board);
      final MoveRecord record = MoveApplier.apply(board, Move.place(40, 7));
      expect(board.valueAt(40), equals(7));
      expect(board.candidatesAt(40).isEmpty, isTrue);
      // 回滚
      MoveApplier.revert(board, record);
      expect(board.valueAt(40), equals(kEmptyValue));
    });

    test('对给定格应用抛 E_BOARD_004', () {
      final Board board = Board.fromPuzzleString(
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      );
      final int given = board.givenMask.indexWhere((bool g) => g);
      expect(
        () => MoveApplier.apply(board, Move.place(given, 1)),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_004')),
      );
    });

    test('canApply 幂等操作判否', () {
      final Board board = Board.fromPuzzleString(kEmptySample);
      CandidateCalculator.recomputeAll(board);
      expect(MoveApplier.canApply(board, Move.place(40, 7)), isTrue);
      MoveApplier.apply(board, Move.place(40, 7));
      // 已填 7，再次填 7 视为幂等不可应用
      expect(MoveApplier.canApply(board, Move.place(40, 7)), isFalse);
    });
  });

  group('UndoStack', () {
    test('push / undo / redo 精确回滚', () {
      final Board board = Board.fromPuzzleString(kEmptySample);
      CandidateCalculator.recomputeAll(board);
      final UndoStack stack = UndoStack();

      final MoveRecord? r1 = stack.push(board, Move.place(40, 7));
      expect(r1, isNotNull);
      expect(board.valueAt(40), equals(7));
      expect(stack.canUndo, isTrue);
      expect(stack.undoCount, equals(1));

      final MoveRecord? r2 = stack.push(board, Move.place(41, 8));
      expect(r2, isNotNull);
      expect(board.valueAt(41), equals(8));

      // 撤销两步
      stack.undo(board);
      expect(board.valueAt(41), equals(kEmptyValue));
      stack.undo(board);
      expect(board.valueAt(40), equals(kEmptyValue));
      expect(stack.canUndo, isFalse);
      expect(stack.canRedo, isTrue);
      expect(
        stack.redoHistory().map((MoveRecord record) => record.move.cellIndex),
        equals(<int>[41, 40]),
        reason: '重做历史应保持栈内顺序，末尾为下一步重做',
      );

      // 重做
      stack.redo(board);
      expect(board.valueAt(40), equals(7));
      expect(stack.redoHistory(), hasLength(1));
      stack.clearRedo();
      expect(stack.canRedo, isFalse);
    });

    test('自动填写候选作为一个原子节点，可一次撤销并重做', () {
      final Board board = Board.fromPuzzleString(
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      );
      board.clearAllCandidates();
      final int preservedCell = board.blankCells().first;
      board.addCandidate(preservedCell, 9);
      final List<int> before = List<int>.of(board.candidateMasks);
      final UndoStack stack = UndoStack();

      stack.push(board, Move.autoFillCandidates());
      expect(stack.undoCount, 1);
      expect(CandidateCalculator.isConsistent(board), isTrue);

      stack.undo(board);
      expect(board.candidateMasks, before, reason: '一次撤销应精确恢复点击前候选');
      expect(stack.redoCount, 1);

      stack.redo(board);
      expect(CandidateCalculator.isConsistent(board), isTrue);
      expect(stack.undoCount, 1);
    });

    test('深度超限淘汰最早记录', () {
      final Board board = Board.fromPuzzleString(kEmptySample);
      CandidateCalculator.recomputeAll(board);
      final UndoStack stack = UndoStack(depth: 2);
      for (int i = 0; i < 5; i++) {
        stack.push(board, Move.place(i, (i % 9) + 1));
      }
      expect(stack.undoCount, equals(2));
    });

    test('resetGame 回到题面初态并重算候选', () {
      final Board board = Board.fromPuzzleString(
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      );
      CandidateCalculator.recomputeAll(board);
      final UndoStack stack = UndoStack();
      // 在一个空格填数再撤销栈重置
      final int blank = board.blankCells().first;
      stack.push(
          board, Move.place(blank, board.candidatesAt(blank).digits().first));
      stack.resetGame(board);
      expect(board.valueAt(blank), equals(kEmptyValue));
      expect(CandidateCalculator.isConsistent(board), isTrue);
      expect(stack.undoCount, equals(0));
    });
  });
}
