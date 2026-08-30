/// `GenerationPipeline` 单测（T-CLI-02：可复现 / 去重 / 命中率）。
library;

import 'package:test/test.dart';
import 'package:sudoku_core/sudoku_core.dart';

import 'package:sudoku_cli/sudoku_cli.dart';

const ProfileSpec _t2 = ProfileSpec(
  name: 't2',
  description: '',
  ruleSetMode: RuleSetMode.t2,
  customIds: <String>[],
  defaultDifficulty: Difficulty.medium,
  defaultTargetGivens: 30,
  symmetry: SymmetryMode.none,
  maxAttempts: 500,
);

void main() {
  group('GenerationPipeline 可复现', () {
    test('同 seed 单并发两次产出完全一致', () async {
      final FilterSpec filter = FilterSpec(exactDifficulty: Difficulty.hard);
      final GenerationPipeline pipeline = GenerationPipeline();
      final PipelineRunResult a = await pipeline.run(
        targetCount: 5,
        baseSeed: 424242,
        profile: _t2,
        filter: filter,
        maxAttempts: 200,
        targetGivens: 24,
        concurrency: 1,
        annotate: true,
      );
      final PipelineRunResult b = await pipeline.run(
        targetCount: 5,
        baseSeed: 424242,
        profile: _t2,
        filter: filter,
        maxAttempts: 200,
        targetGivens: 24,
        concurrency: 1,
        annotate: true,
      );
      final List<String> puzzleA =
          <String>[for (final p in a.puzzles) p.puzzle81];
      final List<String> puzzleB =
          <String>[for (final p in b.puzzles) p.puzzle81];
      expect(puzzleA, equals(puzzleB), reason: '同 seed 必须可复现');
      expect(a.stats.attempts, b.stats.attempts);
    });

    test('并发 4 两次产出一致（忽略无时间依赖字段）', () async {
      final FilterSpec filter = FilterSpec(exactDifficulty: Difficulty.hard);
      final GenerationPipeline pipeline = GenerationPipeline();
      final PipelineRunResult a = await pipeline.run(
        targetCount: 6,
        baseSeed: 90909,
        profile: _t2,
        filter: filter,
        maxAttempts: 300,
        targetGivens: 24,
        concurrency: 4,
        annotate: true,
      );
      final PipelineRunResult b = await pipeline.run(
        targetCount: 6,
        baseSeed: 90909,
        profile: _t2,
        filter: filter,
        maxAttempts: 300,
        targetGivens: 24,
        concurrency: 4,
        annotate: true,
      );
      final List<String> puzzleA =
          <String>[for (final p in a.puzzles) p.puzzle81];
      final List<String> puzzleB =
          <String>[for (final p in b.puzzles) p.puzzle81];
      expect(puzzleA, equals(puzzleB), reason: '同并发同 seed 必须可复现');
    });

    test('收录题全部命中目标难度档', () async {
      final FilterSpec filter = FilterSpec(exactDifficulty: Difficulty.hard);
      final GenerationPipeline pipeline = GenerationPipeline();
      final PipelineRunResult result = await pipeline.run(
        targetCount: 5,
        baseSeed: 12345,
        profile: _t2,
        filter: filter,
        maxAttempts: 300,
        targetGivens: 24,
        concurrency: 2,
        annotate: true,
      );
      expect(result.puzzles.length, 5);
      for (final AnnotatedPuzzle puzzle in result.puzzles) {
        expect(puzzle.difficulty, Difficulty.hard);
      }
    });

    test('收录题指纹无重复（去重生效）', () async {
      final FilterSpec filter = FilterSpec(exactDifficulty: Difficulty.hard);
      final GenerationPipeline pipeline = GenerationPipeline();
      final PipelineRunResult result = await pipeline.run(
        targetCount: 8,
        baseSeed: 555,
        profile: _t2,
        filter: filter,
        maxAttempts: 300,
        targetGivens: 24,
        concurrency: 3,
        annotate: true,
      );
      final Set<String> fingerprints = <String>{
        for (final AnnotatedPuzzle puzzle in result.puzzles) puzzle.fingerprint,
      };
      expect(fingerprints.length, result.puzzles.length,
          reason: '去重后无同构重复');
    });

    test('无法凑足目标时返回不足量并标记未完成', () async {
      // medium 档精确命中率≈0%（批次 D 实测），故意用极低预算验证优雅降级。
      final FilterSpec filter = FilterSpec(exactDifficulty: Difficulty.medium);
      final GenerationPipeline pipeline = GenerationPipeline();
      final PipelineRunResult result = await pipeline.run(
        targetCount: 20,
        baseSeed: 777,
        profile: _t2,
        filter: filter,
        maxAttempts: 60,
        targetGivens: 26,
        concurrency: 1,
        annotate: true,
        minTargetGivens: 20,
      );
      expect(result.puzzles.length, lessThan(20));
      expect(result.isComplete, isFalse);
      expect(result.stats.attempts, greaterThan(0));
    });
  });

  group('GenerationPipeline 命中率统计', () {
    test('唯一解率与可解率统计口径正确', () async {
      final FilterSpec filter = FilterSpec(exactDifficulty: Difficulty.hard);
      final GenerationPipeline pipeline = GenerationPipeline();
      final PipelineRunResult result = await pipeline.run(
        targetCount: 5,
        baseSeed: 888,
        profile: _t2,
        filter: filter,
        maxAttempts: 120,
        targetGivens: 24,
        concurrency: 1,
        annotate: true,
      );
      final PipelineStats stats = result.stats;
      expect(stats.attempts, greaterThanOrEqualTo(stats.uniqueOk));
      expect(stats.uniqueOk, greaterThanOrEqualTo(stats.solvable));
      expect(stats.solvable, greaterThanOrEqualTo(stats.matched));
      expect(stats.matched, greaterThanOrEqualTo(stats.accepted));
      expect(stats.usageCounts, isNotEmpty, reason: '收录题应标注技巧');
      expect(stats.difficultyCounts[Difficulty.hard],
          result.puzzles.length);
    });
  });
}
