/// 提示扫描必须延续玩家已经完成的候选删减。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/engine/engine_facade.dart';
import 'package:sudoku_tutor/domain/engine/engine_task.dart';
import 'package:sudoku_tutor/domain/engine/isolate_engine_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

void _applyScriptStep(Board board, ScriptStep step) {
  for (final Elimination elimination in step.eliminations) {
    board.eliminate(elimination.cellIndex, elimination.digit);
  }
  for (final Placement placement in step.placements) {
    board.forceSetValue(placement.cellIndex, placement.digit);
    CandidateCalculator.syncAfterPlace(
      board,
      placement.cellIndex,
      placement.digit,
    );
  }
}

TechniqueResult? _scanInWorker(Board board, String solution81) {
  final EngineResult result = executeEngineTask(
    HintScanTask(
      taskId: 1,
      generation: 1,
      puzzle81: board.toPuzzleString(),
      givenMask81: board.toGivenMaskString(),
      solution81: solution81,
      candidateMasks81: List<int>.of(board.candidateMasks),
    ),
  );
  final Map<String, Object?>? json = (result as HintScanResult).techniqueJson;
  return json == null ? null : TechniqueResult.fromJson(json);
}

class _CapturingEngineService extends IsolateEngineService {
  HintScanTask? captured;

  @override
  Future<EngineResult> runTask(
    EngineTask Function(int taskId, int generation) build,
  ) async {
    captured = build(1, 1) as HintScanTask;
    return const HintScanResult(taskId: 1, generation: 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('裸对实操：按三级提示删去部分候选后，下一次扫描必须推进', () async {
    final LessonLevel level = await CurriculumRepository().loadLevel('ch0_l06');
    final Puzzle puzzle = level.toLevelPuzzle().toCore();
    final Board board = puzzle.toGivenBoard();
    CandidateCalculator.recomputeAll(board);

    final ScriptStep nakedPairStep = level.script!.steps.firstWhere(
      (ScriptStep step) =>
          step.techniqueId == TechniqueId.nakedPair &&
          step.eliminations.isNotEmpty,
    );
    for (final ScriptStep step in level.script!.steps) {
      if (step.order >= nakedPairStep.order) {
        break;
      }
      _applyScriptStep(board, step);
    }

    final IsolateEngineService service = IsolateEngineService();
    addTearDown(service.dispose);
    final EngineFacade facade = EngineFacade(service: service);
    final HintService hints = HintService(scan: facade.scanHint);
    final List<HintState> firstScene = <HintState>[];
    for (int order = 1; order <= 3; order++) {
      final HintState? hint = await hints.requestNext(
        board: board,
        solution: puzzle.solution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(hint, isNotNull, reason: '裸对第 $order 级提示应正常展开');
      firstScene.add(hint!);
    }
    final HintState conclusion = firstScene.last;
    expect(conclusion.level, HintLevel.level3);
    expect(conclusion.techniqueId, TechniqueId.nakedPair);
    expect(conclusion.eliminations, isNotEmpty);

    final Elimination applied = conclusion.eliminations.first;
    board.eliminate(applied.cellIndex, applied.digit);
    final HintState? next = await hints.requestNext(
      board: board,
      solution: puzzle.solution,
      scope: HintScope.teaching,
      quota: HintQuota.unlimited,
    );

    expect(next, isNotNull, reason: '删数后仍有后续逻辑步骤，不应显示“暂无提示”');
    expect(next!.level, HintLevel.level1, reason: '新结论必须重新从一级解释');
    expect(
      next.sceneFingerprint,
      isNot(conclusion.sceneFingerprint),
      reason: '候选盘面已推进，不得继续返回同一个裸对结论',
    );
  });

  test('全部实操删数技巧：应用部分结论后均能继续给出新提示', () async {
    final CurriculumRepository repository = CurriculumRepository();
    final LevelIndex index = await repository.loadIndex();
    final Set<TechniqueId> audited = <TechniqueId>{};
    int auditedSteps = 0;

    for (final LevelEntry entry in index.allLevels) {
      if (entry.kind != LevelKind.guidedPractice) {
        continue;
      }
      final LessonLevel level = await repository.loadLevel(entry.id);
      final SolutionScript? script = level.script;
      if (script == null) {
        continue;
      }
      final Board board = level.toLevelPuzzle().toCore().toGivenBoard();
      CandidateCalculator.recomputeAll(board);

      for (final ScriptStep step in script.steps) {
        if (step.eliminations.isNotEmpty) {
          final TechniqueResult? before =
              _scanInWorker(board, level.solution81);
          expect(
            before,
            isNotNull,
            reason: '${level.id} 第 ${step.order} 步应可扫描',
          );
          expect(
            before!.techniqueId,
            step.techniqueId,
            reason: '${level.id} 第 ${step.order} 步技巧应与脚本一致',
          );
          expect(before.eliminations, isNotEmpty);

          final Board progressed = board.snapshot();
          final Elimination applied = before.eliminations.first;
          progressed.eliminate(applied.cellIndex, applied.digit);
          final TechniqueResult? after =
              _scanInWorker(progressed, level.solution81);

          expect(
            after,
            isNotNull,
            reason: '${level.id} 第 ${step.order} 步部分删数后仍应有后续提示',
          );
          expect(
            after!.fingerprint,
            isNot(before.fingerprint),
            reason: '${level.id} 第 ${step.order} 步不得重复旧结论',
          );
          audited.add(step.techniqueId);
          auditedSteps++;
        }
        _applyScriptStep(board, step);
      }
    }

    expect(auditedSteps, greaterThanOrEqualTo(30), reason: '应覆盖全部实操删数步骤');
    expect(
      audited,
      <TechniqueId>{
        TechniqueId.nakedPair,
        TechniqueId.hiddenPair,
        TechniqueId.lockedCandidates,
        TechniqueId.nakedTriple,
        TechniqueId.hiddenTriple,
        TechniqueId.xWing,
        TechniqueId.finnedXWing,
        TechniqueId.swordfish,
        TechniqueId.xyWing,
        TechniqueId.xyzWing,
      },
      reason: '当前课程中的十类候选删减技巧必须全部经过连续提示审计',
    );
  });

  test('零散手写笔记不当成完整候选盘面，自动笔记删数状态会传输', () async {
    final Puzzle puzzle = (await CurriculumRepository().loadLevel('ch0_l06'))
        .toLevelPuzzle()
        .toCore();
    final Board board = puzzle.toGivenBoard();
    final int blank = board.blankCells().first;
    board.addCandidate(blank, puzzle.solution[blank]);

    final _CapturingEngineService engine = _CapturingEngineService();
    final EngineFacade facade = EngineFacade(service: engine);
    await facade.scanHint(board, solution81: puzzle.solutionString);
    expect(
      engine.captured!.candidateMasks81,
      isNull,
      reason: '只有零散手写笔记时应由引擎重算，避免制造伪技巧',
    );

    CandidateCalculator.recomputeAll(board);
    final int target = board.blankCells().firstWhere(
          (int cell) => board.candidatesAt(cell).count() > 1,
        );
    final int removed = board.candidatesAt(target).digits().first;
    board.eliminate(target, removed);
    await facade.scanHint(board, solution81: puzzle.solutionString);

    final List<int>? transferred = engine.captured!.candidateMasks81;
    expect(transferred, isNotNull, reason: '完整候选盘面删数后必须跨 Isolate 传输');
    expect(transferred![target] & (1 << (removed - 1)), 0);
  });

  test('损坏的候选传输会安全回退为合法候选重算', () async {
    final Puzzle puzzle = (await CurriculumRepository().loadLevel('ch0_l06'))
        .toLevelPuzzle()
        .toCore();
    final Board board = puzzle.toGivenBoard();

    TechniqueResult? scanWith(List<int>? masks) {
      final EngineResult result = executeEngineTask(
        HintScanTask(
          taskId: 1,
          generation: 1,
          puzzle81: board.toPuzzleString(),
          givenMask81: board.toGivenMaskString(),
          solution81: puzzle.solutionString,
          candidateMasks81: masks,
        ),
      );
      final Map<String, Object?>? json =
          (result as HintScanResult).techniqueJson;
      return json == null ? null : TechniqueResult.fromJson(json);
    }

    final TechniqueResult? recomputed = scanWith(null);
    final TechniqueResult? invalid = scanWith(List<int>.filled(kCellCount, 0));
    expect(invalid?.fingerprint, recomputed?.fingerprint);
  });
}
