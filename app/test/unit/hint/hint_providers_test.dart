/// T-DOM-05 · 提示服务 Riverpod 装配测试。
///
/// 在既有 `hint_service_test.dart`（HintService 纯逻辑）基础上补充
/// **Provider 链路**：`hintServiceProvider` 从 ProviderContainer 正确
/// 装配（scan 注入自 `engineFacadeProvider`），新对局前
/// `resetForNewRound()` 复位配额与逐级解锁进度。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/engine/engine_facade.dart';
import 'package:sudoku_tutor/domain/engine/engine_providers.dart';
import 'package:sudoku_tutor/domain/engine/engine_task.dart';
import 'package:sudoku_tutor/domain/engine/isolate_engine_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

import '../../helpers/fake_progress_repository.dart';

/// 假 Isolate 引擎服务：`runTask` 直接返回固定提示扫描结果，不 spawn Isolate。
class _FakeEngineService extends IsolateEngineService {
  _FakeEngineService(this.result);

  final TechniqueResult result;

  @override
  Future<EngineResult> runTask(
    EngineTask Function(int taskId, int generation) build,
  ) async {
    final EngineTask task = build(1, 1);
    if (task is HintScanTask) {
      return HintScanResult(
        taskId: task.taskId,
        generation: task.generation,
        techniqueJson: result.toJson(),
      );
    }
    return EngineErrorResult(
      taskId: task.taskId,
      generation: task.generation,
      code: 'E_ENGINE_002',
      message: '测试仅支持提示扫描任务',
    );
  }
}

/// 构造一个「删数型」技巧结果（nakedPair：仅 eliminations）。
TechniqueResult _eliminationResult() => TechniqueResult(
      techniqueId: TechniqueId.nakedPair,
      eliminations: <Elimination>[Elimination(10, 5)],
      visual: VisualHint.assemble(
        patternCells: const <int>[11, 12],
        eliminated: <MapEntry<int, int>>[const MapEntry<int, int>(10, 5)],
        emphasized: <MapEntry<int, int>>[const MapEntry<int, int>(11, 5)],
      ),
    );

void main() {
  late ProviderContainer container;
  late Board board;
  late List<int> solution;

  setUp(() {
    final Puzzle puzzle = buildTestPuzzle();
    board = puzzle.toGivenBoard();
    solution = puzzle.solution;
    container = ProviderContainer(
      overrides: <Override>[
        engineFacadeProvider.overrideWithValue(
          EngineFacade(service: _FakeEngineService(_eliminationResult())),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('hintServiceProvider 装配成功，逐级解锁走 Provider 链路', () async {
    final HintService service = container.read(hintServiceProvider);
    expect(service.unlockedLevelOf(HintScope.freePlay), 0);
    expect(service.usedCount, 0);

    final HintState? first = await service.requestNext(
      board: board,
      solution: solution,
      scope: HintScope.freePlay,
      quota: HintQuota.unlimited,
    );
    expect(first, isNotNull);
    expect(first!.level, HintLevel.level1);
    expect(first.techniqueId, TechniqueId.nakedPair);
    expect(service.usedCount, 1);
    expect(service.unlockedLevelOf(HintScope.freePlay), 1);

    final HintState? second = await service.requestNext(
      board: board,
      solution: solution,
      scope: HintScope.freePlay,
      quota: HintQuota.unlimited,
    );
    expect(second, isNotNull);
    expect(second!.level, HintLevel.level2);
  });

  test('resetForNewRound 复位配额与解锁进度（新对局前调用）', () async {
    final HintService service = container.read(hintServiceProvider);
    await service.requestNext(
      board: board,
      solution: solution,
      scope: HintScope.freePlay,
      quota: HintQuota.five,
    );
    await service.requestNext(
      board: board,
      solution: solution,
      scope: HintScope.freePlay,
      quota: HintQuota.five,
    );
    expect(service.usedCount, 2);

    service.resetForNewRound();
    expect(service.usedCount, 0);
    expect(service.unlockedLevelOf(HintScope.freePlay), 0);
    expect(service.remainingOf(HintQuota.five), 5, reason: '配额随复位回到满额');
  });
}
