/// T-DOM-02 · 引擎任务/结果纯数据协议测试（架构 §7.5）。
///
/// 覆盖：任务/结果的**消息编解码往返一致**、消息可 `jsonEncode`
/// （即「纯数据、可 send」的铁律）。禁闭包传函数/对象由此保证。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/engine/engine_task.dart';

void main() {
  test('GradeTask 消息编解码往返一致', () {
    const GradeTask task = GradeTask(
      taskId: 7,
      generation: 2,
      puzzle81:
          '53..7....600195000098000060800060003400803001700020006060000280000419005000080079',
      givenMask81:
          '111110000010010000010000000010000001000000001000000000010000001000001000000100',
      solution81: null,
      ruleSetIds: <String>['xWing', 'nakedSingle'],
      uniqueGuaranteed: false,
    );

    final Map<String, Object?> msg = task.toMessage();
    // 纯数据：可 JSON 序列化（可 send）。
    expect(jsonEncode(msg), isA<String>());

    final EngineTask decoded = EngineTask.fromMessage(msg);
    expect(decoded, isA<GradeTask>());
    final GradeTask g = decoded as GradeTask;
    expect(g.taskId, 7);
    expect(g.generation, 2);
    expect(g.puzzle81, task.puzzle81);
    expect(g.ruleSetIds, <String>['xWing', 'nakedSingle']);
    expect(g.uniqueGuaranteed, isFalse);
  });

  test('GenerateTask 消息编解码往返一致', () {
    const GenerateTask task = GenerateTask(
      taskId: 3,
      generation: 5,
      seed: 20260805,
      targetGivens: 26,
      symmetryId: 'central',
      requireExactTarget: true,
      delayMs: 120,
    );
    final EngineTask decoded = EngineTask.fromMessage(task.toMessage());
    expect(decoded, isA<GenerateTask>());
    final GenerateTask g = decoded as GenerateTask;
    expect(g.seed, 20260805);
    expect(g.targetGivens, 26);
    expect(g.symmetryId, 'central');
    expect(g.requireExactTarget, isTrue);
    expect(g.delayMs, 120);
  });

  test('HintScanTask 消息编解码往返一致', () {
    const HintScanTask task = HintScanTask(
      taskId: 9,
      generation: 1,
      puzzle81: '53..7....600195000',
      candidateMasks81: <int>[3, 5, 9],
      maxSteps: 1,
    );
    final EngineTask decoded = EngineTask.fromMessage(task.toMessage());
    expect(decoded, isA<HintScanTask>());
    expect((decoded as HintScanTask).maxSteps, 1);
    expect(decoded.puzzle81, '53..7....600195000');
    expect(decoded.candidateMasks81, <int>[3, 5, 9]);
  });

  test('各类结果消息编解码往返一致', () {
    const GradeResult grade = GradeResult(
      taskId: 1,
      generation: 2,
      reportJson: <String, Object?>{
        'difficulty': 'easy',
        'solved': true,
        'stepCount': 3,
      },
    );
    final GradeResult gradeBack =
        EngineResult.fromMessage(grade.toMessage()) as GradeResult;
    expect(gradeBack.reportJson['difficulty'], 'easy');

    const GenerateResult generate = GenerateResult(
      taskId: 2,
      generation: 2,
      puzzle81: '53..7....',
      solution81: '534678912',
      givenCount: 4,
    );
    final GenerateResult genBack =
        EngineResult.fromMessage(generate.toMessage()) as GenerateResult;
    expect(genBack.givenCount, 4);

    const HintScanResult hint = HintScanResult(
      taskId: 3,
      generation: 2,
      techniqueJson: <String, Object?>{'techniqueId': 'xWing'},
    );
    final HintScanResult hintBack =
        EngineResult.fromMessage(hint.toMessage()) as HintScanResult;
    expect(hintBack.techniqueJson!['techniqueId'], 'xWing');

    const HintScanResult noHint = HintScanResult(taskId: 4, generation: 2);
    final HintScanResult noHintBack =
        EngineResult.fromMessage(noHint.toMessage()) as HintScanResult;
    expect(noHintBack.techniqueJson, isNull);

    const EngineErrorResult error = EngineErrorResult(
      taskId: 5,
      generation: 9,
      code: 'E_ENGINE_001',
      message: '已取消',
    );
    final EngineErrorResult errorBack =
        EngineResult.fromMessage(error.toMessage()) as EngineErrorResult;
    expect(errorBack.code, 'E_ENGINE_001');
  });

  test('未知任务类型 → ArgumentError', () {
    expect(
      () => EngineTask.fromMessage(<String, Object?>{'type': 'mystery'}),
      throwsArgumentError,
    );
  });
}
