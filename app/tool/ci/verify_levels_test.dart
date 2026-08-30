/// T-QA-05 关卡 JSON 回放校验测试（P0-QA-05、C-25，批次 F 出口硬门槛）。
///
/// 从 F-5 一次性脚本 `tool/verify_curriculum.dart` 复用校验逻辑（见
/// `tool/ci/level_verifier.dart`），本文件只负责 package:test 编排断言：
/// 1. `index.json` 登记校验（34 关齐全、id↔文件一一对应、章内 order 连续唯一）；
/// 2. **逐关** `LevelCodec.decode` + `ScriptReplayer` 逐步回放：
///    技巧识别/删数/填数与脚本标注一致，任意一步不一致即该关失败
///    （错误含关卡 id + 步骤号 + 期望 vs 实际）；
/// 3. 试炼关（`kind == 'trial'`，ch1_l07/ch2_l07/ch3_l10）专项：
///    题面唯一解 + 最高技巧 == 目标技巧 + poolRef 指向来源池；
/// 4. 检测能力自证：构造人造删数/填数不一致，断言校验器能检出。
///
/// 运行：`cd app && dart test tool/ci/verify_levels_test.dart`
///（纯 Dart，不 import flutter；依赖 `test` dev_dependency）。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import 'level_verifier.dart';

void main() {
  final LevelVerifier verifier = LevelVerifier();
  late CurriculumVerification result;

  setUpAll(() {
    result = verifier.verifyAll();
  });

  // ---------------------------------------------------------------- index
  group('index.json 登记（C-25：新增一关 = 加文件 + 登记一行）', () {
    test('schemaVersion 解析成功且 34 关登记齐全、无多余', () {
      expect(result.indexPassed, isTrue, reason: _summarizeIndex(result));
    });

    test('id ↔ 文件一一对应（file == <id>.json），无幽灵文件', () {
      final List<String> errors = <String>[
        for (final String e in result.indexErrors)
          if (e.contains('file') || e.contains('不存在') || e.contains('未登记')) e,
      ];
      expect(errors, isEmpty, reason: errors.join('\n'));
    });

    test('每章 order 连续唯一且 chapter 一致', () {
      final List<String> errors = <String>[
        for (final String e in result.indexErrors)
          if (e.contains('order') || e.contains('chapter')) e,
      ];
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  });

  // ---------------------------------------------------------------- 逐关
  group('逐关解码 + ScriptReplayer 回放（P0-QA-05：任意一步不一致即失败）', () {
    for (final String id in kKnownLevelIds) {
      test('$id 字段完整 + 回放零不一致', () {
        final LevelVerification? lv = result.byId(id);
        expect(lv, isNotNull,
            reason: '$id 未在 index 中登记（${result.indexErrors.join('；')}）');
        if (lv == null) {
          return;
        }
        expect(lv.passed, isTrue, reason: lv.errors.join('\n'));
      });
    }
  });

  // ---------------------------------------------------------------- 试炼关
  group('试炼关专项（kind == trial：盘面确实含目标技巧）', () {
    test('试炼关恰好 3 关，id 集合 == ch1_l07/ch2_l07/ch3_l10', () {
      final List<String> trialIds = <String>[
        for (final LevelVerification lv in result.trialLevels) lv.id,
      ];
      expect(trialIds.toSet(), kTrialLevelIds.toSet(),
          reason: '试炼关集合应为 $kTrialLevelIds，实际 $trialIds');
    });

    for (final String id in kTrialLevelIds) {
      test('$id 唯一解 + 最高技巧 == 目标技巧 + poolRef 正确', () {
        final LevelVerification? lv = result.byId(id);
        expect(lv, isNotNull,
            reason: '$id 未在 index 中登记（${result.indexErrors.join('；')}）');
        if (lv == null) {
          return;
        }
        expect(lv.passed, isTrue, reason: lv.errors.join('\n'));
      });
    }
  });

  // ---------------------------------------------------------------- 汇总
  test('34 关全部通过（批次 F 出口硬门槛汇总）', () {
    expect(result.allPassed, isTrue, reason: _summarizeAll(result));
  });

  // ---------------------------------------------------------------- 自证
  group('LevelVerifier 检测能力自证（人造不一致必须被检出）', () {
    test('篡改删数/填数后能检出，并报告步骤号 + 期望 vs 实际', () {
      final LevelVerification? base = result.byId('ch0_l01');
      expect(base?.level, isNotNull,
          reason: '自证前置：ch0_l01 应可解码（实际 errors=${base?.errors}）');
      if (base?.level == null) {
        return;
      }
      final LessonLevel bad = _tamperedCopy(base!.level!);
      final List<String> errors = verifier.verifyLevel(bad);
      expect(errors, isNotEmpty, reason: '人造不一致必须被检出（当前未检出任何错误！）');
      final String joined = errors.join('\n');
      expect(joined, contains('第 '), reason: '应报告步骤号\n$joined');
      expect(joined, contains('期望'), reason: '应报告期望值\n$joined');
      expect(joined, contains('实际'), reason: '应报告实际值\n$joined');
    });
  });
}

// ------------------------------------------------------------ 工具

String? _summarizeIndex(CurriculumVerification result) =>
    result.indexErrors.isEmpty ? null : result.indexErrors.join('\n');

String? _summarizeAll(CurriculumVerification result) {
  final List<String> lines = <String>[
    ...result.indexErrors,
    for (final LevelVerification lv in result.levels)
      if (!lv.passed) ...lv.errors,
  ];
  return lines.isEmpty ? null : '失败明细：\n${lines.join('\n')}';
}

/// 复制 [base]，并把脚本中首个有结论的步骤的删数/填数数字改错一位。
LessonLevel _tamperedCopy(LessonLevel base) {
  final SolutionScript script = base.script!;
  return LessonLevel(
    id: base.id,
    chapter: base.chapter,
    order: base.order,
    kind: base.kind,
    title: base.title,
    intro: base.intro,
    narration: base.narration,
    techniqueTags: base.techniqueTags,
    puzzle81: base.puzzle81,
    solution81: base.solution81,
    givenMask: base.givenMask,
    poolRef: base.poolRef,
    script: _tamperFirstConclusion(script),
  );
}

/// 把脚本中首个含结论（删数或填数）的步骤对应数字改错，制造人造不一致。
SolutionScript _tamperFirstConclusion(SolutionScript script) {
  final List<ScriptStep> steps = <ScriptStep>[];
  bool tampered = false;
  for (final ScriptStep step in script.steps) {
    if (tampered) {
      steps.add(step);
      continue;
    }
    if (step.eliminations.isNotEmpty) {
      final Elimination first = step.eliminations.first;
      final Elimination bad =
          Elimination(first.cellIndex, first.digit == 1 ? 2 : 1);
      steps.add(ScriptStep(
        order: step.order,
        techniqueId: step.techniqueId,
        eliminations: <Elimination>[
          for (final Elimination e in step.eliminations) e == first ? bad : e,
        ],
        placements: step.placements,
        involvedCells: step.involvedCells,
        narration: step.narration,
        visual: step.visual,
      ));
      tampered = true;
    } else if (step.placements.isNotEmpty) {
      final Placement first = step.placements.first;
      final Placement bad =
          Placement(first.cellIndex, first.digit == 1 ? 2 : 1);
      steps.add(ScriptStep(
        order: step.order,
        techniqueId: step.techniqueId,
        eliminations: step.eliminations,
        placements: <Placement>[
          for (final Placement p in step.placements) p == first ? bad : p,
        ],
        involvedCells: step.involvedCells,
        narration: step.narration,
        visual: step.visual,
      ));
      tampered = true;
    } else {
      steps.add(step);
    }
  }
  if (!tampered) {
    throw StateError('ch0_l01 脚本没有任何删数/填数步，无法构造人造不一致');
  }
  return SolutionScript(steps: steps);
}
