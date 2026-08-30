/// T-EDU-03 · 引导实操关控制器单测（+ T-EDU-04 误操作挂接）。
///
/// 覆盖：
/// - 三级提示必须逐级解锁（一级→二级→三级），次数不限、不扣分；
/// - 已用级别保留可回看（unlockedHints 历史）；
/// - 三级给出删数结论、一级/二级无删数（无 Placement 直出，HintState 结构保证）；
/// - 误操作 (a) 填错 / (c) 抢先填数（仅盘面无法推理推出时才触发；
///   可推理则不打扰——用户诉求），2 分钟去重（错误计数不重复累加）；
/// - 整盘解出 → recordCompletion（hintUsed/errorCount 真实采集）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/session_snapshot.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_detector.dart';
import 'package:sudoku_tutor/domain/teaching/practice_controller.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

/// 假 scan：恒返回裸对删数型结果（确定性，不触发真实引擎）。
TechniqueResult _fakeScan(Board board,
        {RuleSet? ruleSet, String? solution81}) =>
    TechniqueResult(
      techniqueId: TechniqueId.nakedPair,
      eliminations: <Elimination>[Elimination(10, 5)],
      visual: VisualHint.assemble(
        patternCells: const <int>[11, 12],
        eliminated: const <MapEntry<int, int>>[MapEntry<int, int>(10, 5)],
        emphasized: const <MapEntry<int, int>>[MapEntry<int, int>(11, 5)],
      ),
    );

void main() {
  (FakeProgressRepository, ProviderContainer) makeContainer(
      {HintScanFn? scan}) {
    final FakeProgressRepository repo = FakeProgressRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        curriculumRepositoryProvider.overrideWithValue(
          CurriculumRepository(
            loader: buildTeachingCurriculumLoader(
              levelJsonById: buildDefaultTeachingLevels(),
            ),
          ),
        ),
        hintServiceProvider.overrideWithValue(
          HintService(
            scan: scan ??
                (Board board, {RuleSet? ruleSet, String? solution81}) async =>
                    _fakeScan(board, ruleSet: ruleSet, solution81: solution81),
          ),
        ),
      ],
    );
    return (repo, container);
  }

  test('start：加载实操关，初始无提示、无错误', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);

    await ctrl.start('ch0_l02');

    final PracticeState st = container.read(practiceControllerProvider)!;
    expect(st.level.id, 'ch0_l02');
    expect(st.unlockedHints, isEmpty);
    expect(st.currentHint, isNull);
    expect(st.hintUsed, 0);
    expect(st.errorCount, 0);
    expect(st.completed, isFalse);
    expect(st.resumed, isFalse);
  });

  test('自动保存并恢复当前盘面，但不恢复撤销/重做操作过程', () async {
    final (FakeProgressRepository repo, ProviderContainer container) =
        makeContainer();
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);
    final freePlaySnapshot = const SessionSnapshot(
      puzzle81: 'free-play',
      board81: 'free-play',
      elapsedMs: 99,
    );
    repo.snapshot = freePlaySnapshot;

    await ctrl.start('ch0_l02');
    expect(repo.snapshot, same(freePlaySnapshot), reason: '进入教学关不应清除自由练习断点');

    ctrl.handleSelectCell(10);
    ctrl.handleDigit(4); // 错误填数，errorCount=1。
    await ctrl.requestHint(); // hintUsed=1。
    await ctrl.saveNow();

    final saved = repo.teachingSnapshots['ch0_l02']!;
    expect(saved.board81[10], '4');
    expect(saved.hintUsed, 1);
    expect(saved.errorCount, 1);

    await container
        .read(gameSessionControllerProvider.notifier)
        .discardSession(clearSavedSnapshot: false);
    await ctrl.start('ch0_l02');

    final session = container.read(gameSessionControllerProvider)!;
    final state = container.read(practiceControllerProvider)!;
    expect(state.resumed, isTrue);
    expect(session.board.valueAt(10), 4);
    expect(session.errorCells, contains(10));
    expect(session.undoMoves, isEmpty, reason: '不保存退出前的撤销历史');
    expect(session.redoMoves, isEmpty, reason: '不保存退出前的重做历史');
    expect(state.hintUsed, 1);
    expect(state.errorCount, 1);
  });

  test('三级提示必须逐级解锁，次数不限，已用级别保留可回看', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);
    await ctrl.start('ch0_l02');

    final HintState? h1 = await ctrl.requestHint();
    expect(h1, isNotNull);
    expect(h1!.level.order, 1, reason: '第一次请求只能拿到一级');
    expect(h1.eliminations, isEmpty, reason: '一级无删数结论');
    expect(h1.highlightedCells, isNotEmpty, reason: '一级=指出技巧并高亮区域');

    final HintState? h2 = await ctrl.requestHint();
    expect(h2, isNotNull);
    expect(h2!.level.order, 2, reason: '逐级解锁，第二次为二级');
    expect(h2.eliminations, isEmpty, reason: '二级仍无删数结论');

    final HintState? h3 = await ctrl.requestHint();
    expect(h3, isNotNull);
    expect(h3!.level.order, 3, reason: '第三次为三级');
    expect(h3.eliminations, isNotEmpty, reason: '三级=给出删数结论');
    expect(h3.eliminations.first.cellIndex, 10);

    // 已解锁满 → 再请求为 null（不降级、不直出填数答案）。
    expect(await ctrl.requestHint(), isNull);

    final PracticeState st = container.read(practiceControllerProvider)!;
    expect(st.unlockedHints, hasLength(3), reason: '已用级别保留可回看');
    expect(
      st.unlockedHints.map((HintState h) => h.level.order),
      <int>[1, 2, 3],
      reason: '历史按级别升序',
    );
    expect(st.hintUsed, 3, reason: '次数不限且如实计数');
  });

  test('解题结论变化后提示回到一级，并清除上一结论的提示卡', () async {
    TechniqueResult current = TechniqueResult(
      techniqueId: TechniqueId.nakedPair,
      eliminations: <Elimination>[Elimination(10, 5)],
      visual: VisualHint.assemble(patternCells: const <int>[11, 12]),
    );
    final (_, ProviderContainer container) = makeContainer(
      scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
          current,
    );
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);
    await ctrl.start('ch0_l02');

    expect((await ctrl.requestHint())!.level.order, 1);
    expect((await ctrl.requestHint())!.level.order, 2);

    current = TechniqueResult(
      techniqueId: TechniqueId.hiddenPair,
      eliminations: <Elimination>[Elimination(20, 7)],
      visual: VisualHint.assemble(patternCells: const <int>[19, 20]),
    );
    final HintState nextScene = (await ctrl.requestHint())!;

    expect(nextScene.level.order, 1, reason: '新结论应重新从一级解释');
    final PracticeState state = container.read(practiceControllerProvider)!;
    expect(state.unlockedHints, hasLength(1), reason: '不能混放上一结论的提示卡');
    expect(state.currentHint!.sceneFingerprint, nextScene.sceneFingerprint);
    expect(state.hintUsed, 3, reason: '三次成功请求仍应如实计数');
  });

  test('误操作 (a)：填错触发 wrongFill；同一错误 2 分钟内不重复弹', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);
    await ctrl.start('ch0_l02');

    // 选中 index10（终局解为 5），填 4。
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(4);

    var st = container.read(practiceControllerProvider)!;
    expect(st.lastMistake, isNotNull);
    expect(st.lastMistake!.type, MistakeType.wrongFill);
    expect(st.errorCount, 1);

    ctrl.acknowledgeMistake();
    expect(container.read(practiceControllerProvider)!.lastMistake, isNull);

    // 同一格同数字再填 → 2 分钟内去重，不弹不计数。
    ctrl.handleDigit(4);
    st = container.read(practiceControllerProvider)!;
    expect(st.lastMistake, isNull, reason: '2 分钟内同一错误不重复弹');
    expect(st.errorCount, 1, reason: '错误计数不因去重重复累加');
  });

  test('误操作 (c)：前置未满足但盘面可推理 → 不触发（推理出来不打扰）', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);
    await ctrl.start('ch0_l02');

    // 直接填目标技巧步的格 (10,5)：前置裸单 (5,6) 未就位，
    // 但当前盘面可凭 hiddenSingle 独立推出该格（有推理支撑）→ 不判抢先。
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(5);

    final PracticeState st = container.read(practiceControllerProvider)!;
    expect(st.lastMistake, isNull, reason: '盘面能推理推出该格时不应判「抢先填数」');
  });

  test('正常按脚本顺序推进：前置满足后填数不触发 (c)', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);
    await ctrl.start('ch0_l02');

    ctrl.handleSelectCell(5); // step1 裸单 (5,6)。
    ctrl.handleDigit(6);
    expect(container.read(practiceControllerProvider)!.lastMistake, isNull);

    ctrl.handleSelectCell(10); // step2 隐单 (10,5)，前置已满足。
    ctrl.handleDigit(5);
    expect(container.read(practiceControllerProvider)!.lastMistake, isNull);
    expect(container.read(practiceControllerProvider)!.errorCount, 0);
  });

  test('整盘解出 → recordCompletion（hintUsed/errorCount 真实采集）', () async {
    final (FakeProgressRepository repo, ProviderContainer container) =
        makeContainer();
    addTearDown(container.dispose);
    final PracticeController ctrl =
        container.read(practiceControllerProvider.notifier);
    await ctrl.start('ch0_l02');

    // 先制造一次错误（errorCount=1）。
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(4);
    ctrl.acknowledgeMistake();

    // 填满仅有的两个空格（其它为给定格）→ 整盘解出。
    ctrl.handleSelectCell(5);
    ctrl.handleDigit(6);
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(5);

    await ctrl.completeIfNeeded();
    await Future<void>.delayed(Duration.zero); // 等待事件触发的写档微任务。

    final LevelProgress progress = repo.current.levels['ch0_l02']!;
    expect(progress.status, LevelStatus.completed);
    expect(progress.hintUsed, 0, reason: '本局未用提示');
    expect(progress.errorCount, 1, reason: '错误次数真实采集');
    expect(container.read(practiceControllerProvider)!.completed, isTrue);
    expect(repo.teachingSnapshots['ch0_l02'], isNull, reason: '通关后清除本关断点');
  });
}
