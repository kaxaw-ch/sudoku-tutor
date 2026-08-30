/// `FilterSpec` / `Dedup` / `AnnotatedPuzzle` JSON 往返单测。
library;

import 'package:test/test.dart';
import 'package:sudoku_core/sudoku_core.dart';

import 'package:sudoku_cli/sudoku_cli.dart';

/// 构造一个测试用标注题（难度/技巧可定制）。
AnnotatedPuzzle makePuzzle({
  required Difficulty difficulty,
  Set<TechniqueId> techniques = const <TechniqueId>{},
  int seed = 1,
}) {
  final Puzzle core = PuzzleGenerator().generate(Rng(seed), targetGivens: 36);
  return AnnotatedPuzzle(
    puzzle81: core.givenString,
    solution81: core.solutionString,
    seed: seed,
    fingerprint: Fingerprint.ofValues(core.given),
    difficulty: difficulty,
    hardestTechnique: techniques.isEmpty ? null : techniques.first,
    stepCount: 10,
    techniques: techniques,
  );
}

void main() {
  group('FilterSpec', () {
    test('精确难度匹配', () {
      final FilterSpec spec = FilterSpec(exactDifficulty: Difficulty.hard);
      expect(spec.matches(makePuzzle(difficulty: Difficulty.hard)), isTrue);
      expect(spec.matches(makePuzzle(difficulty: Difficulty.medium)), isFalse);
    });

    test('难度区间匹配', () {
      final FilterSpec spec = FilterSpec(
        minDifficulty: Difficulty.hard,
        maxDifficulty: Difficulty.master,
      );
      expect(spec.matches(makePuzzle(difficulty: Difficulty.hard)), isTrue);
      expect(spec.matches(makePuzzle(difficulty: Difficulty.master)), isTrue);
      expect(spec.matches(makePuzzle(difficulty: Difficulty.medium)), isFalse);
    });

    test('requiredTechniques 必须全部出现', () {
      final FilterSpec spec = FilterSpec(
        requiredTechniques: <TechniqueId>{TechniqueId.xWing, TechniqueId.xyWing},
      );
      expect(
        spec.matches(
          makePuzzle(
            difficulty: Difficulty.hard,
            techniques: <TechniqueId>{
              TechniqueId.xWing,
              TechniqueId.xyWing,
            },
          ),
        ),
        isTrue,
      );
      expect(
        spec.matches(
          makePuzzle(
            difficulty: Difficulty.hard,
            techniques: <TechniqueId>{TechniqueId.xWing},
          ),
        ),
        isFalse,
      );
    });

    test('anyRequiredTechniques 至少一个', () {
      final FilterSpec spec = FilterSpec(
        anyRequiredTechniques: <TechniqueId>{
          TechniqueId.finnedXWing,
          TechniqueId.swordfish,
        },
      );
      expect(
        spec.matches(
          makePuzzle(
            difficulty: Difficulty.hard,
            techniques: <TechniqueId>{TechniqueId.finnedXWing},
          ),
        ),
        isTrue,
      );
      expect(
        spec.matches(
          makePuzzle(
            difficulty: Difficulty.hard,
            techniques: <TechniqueId>{TechniqueId.xWing},
          ),
        ),
        isFalse,
      );
    });

    test('bannedTechniques 禁止出现', () {
      final FilterSpec spec = FilterSpec(
        bannedTechniques: <TechniqueId>{TechniqueId.xWing},
      );
      expect(
        spec.matches(
          makePuzzle(
            difficulty: Difficulty.medium,
            techniques: <TechniqueId>{TechniqueId.nakedPair},
          ),
        ),
        isTrue,
      );
      expect(
        spec.matches(
          makePuzzle(
            difficulty: Difficulty.medium,
            techniques: <TechniqueId>{TechniqueId.xWing},
          ),
        ),
        isFalse,
      );
    });

    test('toJson/fromJson 往返一致', () {
      final FilterSpec spec = FilterSpec(
        requiredTechniques: <TechniqueId>{TechniqueId.xWing},
        anyRequiredTechniques: <TechniqueId>{TechniqueId.finnedXWing},
        bannedTechniques: <TechniqueId>{TechniqueId.wWing},
        exactDifficulty: Difficulty.hard,
      );
      final FilterSpec restored = FilterSpec.fromJson(spec.toJson());
      expect(restored.requiredTechniques, spec.requiredTechniques);
      expect(restored.anyRequiredTechniques, spec.anyRequiredTechniques);
      expect(restored.bannedTechniques, spec.bannedTechniques);
      expect(restored.exactDifficulty, Difficulty.hard);
    });
  });

  group('Dedup 指纹去重', () {
    test('同构（数字重标）被识别为重复', () {
      // 取自 selftest 的真实 81 字符题面。
      const String a = '..167..259.781.....3.....873.45267....6...4....2..7.5.7..16.2.....35..79..9......';
      expect(a.length, 81);
      // 把数字 1 与 9 互换：数字重标等价 → 规范化指纹必须相同。
      final String relabeled = a
          .replaceAll('1', 'A')
          .replaceAll('9', 'B')
          .replaceAll('A', '9')
          .replaceAll('B', '1');
      final Dedup dedup = Dedup();
      expect(dedup.add(Dedup.fingerprintOf(BoardCodec.decodeValues(a))), isTrue);
      expect(
        dedup.add(Dedup.fingerprintOf(BoardCodec.decodeValues(relabeled))),
        isFalse,
        reason: '数字重标后的题面指纹应与原题相同',
      );
    });

    test('不同题面指纹不同', () {
      final Puzzle p1 = PuzzleGenerator().generate(Rng(11), targetGivens: 30);
      final Puzzle p2 = PuzzleGenerator().generate(Rng(12), targetGivens: 30);
      final Dedup dedup = Dedup();
      expect(dedup.add(Dedup.fingerprintOf(p1.given)), isTrue);
      expect(dedup.add(Dedup.fingerprintOf(p2.given)), isTrue);
      expect(dedup.length, 2);
    });

    test('unique 静态方法返回去重后列表', () {
      final Puzzle core = PuzzleGenerator().generate(Rng(99), targetGivens: 34);
      final AnnotatedPuzzle p = fromPuzzleOnly(puzzle: core, seed: 99);
      final List<AnnotatedPuzzle> withDup = <AnnotatedPuzzle>[p, p];
      final (List<AnnotatedPuzzle>, int) result = Dedup.unique(withDup);
      expect(result.$1.length, 1);
      expect(result.$2, 1);
    });
  });

  group('AnnotatedPuzzle JSON 往返', () {
    test('标注题 toJson/fromJson 往返一致', () {
      final Puzzle core = PuzzleGenerator().generate(Rng(7), targetGivens: 30);
      final Board board = core.toGivenBoard();
      CandidateCalculator.recomputeAll(board);
      final StepwiseSolveOutcome outcome = StepwiseSolver().solve(
        SolveContext(
          board: board,
          ruleSet: RuleSet.t2(),
          uniqueSolutionGuaranteed: true,
          solution: core.solution,
        ),
      );
      final GradingReport report = DifficultyGrader.fromOutcome(outcome);
      final AnnotatedPuzzle annotated = assembleAnnotated(
        puzzle: core,
        seed: 7,
        outcome: outcome,
        report: report,
      );

      final Map<String, Object?> json = annotated.toJson();
      final AnnotatedPuzzle restored = AnnotatedPuzzle.fromJson(json);

      expect(restored.puzzle81, annotated.puzzle81);
      expect(restored.solution81, annotated.solution81);
      expect(restored.difficulty, annotated.difficulty);
      expect(restored.hardestTechnique, annotated.hardestTechnique);
      expect(restored.stepCount, annotated.stepCount);
      expect(restored.techniques, annotated.techniques);
      expect(restored.script.length, annotated.script.length);
      expect(restored.script.first.techniqueId,
          annotated.script.first.techniqueId);
      expect(restored.script.first.eliminations,
          annotated.script.first.eliminations);
      expect(restored.script.first.placements,
          annotated.script.first.placements);
    });

    test('脚本步骤携带可视化与中文讲解', () {
      final Puzzle core = PuzzleGenerator().generate(Rng(7), targetGivens: 30);
      final Board board = core.toGivenBoard();
      CandidateCalculator.recomputeAll(board);
      final StepwiseSolveOutcome outcome = StepwiseSolver().solve(
        SolveContext(
          board: board,
          ruleSet: RuleSet.t2(),
          uniqueSolutionGuaranteed: true,
          solution: core.solution,
        ),
      );
      final GradingReport report = DifficultyGrader.fromOutcome(outcome);
      final AnnotatedPuzzle annotated = assembleAnnotated(
        puzzle: core,
        seed: 7,
        outcome: outcome,
        report: report,
      );
      expect(annotated.script, isNotEmpty);
      final AnnotatedScriptStep first = annotated.script.first;
      expect(first.visual, isNotEmpty,
          reason: '每步必须携带 VisualHint JSON（UI 零推断）');
      expect(first.narration, isNotNull,
          reason: '每步必须渲染中文讲解（模板表应覆盖 16 项）');
    });
  });
}
