/// 校验与冲突检测单测（doc 07 T-CORE-02）。
///
/// 口径说明（对齐 `Validator` 的文档契约，勿凭直觉改断言）：
/// - [Validator.isValidPlacement] **不考虑目标格自身的当前值**，
///   只看同行/列/宫的**其它格**；因此对一个已填 5 的格再问「能否填 5」答案是
///   `true`。要检测「已填格与邻居冲突」请用 [Validator.findConflicts]。
/// - [Validator.isConsistent] 允许空格存在，只要求无重复；
///   [Validator.isComplete] 才额外要求填满。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

/// 经典题面（0 表示空格）。
const String kPuzzle =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

/// [kPuzzle] 的唯一终局解。
const String kSolution =
    '534678912672195348198342567859761423426853791713924856961537284287419635345286179';

List<int> _valuesOf(String s81) =>
    <int>[for (int i = 0; i < s81.length; i++) int.parse(s81[i])];

void main() {
  group('Validator 终局解判定', () {
    test('合法终盘通过 isValidSolution', () {
      expect(Validator.isValidSolution(_valuesOf(kSolution)), isTrue);
    });

    test('长度错误 / 含 0 的列表不通过', () {
      expect(Validator.isValidSolution(<int>[1, 2, 3]), isFalse);
      // 全 1：长度对但每个单元都重复。
      expect(Validator.isValidSolution(List<int>.filled(kCellCount, 1)), isFalse);
      // 含 0（空格）不算终局解。
      final List<int> withBlank = _valuesOf(kSolution)..[40] = kEmptyValue;
      expect(Validator.isValidSolution(withBlank), isFalse);
    });

    test('单处数字被改坏即不再是合法终盘', () {
      final List<int> broken = _valuesOf(kSolution);
      // r1c1 原为 5，改成同行 r1c3 的 4 → 第 1 行出现两个 4。
      broken[0] = broken[2];
      expect(Validator.isValidSolution(broken), isFalse);
    });
  });

  group('Validator 冲突检测', () {
    test('同行重复数字被报告一次，且带正确单元信息', () {
      final Board board = Board.empty();
      board.forceSetValue(Coord.indexOf(0, 0), 5);
      board.forceSetValue(Coord.indexOf(0, 3), 5);

      final List<Conflict> conflicts = Validator.findConflicts(board);
      expect(conflicts, hasLength(1));
      final Conflict conflict = conflicts.single;
      expect(conflict.digit, equals(5));
      expect(conflict.indexA, equals(Coord.indexOf(0, 0)));
      expect(conflict.indexB, equals(Coord.indexOf(0, 3)));
      expect(conflict.unitType, equals(UnitType.row));
      expect(conflict.unitId, equals(0));
      expect(Validator.hasConflict(board), isTrue);
      expect(Validator.isConsistent(board), isFalse);
    });

    test('同宫同列重复会分别在各自单元各报一次', () {
      final Board board = Board.empty();
      // r1c1 与 r2c1：既同列 0，又同宫 0 → 列冲突 + 宫冲突共 2 条。
      board.forceSetValue(Coord.indexOf(0, 0), 7);
      board.forceSetValue(Coord.indexOf(1, 0), 7);

      final List<Conflict> conflicts = Validator.findConflicts(board);
      expect(conflicts, hasLength(2));
      expect(
        conflicts.map((Conflict c) => c.unitType).toSet(),
        equals(<UnitType>{UnitType.col, UnitType.box}),
      );
      expect(
        Validator.conflictCells(board),
        equals(<int>{Coord.indexOf(0, 0), Coord.indexOf(1, 0)}),
      );
    });

    test('无冲突题面 isConsistent 为 true 但未完成', () {
      final Board board = Board.fromPuzzleString(kPuzzle);
      expect(Validator.isConsistent(board), isTrue);
      expect(Validator.isComplete(board), isFalse);
      expect(() => Validator.requireConsistent(board), returnsNormally);
    });

    test('填满且无冲突的终盘 isComplete 为 true', () {
      final Board board = Board.fromValues(_valuesOf(kSolution));
      expect(Validator.isComplete(board), isTrue);
    });

    test('requireConsistent 对冲突盘面抛 E_BOARD_003', () {
      final Board board = Board.empty();
      board.forceSetValue(Coord.indexOf(4, 4), 9);
      board.forceSetValue(Coord.indexOf(4, 7), 9);
      expect(
        () => Validator.requireConsistent(board),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_003')),
      );
    });
  });

  group('Validator.isValidPlacement', () {
    late Board board;

    setUp(() => board = Board.fromPuzzleString(kPuzzle));

    test('空格：同行已有该数字 → 不可落子', () {
      // 第 1 行已有 5（r1c1），故空格 r1c3 不能再填 5。
      expect(Validator.isValidPlacement(board, Coord.indexOf(0, 2), 5), isFalse);
    });

    test('空格：同列 / 同宫已有该数字 → 不可落子', () {
      // 第 1 列已有 6（r2c1），空格 r3c1 不能填 6。
      expect(Validator.isValidPlacement(board, Coord.indexOf(2, 0), 6), isFalse);
      // 第 1 宫已有 9（r3c2），空格 r3c1 不能填 9。
      expect(Validator.isValidPlacement(board, Coord.indexOf(2, 0), 9), isFalse);
    });

    test('空格：三条单元线都没有该数字 → 可落子', () {
      // r1c3 所在行有 {5,3,7}、第 3 列有 {8}、第 1 宫有 {5,3,6,9,8}；填 1 合法。
      expect(Validator.isValidPlacement(board, Coord.indexOf(0, 2), 1), isTrue);
      // 与唯一终局解一致的落子必然合法。
      final List<int> solution = _valuesOf(kSolution);
      for (final int index in board.blankCells()) {
        expect(
          Validator.isValidPlacement(board, index, solution[index]),
          isTrue,
          reason: '终局解在 ${Coord.label(index)} 的取值应当总是合法落子',
        );
      }
    });

    test('契约：不考虑目标格自身当前值，重填同一数字仍算合法', () {
      // r1c1 本身就是 5，且同行/列/宫的**其它格**都没有 5 → 契约规定返回 true。
      expect(Validator.isValidPlacement(board, Coord.indexOf(0, 0), 5), isTrue);
      // 换成同宫其它格已有的 3 则不合法。
      expect(Validator.isValidPlacement(board, Coord.indexOf(0, 0), 3), isFalse);
    });

    test('isValidPlacementAt 与索引版等价', () {
      for (int row = 0; row < kBoardSize; row++) {
        for (int col = 0; col < kBoardSize; col++) {
          for (int digit = kMinDigit; digit <= kMaxDigit; digit++) {
            expect(
              Validator.isValidPlacementAt(board, row, col, digit),
              equals(
                Validator.isValidPlacement(board, Coord.indexOf(row, col), digit),
              ),
            );
          }
        }
      }
    });

    test('非法索引 / 非法数字抛 E_BOARD_005', () {
      expect(
        () => Validator.isValidPlacement(board, 81, 1),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_005')),
      );
      expect(
        () => Validator.isValidPlacement(board, 0, 0),
        throwsA(isA<CoreException>()
            .having((CoreException e) => e.code, 'code', 'E_BOARD_005')),
      );
    });
  });
}
