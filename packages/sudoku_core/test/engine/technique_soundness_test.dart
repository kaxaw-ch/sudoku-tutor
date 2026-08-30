/// **零误报总闸**：16 项识别器在真实题面上的结论必须条条与终局解相容。
///
/// 这是「精确率优先、零误报」这条架构红线唯一的端到端断言（doc 08 风险 1）。
///
/// 关键设计——[SolveContext.solution] 必须传 `null`：
/// `TechniqueSupport.emit` 会用 `ctx.solution` 过滤掉不安全结论。若把真实终局解
/// 喂进上下文，误报会被识别器自己静默吞掉，测试就变成永远通过的空壳。
/// 因此本文件让识别器在「不知道答案」的状态下裸奔，再用**外部**持有的终局解
/// 逐条复核 —— 只有这样才能真正抓出误删/误填。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

/// 把一条结论落到盘面，返回实际改动条目数（等价于 StepwiseSolver 的私有落盘逻辑）。
int applyResult(Board board, TechniqueResult result) {
  int changed = 0;
  for (final Elimination e in result.eliminations) {
    if (board.isBlank(e.cellIndex) &&
        board.candidatesAt(e.cellIndex).contains(e.digit)) {
      board.eliminate(e.cellIndex, e.digit);
      changed++;
    }
  }
  for (final Placement p in result.placements) {
    if (!board.isBlank(p.cellIndex)) {
      continue;
    }
    board.forceSetValue(p.cellIndex, p.digit);
    CandidateCalculator.syncAfterPlace(board, p.cellIndex, p.digit);
    changed++;
  }
  return changed;
}

/// 一次扫描中发现的问题描述（用于失败时给出可复现信息）。
String describeViolation(
  int seed,
  Board board,
  TechniqueResult result,
  SanityViolation violation,
) =>
    '\nseed=$seed'
    '\n技巧=${result.techniqueId.id}(${result.techniqueId.zhName})'
    '\n违规=${violation.zhDescription}'
    '\n结论指纹=${result.fingerprint}'
    '\n复现盘面=${board.toPuzzleString(emptyChar: "0")}';

void main() {
  const PuzzleGenerator generator = PuzzleGenerator();
  final TechniqueRegistry registry = TechniqueRegistry.defaults();

  group('注册表完整性', () {
    test('16 项识别器全部登记，按 rank 升序且无遗漏', () {
      expect(registry.length, equals(16));
      expect(registry.length, equals(TechniqueId.values.length));
      expect(registry.missingIds(), isEmpty);

      final List<Technique> sorted = registry.sorted;
      for (int i = 1; i < sorted.length; i++) {
        expect(sorted[i].rank, greaterThan(sorted[i - 1].rank));
      }
      expect(registry.enabled(RuleSet.t2()), hasLength(16));
      expect(registry.enabled(RuleSet.none()), isEmpty);
    });

    test('每个识别器在空盘上都返回空（不得凭空造结论）', () {
      final SolveContext ctx = SolveContext(
        board: Board.empty(),
        ruleSet: RuleSet.t2(),
      );
      for (final Technique technique in registry.sorted) {
        expect(technique.find(ctx, limit: 8), isEmpty,
            reason: '${technique.id.id} 在全空候选的盘面上不应有任何结论');
      }
    });
  });

  group('16 项识别器 · 真实题面零误报', () {
    /// 逐题推进并在**每个中间状态**扫描全部 16 项识别器，
    /// 用外部终局解复核每一条结论。
    Set<TechniqueId> auditPuzzle(int seed, {required int targetGivens}) {
      final Puzzle puzzle = generator.generate(
        Rng(seed),
        targetGivens: targetGivens,
        requireExactTarget: true,
      );
      final List<int> solution = puzzle.solution;
      final Board board = puzzle.toGivenBoard();
      CandidateCalculator.recomputeAll(board);

      final Set<TechniqueId> exercised = <TechniqueId>{};
      final Set<String> appliedFingerprints = <String>{};

      for (int step = 0; step < 200; step++) {
        // 识别器不知道答案：solution 传 null，避免自我过滤。
        final SolveContext ctx = SolveContext(
          board: board,
          ruleSet: RuleSet.t2(),
        );

        TechniqueResult? next;
        for (final Technique technique in registry.sorted) {
          for (final TechniqueResult result in technique.find(ctx, limit: 6)) {
            if (result.isEmpty) {
              continue;
            }
            exercised.add(result.techniqueId);

            // —— 核心断言：任何一条结论都不得与终局解冲突 ——
            final List<SanityViolation> violations =
                SanityGuard.collectViolations(solution, result);
            expect(
              violations,
              isEmpty,
              reason: violations.isEmpty
                  ? null
                  : describeViolation(seed, board, result, violations.first),
            );

            // 结论必须自带完整的可视化与讲解载荷（P0-ENG-09/10）。
            expect(result.visual.isNotEmpty, isTrue,
                reason: '${result.techniqueId.id} 结论缺少 visual');
            expect(result.narration.slots.isNotEmpty, isTrue,
                reason: '${result.techniqueId.id} 结论缺少 narration');

            next ??= result;
          }
        }

        if (next == null) {
          break; // 当前规则集下再无可用技巧。
        }
        if (!appliedFingerprints.add(next.fingerprint)) {
          break; // 同一结论重复上报，防空转。
        }
        if (applyResult(board, next) == 0) {
          break; // 无实际改动，防空转。
        }
        // 每步之后，各格候选必须是「全量重算结果」的子集：
        // 技巧删数只会让候选变少，绝不允许凭空多出候选。
        // （注意不能要求逐格相等 —— 删数本就是刻意偏离几何重算的结果。）
        for (final int index in board.blankCells()) {
          final CandidateSet actual = board.candidatesAt(index);
          final CandidateSet geometric =
              CandidateCalculator.candidatesFor(board, index);
          expect(geometric.containsAll(actual), isTrue,
              reason: 'seed=$seed 第 $step 步后 ${Coord.label(index)} '
                  '出现了几何上不可能的候选');
        }
        if (board.isFull) {
          break;
        }
      }

      // 已填入的格必须全部等于终局解。
      for (int i = 0; i < kCellCount; i++) {
        if (board.valueAt(i) != kEmptyValue) {
          expect(board.valueAt(i), equals(solution[i]),
              reason: 'seed=$seed 在 ${Coord.label(i)} 填错了数字');
        }
      }
      // 剩余空格的候选集必须仍然保留正确答案（没有被误删）。
      for (final int index in board.blankCells()) {
        expect(
          board.candidatesAt(index).contains(solution[index]),
          isTrue,
          reason: 'seed=$seed ${Coord.label(index)} 的正确答案 '
              '${solution[index]} 被误删'
              '\n复现盘面=${board.toPuzzleString(emptyChar: "0")}',
        );
      }
      return exercised;
    }

    test('多副随机题目全程无一条误删/误填结论', () {
      final Set<TechniqueId> covered = <TechniqueId>{};
      for (final int seed in <int>[1, 2, 3, 5, 8, 13, 21, 34]) {
        covered.addAll(auditPuzzle(seed, targetGivens: 24));
      }

      // 覆盖率自检：上述固定 seed 恰好能把 16 项识别器全部真实触发一遍。
      // 若某项从未被触发，本轮「零误报」对它就是空头支票，必须补 seed。
      final Set<TechniqueId> missed =
          TechniqueId.values.toSet().difference(covered);
      expect(
        missed,
        isEmpty,
        reason: '以下技巧在本轮体检中从未被触发，零误报结论对它们不成立：'
            '${missed.map((TechniqueId t) => t.id).join("、")}',
      );
    });
  });

  group('StepwiseSolver · 端到端一致性', () {
    test('逐级求解得到的盘面与终局解完全一致', () {
      final StepwiseSolver solver = StepwiseSolver();
      int solvedCount = 0;

      for (final int seed in <int>[4, 6, 9, 12, 15]) {
        final Puzzle puzzle = generator.generate(Rng(seed), targetGivens: 32);
        final StepwiseSolveOutcome outcome = solver.solveBoard(
          puzzle.toGivenBoard(),
          // 此处允许传终局解：本组验证的是求解链路，而非识别器精确率。
          solution: puzzle.solution,
        );

        for (int i = 0; i < kCellCount; i++) {
          if (outcome.board.valueAt(i) != kEmptyValue) {
            expect(outcome.board.valueAt(i), equals(puzzle.solution[i]),
                reason: 'seed=$seed 逐级求解在 ${Coord.label(i)} 填错');
          }
        }
        if (outcome.solved) {
          solvedCount++;
          expect(outcome.board.toValueList(), equals(puzzle.solution));
          expect(outcome.steps, isNotEmpty);
          expect(outcome.maxRank(), greaterThan(0));
        }
      }
      expect(solvedCount, greaterThan(0), reason: '至少应有题目被纯逻辑解出');
    });
  });
}
