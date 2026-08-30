/// T-DOM-03 · 文本导入服务测试（P0-PRA-10）。
///
/// 覆盖：合法题导入成功（唯一解）、长度非法 / 非法字符 / 初始自相矛盾
/// → `E_IMPORT_001`；多解 → `E_IMPORT_002`；无解 → `E_IMPORT_001`；
/// 剪贴板多行/竖线/空格容错。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_import_service.dart';

/// 同步唯一解校验器（测试注入，避免 Isolate 开销）。
Future<(int, List<int>?)> syncChecker(List<int> values) async {
  final Board board = Board.fromValues(values);
  const BacktrackingSolver solver = BacktrackingSolver();
  final int count = solver.countSolutions(board, stopAt: 2);
  final List<int>? solution = count == 1 ? solver.solveFirst(board) : null;
  return (count, solution);
}

void main() {
  // 一道真实唯一解题（取自 assets/puzzles/medium.json.gz）。
  const String validPuzzle =
      '........66...98......4..58.....4.9.2.1....83....6.3..58..7......72.6.39.3.9..4...';
  const String validSolution =
      '958371246624598173731426589583147962416952837297683415845739621172865394369214758';

  /// 多解盘面：全空 81 格。
  const String multiSolutionPuzzle =
      '.................................................................................';

  /// 无解盘面：(0,8) 为死格（候选空）但无行/列/宫冲突。
  const String noSolutionPuzzle = '98765432.'
      '........1'
      '.................................................................';

  late PuzzleImportService service;

  setUp(() {
    service = PuzzleImportService(checker: syncChecker);
  });

  test('合法唯一解题导入成功，带回完整终局解与 givenMask', () async {
    final Puzzle puzzle = await service.import(validPuzzle);
    expect(puzzle.givenString, validPuzzle);
    expect(puzzle.solutionString, validSolution);
    expect(puzzle.givenCount, greaterThan(0));
    // 非空格全部固化为给定格。
    expect(puzzle.givenMask.length, 81);
    for (int i = 0; i < 81; i++) {
      if (validPuzzle[i] != '.') {
        expect(puzzle.givenMask[i], isTrue, reason: '格 $i 应为给定');
      }
    }
  });

  test('剪贴板多行 / 竖线 / 空格容错', () async {
    // 把合法题拆成三行并插入竖线与空格。
    final String messy =
        '${validPuzzle.substring(0, 27)} | ${validPuzzle.substring(27, 54)}\n'
        '${validPuzzle.substring(54)}';
    final Puzzle puzzle = await service.import(messy);
    expect(puzzle.givenString, validPuzzle);
  });

  test('长度非 81 → E_IMPORT_001', () async {
    await expectLater(
      service.import('123'),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_IMPORT_001'),
      ),
    );
  });

  test('含非法字符 → E_IMPORT_001', () async {
    final String bad =
        '${validPuzzle.substring(0, 40)}X${validPuzzle.substring(41)}';
    await expectLater(
      service.import(bad),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_IMPORT_001'),
      ),
    );
  });

  test('初始盘面自相矛盾（行冲突）→ E_IMPORT_001', () async {
    // 第一行出现两个 6。
    final String conflicted = '66${validPuzzle.substring(2)}'.substring(0, 81);
    await expectLater(
      service.import(conflicted),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_IMPORT_001'),
      ),
    );
  });

  test('多解盘面 → E_IMPORT_002', () async {
    await expectLater(
      service.import(multiSolutionPuzzle),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_IMPORT_002'),
      ),
    );
  });

  test('无解盘面（死格）→ E_IMPORT_001', () async {
    await expectLater(
      service.import(noSolutionPuzzle),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_IMPORT_001'),
      ),
    );
  });
}
