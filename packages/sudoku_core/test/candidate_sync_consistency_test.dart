/// 候选增量同步与全量重算逐格一致性（批次 B，doc 07 T-CORE-02）。
///
/// 目标：证明 `CandidateCalculator.syncAfterPlace/syncAfterClear` 的增量维护，
/// 在任意随机操作序列下，与 `recomputeAll` 全量重算结果**逐格相等**。
///
/// ⚠️ 静态约束：本文件不在当前沙箱执行（无 Flutter/Dart SDK），
/// 由 CI 在客户端运行；详见 `docs/08-QA批次A+B审查.md` §8 验证清单。
library;

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';

/// 取 [board] 在 [index] 当前候选中的某个合法数字；无候选返回 0。
int _aCandidateDigit(Board board, int index) {
  for (int d = 1; d <= 9; d++) {
    if ((board.candidateMasks[index] & (1 << (d - 1))) != 0) {
      return d;
    }
  }
  return 0;
}

void main() {
  group('增量同步与全量重算一致', () {
    test('10000 步随机 place/clear 后候选逐格相等', () {
      final Rng rng = Rng(20240805);
      final Board boardInc = PuzzleGenerator().generateBoard(
        rng,
        targetGivens: 36,
      );
      final Board boardFull = boardInc.snapshot();

      for (int step = 0; step < 10000; step++) {
        final int cell = rng.nextInt(kCellCount);
        if (boardInc.isGiven(cell)) {
          continue;
        }

        if (boardInc.isBlank(cell)) {
          final int digit = _aCandidateDigit(boardInc, cell);
          if (digit == 0) {
            continue;
          }
          boardInc.place(cell, digit);
          CandidateCalculator.syncAfterPlace(boardInc, cell, digit);
          boardFull.place(cell, digit);
          CandidateCalculator.recomputeAll(boardFull);
        } else {
          boardInc.clear(cell);
          CandidateCalculator.syncAfterClear(boardInc, cell);
          boardFull.clear(cell);
          CandidateCalculator.recomputeAll(boardFull);
        }

        // 每步都必须无不一致格（死格）。
        expect(CandidateCalculator.findInconsistentCells(boardInc), isEmpty,
            reason: 'step=$step 增量同步后出现不一致格');
        expect(CandidateCalculator.findInconsistentCells(boardFull), isEmpty,
            reason: 'step=$step 全量重算后出现不一致格');

        // 两种方式得到的候选掩码必须逐格相同。
        for (int i = 0; i < kCellCount; i++) {
          expect(boardInc.candidateMasks[i], equals(boardFull.candidateMasks[i]),
              reason: 'step=$step 格 $i 候选掩码不一致');
        }
      }
    });

    test('syncAfterClear 后单格候选等于全量重算', () {
      final Rng rng = Rng(1);
      final Board board = PuzzleGenerator().generateBoard(rng, targetGivens: 40);
      final Board reference = board.snapshot();

      // 随便填一格再清掉，比较清掉之后的候选恢复是否正确。
      final int cell = board.blankCells().first;
      final int digit = _aCandidateDigit(board, cell);
      board.place(cell, digit);
      CandidateCalculator.syncAfterPlace(board, cell, digit);
      board.clear(cell);
      CandidateCalculator.syncAfterClear(board, cell);

      CandidateCalculator.recomputeAll(reference);
      // reference 从未被改动（仍保持初始题面），其候选即"正确基准"。
      for (int i = 0; i < kCellCount; i++) {
        expect(board.candidateMasks[i], equals(reference.candidateMasks[i]),
            reason: '格 $i 清数后候选应回到题面初始候选');
      }
    });
  });
}
