/// 基础盘面与候选计算的琐碎单测（批次 A/B 冒烟，doc 07 T-QA-03）。
///
/// 这些测试只覆盖**不依赖随机**的纯函数路径，确保模型层编解码、givenMask
/// 携带与候选计算一致性正确；随机相关的生成/求解路径见 generator_test.dart。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

const String kSample =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

void main() {
  group('Board 编解码往返', () {
    test('fromPuzzleString -> toPuzzleString 稳定', () {
      final Board board = Board.fromPuzzleString(kSample);
      // toPuzzleString 默认空格字符为 '.'（kEmptyChar），需显式指定 '0' 才与 kSample 同形。
      expect(board.toPuzzleString(emptyChar: '0'), equals(kSample));
      expect(board.toPuzzleString(), equals(kSample.replaceAll('0', '.')));
    });

    test('非标准空格字符被正确归一并往返', () {
      // `_` 与 `*` 都是 Digit.parseChar 认可的空格字符，且不会被清洗正则剔除。
      for (final String blank in <String>['.', '_', '*']) {
        final Board board =
            Board.fromPuzzleString(kSample.replaceAll('0', blank));
        expect(board.toPuzzleString(emptyChar: '0'), equals(kSample));
      }
    });

    test('换行 / 竖线 / 短横等排版字符被清洗后仍可解析', () {
      // fromPuzzleString 会剔除 [\s|\-+]，便于直接粘贴多行带框的题面。
      final StringBuffer pretty = StringBuffer();
      for (int row = 0; row < kBoardSize; row++) {
        for (int col = 0; col < kBoardSize; col++) {
          pretty.write(kSample[row * kBoardSize + col]);
          if (col % 3 == 2 && col != kBoardSize - 1) {
            pretty.write('|');
          }
        }
        pretty.write('\n');
        if (row % 3 == 2 && row != kBoardSize - 1) {
          pretty.write('---+---+---\n');
        }
      }
      final Board board = Board.fromPuzzleString(pretty.toString());
      expect(board.toPuzzleString(emptyChar: '0'), equals(kSample));
    });

    test('长度非 81 抛 E_BOARD_001', () {
      expect(
        () => Board.fromPuzzleString('123'),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_001')),
      );
    });

    test('非法字符抛 E_BOARD_002', () {
      expect(
        () => Board.fromPuzzleString('X' * kCellCount),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_002')),
      );
    });
  });

  group('givenMask 全链路携带', () {
    test('fromPuzzleString 默认按非空标记给定格', () {
      final Board board = Board.fromPuzzleString(kSample);
      expect(board.givenCount(), equals(30));
      for (int i = 0; i < kCellCount; i++) {
        expect(board.isGiven(i), equals(board.valueAt(i) != kEmptyValue));
      }
    });

    test('给定格不可被 place/clear 修改（E_BOARD_004）', () {
      final Board board = Board.fromPuzzleString(kSample);
      final int givenIndex = board.givenMask.indexWhere((bool g) => g);
      expect(
        () => board.place(givenIndex, 4),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_004')),
      );
      expect(
        () => board.clear(givenIndex),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_004')),
      );
    });

    test('Puzzle 自动固化 givenMask 与指纹', () {
      final Puzzle puzzle = Puzzle(
        given: Board.fromPuzzleString(kSample).toValueList(),
        solution: List<int>.generate(kCellCount, (int i) => (i % 9) + 1),
      );
      expect(puzzle.givenCount, equals(30));
      expect(puzzle.givenMask.length, equals(kCellCount));
      expect(puzzle.fingerprint, isNotEmpty);
      // 同题面指纹稳定
      final Puzzle same = Puzzle(
        given: Board.fromPuzzleString(kSample).toValueList(),
        solution: List<int>.generate(kCellCount, (int i) => (i % 9) + 1),
      );
      expect(same.fingerprint, equals(puzzle.fingerprint));
    });
  });

  group('候选计算一致性', () {
    test('recomputeAll 后无不一致格', () {
      final Board board = Board.fromPuzzleString(kSample);
      CandidateCalculator.recomputeAll(board);
      expect(CandidateCalculator.findInconsistentCells(board), isEmpty);
    });

    test('填数后 syncAfterPlace 与全量重算逐格一致', () {
      final Board board = Board.fromPuzzleString(kSample);
      CandidateCalculator.recomputeAll(board);
      // 找一个空格填数
      final int blank = board.blankCells().first;
      final int digit = board.candidatesAt(blank).digits().first;
      board.place(blank, digit);
      CandidateCalculator.syncAfterPlace(board, blank, digit);
      expect(CandidateCalculator.findInconsistentCells(board), isEmpty);
    });

    test('清除后 syncAfterClear 与全量重算逐格一致', () {
      final Board board = Board.fromPuzzleString(kSample);
      CandidateCalculator.recomputeAll(board);
      final int blank = board.blankCells().first;
      final int digit = board.candidatesAt(blank).digits().first;
      board.place(blank, digit);
      CandidateCalculator.syncAfterPlace(board, blank, digit);
      board.clear(blank);
      CandidateCalculator.syncAfterClear(board, blank);
      expect(CandidateCalculator.findInconsistentCells(board), isEmpty);
    });
  });

  group('peer 几何', () {
    test('每格恰有 20 个 peer', () {
      for (int i = 0; i < kCellCount; i++) {
        expect(Peers.peersOf(i).length, equals(20));
      }
    });

    test('同行/列/宫可见，自身不可见', () {
      expect(Peers.sees(0, 1), isTrue); // r1c1 与 r1c2：同行
      expect(Peers.sees(0, 9), isTrue); // r1c1 与 r2c1：同列
      expect(Peers.sees(0, 10), isTrue); // r1c1 与 r2c2：同宫
      expect(Peers.sees(0, 8), isTrue); // r1c1 与 r1c9：仍是同行
      expect(Peers.sees(0, 0), isFalse); // 自身不算 peer
      // r1c1 与 r2c4：不同行、不同列、不同宫
      expect(Peers.sees(Coord.indexOf(0, 0), Coord.indexOf(1, 3)), isFalse);
      // r1c1 与 r9c9：对角远端
      expect(Peers.sees(Coord.indexOf(0, 0), Coord.indexOf(8, 8)), isFalse);
    });
  });
}
