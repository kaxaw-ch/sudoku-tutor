/// T-CORE-09：ScriptReplayer 逐级回放校验测试。
///
/// 正面用例：用真实候选盘面脚本回放全通过（候选由 CLI annotate 产出，
/// 与引擎 `StepwiseSolver` 同源，理应逐级一致）。
/// 反面用例：**人造脚本**——把正确脚本的某一步删数/填数/技巧 ID 改坏，
/// 断言 `ScriptReplayer` 能检出不一致并报告正确的步骤号。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

const String kCandidatesDir = '../../dataset/level_candidates/ch0';

LessonLevel loadCandidate(String fileName) {
  final File file = File('$kCandidatesDir/$fileName');
  final Map<String, Object?> json =
      jsonDecode(file.readAsStringSync(encoding: utf8)) as Map<String, Object?>;
  return LevelCodec.decode(json);
}

/// 构造"改坏一步"的脚本：把 [targetOrder] 步经 [transform] 替换。
SolutionScript mutateStep(
  SolutionScript script,
  int targetOrder,
  ScriptStep Function(ScriptStep step) transform,
) =>
    SolutionScript(
      steps: <ScriptStep>[
        for (final ScriptStep step in script.steps)
          if (step.order == targetOrder) transform(step) else step,
      ],
    );

void main() {
  group('ScriptReplayer · 正面：真实候选脚本回放全通过', () {
    test('ch0_l01（裸单演示，55 步）逐级回放全过', () {
      final LessonLevel level = loadCandidate('ch0_l01_candidate_1.json');
      final ScriptReplayOutcome outcome = ScriptReplayer().replayLevel(level);
      expect(outcome.mismatches, isEmpty,
          reason: '候选脚本应逐级一致：${outcome.mismatches}');
      expect(outcome.verifiedSteps, equals(level.script!.stepCount));
      expect(outcome.passed, isTrue);
    });

    test('ch0_l02（隐单演示，55 步）逐级回放全过', () {
      final LessonLevel level = loadCandidate('ch0_l02_candidate_1.json');
      final ScriptReplayOutcome outcome = ScriptReplayer().replayLevel(level);
      expect(outcome.mismatches, isEmpty,
          reason: '候选脚本应逐级一致：${outcome.mismatches}');
      expect(outcome.verifiedSteps, equals(level.script!.stepCount));
    });

    test('ch0_l05（裸对演示，含删数步骤）逐级回放全过', () {
      final LessonLevel level = loadCandidate('ch0_l05_candidate_1.json');
      expect(
        level.script!.steps.any((ScriptStep s) => s.eliminations.isNotEmpty),
        isTrue,
      );
      final ScriptReplayOutcome outcome = ScriptReplayer().replayLevel(level);
      expect(outcome.mismatches, isEmpty,
          reason: '候选脚本应逐级一致：${outcome.mismatches}');
      expect(outcome.verifiedSteps, equals(level.script!.stepCount));
    });
  });

  group('ScriptReplayer · 反面：人造不一致必须被检出', () {
    test('改坏第 5 步填数 digit → 检出 placement/applyPlacement，步骤号=5', () {
      final LessonLevel level = loadCandidate('ch0_l01_candidate_1.json');
      final SolutionScript broken = mutateStep(
        level.script!,
        5,
        (ScriptStep step) {
          final Placement original = step.placements.single;
          // 把 digit 3 改成 4（终局解为 3）。
          final int wrongDigit = original.digit == 4 ? 5 : 4;
          return ScriptStep(
            order: step.order,
            techniqueId: step.techniqueId,
            placements: <Placement>[
              Placement(original.cellIndex, wrongDigit),
            ],
            involvedCells: step.involvedCells,
            narration: step.narration,
            visual: step.visual,
          );
        },
      );

      final ScriptReplayOutcome outcome = ScriptReplayer().replay(
        puzzle81: level.puzzle81,
        solution81: level.solution81,
        script: broken,
      );

      expect(outcome.passed, isFalse);
      final ReplayMismatch step5 = outcome.mismatches
          .firstWhere((ReplayMismatch m) => m.order == 5);
      expect(
        step5.kind,
        isIn(<ReplayMismatchKind>[
          ReplayMismatchKind.placement,
          ReplayMismatchKind.applyPlacement,
        ]),
        reason: '改坏填数应命中 placement 类不一致：$step5',
      );
      // 期望/实际字符串应体现数字差异。
      expect(step5.expected, isNot(equals(step5.actual)));
    });

    test('改坏第 3 步技巧 ID → 检出 technique mismatch，步骤号=3', () {
      final LessonLevel level = loadCandidate('ch0_l01_candidate_1.json');
      final TechniqueId wrongTech =
          level.script!.steps[2].techniqueId == TechniqueId.nakedSingle
              ? TechniqueId.hiddenSingle
              : TechniqueId.nakedSingle;
      final SolutionScript broken = mutateStep(
        level.script!,
        3,
        (ScriptStep step) => ScriptStep(
          order: step.order,
          techniqueId: wrongTech,
          eliminations: step.eliminations,
          placements: step.placements,
          involvedCells: step.involvedCells,
          narration: step.narration,
          visual: step.visual,
        ),
      );

      final ScriptReplayOutcome outcome = ScriptReplayer().replay(
        puzzle81: level.puzzle81,
        solution81: level.solution81,
        script: broken,
      );

      expect(outcome.passed, isFalse);
      final ReplayMismatch step3 = outcome.mismatches
          .firstWhere((ReplayMismatch m) => m.order == 3);
      expect(step3.kind, equals(ReplayMismatchKind.technique));
      expect(step3.expected, equals(wrongTech.id));
      expect(step3.actual, equals(TechniqueId.nakedSingle.id));
    });

    test('改坏裸对删数 digit → 检出 elimination mismatch，步骤号正确', () {
      final LessonLevel level = loadCandidate('ch0_l05_candidate_1.json');
      final int elimOrder = level.script!.steps
          .firstWhere((ScriptStep s) => s.eliminations.isNotEmpty)
          .order;
      final SolutionScript broken = mutateStep(
        level.script!,
        elimOrder,
        (ScriptStep step) {
          final Elimination original = step.eliminations.first;
          final int wrongDigit = original.digit == 4 ? 5 : 4;
          return ScriptStep(
            order: step.order,
            techniqueId: step.techniqueId,
            eliminations: <Elimination>[
              for (final Elimination e in step.eliminations)
                if (e.cellIndex == original.cellIndex &&
                    e.digit == original.digit)
                  Elimination(original.cellIndex, wrongDigit)
                else
                  e,
            ],
            placements: step.placements,
            involvedCells: step.involvedCells,
            narration: step.narration,
            visual: step.visual,
          );
        },
      );

      final ScriptReplayOutcome outcome = ScriptReplayer().replay(
        puzzle81: level.puzzle81,
        solution81: level.solution81,
        script: broken,
      );

      expect(outcome.passed, isFalse);
      final ReplayMismatch at = outcome.mismatches
          .firstWhere((ReplayMismatch m) => m.order == elimOrder);
      expect(
        at.kind,
        isIn(<ReplayMismatchKind>[
          ReplayMismatchKind.elimination,
          ReplayMismatchKind.applyElimination,
        ]),
        reason: '改坏删数应命中 elimination 类不一致：$at',
      );
    });

    test('宽松模式（strictTechnique=false）忽略技巧 ID、仅校验结论包含关系', () {
      final LessonLevel level = loadCandidate('ch0_l01_candidate_1.json');
      final SolutionScript broken = mutateStep(
        level.script!,
        3,
        (ScriptStep step) => ScriptStep(
          order: step.order,
          // 故意报错技巧，但结论保持正确。
          techniqueId: TechniqueId.hiddenSingle,
          eliminations: step.eliminations,
          placements: step.placements,
          involvedCells: step.involvedCells,
          narration: step.narration,
          visual: step.visual,
        ),
      );

      final ScriptReplayOutcome strictOutcome = ScriptReplayer().replay(
        puzzle81: level.puzzle81,
        solution81: level.solution81,
        script: broken,
        strictTechnique: true,
      );
      expect(strictOutcome.mismatches, isNotEmpty,
          reason: '严格模式必须检出技巧 ID 不一致');

      final ScriptReplayOutcome looseOutcome = ScriptReplayer().replay(
        puzzle81: level.puzzle81,
        solution81: level.solution81,
        script: broken,
        strictTechnique: false,
      );
      expect(looseOutcome.mismatches, isEmpty,
          reason: '宽松模式只校验结论，技巧 ID 不影响；'
              '${looseOutcome.mismatches}');
    });
  });
}
