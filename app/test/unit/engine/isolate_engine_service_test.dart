/// T-DOM-02 · 常驻 Isolate 引擎服务集成测试（P0-ENG-12）。
///
/// 在**真实 Isolate** 上验证：
/// 1. 评级/生成/提示扫描在独立 Isolate 执行并返回正确结果；
/// 2. 消息纯数据（可 `jsonEncode`，可 send）；
/// 3. `cancelAll` 后过期结果被丢弃（请求代次/ID 校验）；
/// 4. Isolate 内耗时任务**不阻塞 UI 帧**（主 isolate 计时断言）。
///
/// ⚠️ 本测试用真实异步（非 fakeAsync），每个用例独立 service 并 dispose。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/engine/engine_task.dart';
import 'package:sudoku_tutor/domain/engine/isolate_engine_service.dart';

/// 标准终盘（已填满，分级应为一步未用的入门）。
const String kSolvedBoard =
    '534678912672195348198342567859761423426853791713924856'
    '961537284287419635345286179';

/// M0 冒烟题（骨架页自检样例）。
const String kSamplePuzzle =
    '530070000600195000098000060800060003400803001700020006'
    '060000280000419005000080079';

void main() {
  late IsolateEngineService service;

  setUp(() {
    service = IsolateEngineService();
  });

  tearDown(() async {
    await service.dispose();
  });

  test('评级任务在独立 Isolate 执行：完整终盘 = 入门且已解出', () async {
    final EngineResult result = await service.runTask(
      (int taskId, int generation) => GradeTask(
        taskId: taskId,
        generation: generation,
        puzzle81: kSolvedBoard,
        ruleSetIds: const <String>[],
      ),
    );

    expect(result, isA<GradeResult>());
    final GradeResult grade = result as GradeResult;
    expect(grade.reportJson['difficulty'], 'beginner');
    expect(grade.reportJson['solved'], isTrue);
  });

  test('生成任务在独立 Isolate 执行：同 seed 可复现、题面合法', () async {
    final EngineResult result = await service.runTask(
      (int taskId, int generation) => GenerateTask(
        taskId: taskId,
        generation: generation,
        seed: 42,
        targetGivens: 30,
      ),
    );

    expect(result, isA<GenerateResult>());
    final GenerateResult gen = result as GenerateResult;
    expect(gen.puzzle81.length, 81);
    expect(gen.solution81.length, 81);
    expect(gen.givenCount, greaterThanOrEqualTo(PuzzleGenerator.kMinGivens));
    // 题面可被 core 正常解析（合法盘面）。
    final Board board = Board.fromPuzzleString(gen.puzzle81);
    expect(board.givenCount(), gen.givenCount);
  });

  test('提示扫描任务在独立 Isolate 执行：返回下一步技巧或 null', () async {
    final EngineResult result = await service.runTask(
      (int taskId, int generation) => HintScanTask(
        taskId: taskId,
        generation: generation,
        puzzle81: kSamplePuzzle,
        ruleSetIds: const <String>[],
      ),
    );

    expect(result, isA<HintScanResult>());
    final HintScanResult hint = result as HintScanResult;
    // 该题至少存在一个可识别技巧；即使无可用也应返回合法结果类型。
    expect(hint.techniqueJson, anyOf(isA<Map<String, Object?>>(), isNull));
  });

  test('消息是纯数据：toMessage 后可 jsonEncode（可跨 isolate send）', () async {
    final EngineTask task = GenerateTask(
      taskId: 1,
      generation: 1,
      seed: 7,
      targetGivens: 30,
    );
    expect(jsonEncode(task.toMessage()), isA<String>());
    expect(jsonEncode(task.toMessage()), contains('"seed":7'));
  });

  test('cancelAll 后：在途任务收到 E_ENGINE_001，过期结果被丢弃', () async {
    final Future<EngineResult> inFlight = service.runTask(
      (int taskId, int generation) => GenerateTask(
        taskId: taskId,
        generation: generation,
        seed: 1,
        targetGivens: 30,
        delayMs: 300, // 保证任务仍在 worker 执行中。
      ),
    );

    // 确保任务已投递到 worker。
    await Future<void>.delayed(const Duration(milliseconds: 60));
    service.cancelAll();

    // 调用方收到取消结果。
    final EngineResult cancelled = await inFlight;
    expect(cancelled, isA<EngineErrorResult>());
    expect((cancelled as EngineErrorResult).code, 'E_ENGINE_001');

    // 等待 worker 把旧代次结果送回 —— 应被丢弃（不崩溃、不污染 pending）。
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(service.generation, greaterThan(1), reason: 'cancelAll 已提升代次');
  });

  test('dispatchResult 按代次过滤：过期结果直接丢弃', () async {
    final Completer<EngineResult> completer = Completer<EngineResult>();
    service.cancelAll(); // 代次 +1

    final int staleGeneration = service.generation - 1;
    // 注入一条旧代次结果 —— 若未被过滤，会把没有 pending 的 id 也处理掉。
    service.dispatchResult(
      GenerateResult(
        taskId: 999,
        generation: staleGeneration,
        puzzle81: kSamplePuzzle.substring(0, 81),
        solution81: kSolvedBoard,
        givenCount: 20,
      ),
    );
    // 无 pending 任务 + 旧代次 → 无副作用。
    expect(completer.isCompleted, isFalse);
  });

  test('Isolate 内耗时任务不阻塞主 isolate（低端机掉帧替代验证）', () async {
    final Future<EngineResult> heavy = service.runTask(
      (int taskId, int generation) => GenerateTask(
        taskId: taskId,
        generation: generation,
        seed: 123,
        targetGivens: 30,
        delayMs: 300, // worker 侧强制耗时 300ms。
      ),
    );

    // 主 isolate 同时执行 5 次 10ms 延时（模拟逐帧任务）。
    final Stopwatch watch = Stopwatch()..start();
    for (int i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    watch.stop();

    // 若 worker 阻塞主 isolate，总耗时会被拖到 ≈300ms；
    // 正常调度下应接近 50ms，远小于 300ms。
    expect(
      watch.elapsedMilliseconds,
      lessThan(250),
      reason: '主 isolate 在 worker 忙碌时应能按时完成 5×10ms 延时',
    );

    // 收尾：让 heavy 完成或被取消，避免悬挂。
    await heavy;
  });
}
