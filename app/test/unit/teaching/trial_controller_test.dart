/// T-EDU-05 · 验收试炼关控制器单测。
///
/// 覆盖：
/// - 从题池抽题，目标技巧展示（题池标注 ∪ 关卡标签）；
/// - **专项测试：不校验玩家是否使用目标技巧** —— 用普通填数（非技巧方式）
///   解完整盘也判通过（C-06：通关 = 完整解出整盘）；
/// - 不限次数、不重置整关（错误保留盘面）；
/// - 连续失败 3 次弹出「回看原理演示」入口（reviewDemoLevelId=同章演示关）；
/// - 继续挑战后收起入口、失败计数清零。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_bank_repository.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/domain/teaching/trial_controller.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

/// 构造试炼池（含 2 空格题目，techniques 标注目标技巧 hiddenSingle）。
TrialPool buildTrialPool() => TrialPool(
      chapter: 0,
      targetTechniques: const <TechniqueId>{TechniqueId.hiddenSingle},
      puzzles: <Puzzle>[
        Puzzle(
          given: <int>[
            for (final String ch in kTeachingPuzzle81.split(''))
              ch == '.' ? 0 : int.parse(ch),
          ],
          solution: <int>[
            for (final String ch in kTeachingSolution81.split(''))
              int.parse(ch),
          ],
          techniques: const <TechniqueId>{TechniqueId.hiddenSingle},
        ),
      ],
    );

void main() {
  (FakeProgressRepository, ProviderContainer) makeContainer() {
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
        puzzleBankRepositoryProvider.overrideWithValue(
          FakePuzzleBankRepository(pool: buildTrialPool()),
        ),
      ],
    );
    return (repo, container);
  }

  test('start：从题池抽题，目标技巧 = 题池标注 ∪ 关卡标签', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final TrialController ctrl =
        container.read(trialControllerProvider.notifier);

    await ctrl.start('ch0_l03');

    final TrialState st = container.read(trialControllerProvider)!;
    expect(st.level.id, 'ch0_l03');
    expect(st.puzzle.solutionString, kTeachingSolution81, reason: '盘面来自题池');
    expect(st.targetTechniques, contains(TechniqueId.hiddenSingle));
    expect(st.targetTechniqueLabel, contains('隐性唯一数'));
    expect(st.completed, isFalse);
  });

  test('专项：不校验玩家是否使用目标技巧 —— 普通填数解完也判通过', () async {
    final (FakeProgressRepository repo, ProviderContainer container) =
        makeContainer();
    addTearDown(container.dispose);
    final TrialController ctrl =
        container.read(trialControllerProvider.notifier);
    await ctrl.start('ch0_l03');

    // 玩家用最朴素的「直接填数」方式（不使用任何技巧识别流程）填满仅有的
    // 两个空格（其余为给定格）。C-06：系统不校验是否使用了目标技巧。
    ctrl.handleSelectCell(5);
    ctrl.handleDigit(6);
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(5);

    await ctrl.completeIfNeeded();
    await Future<void>.delayed(Duration.zero);

    final TrialState st = container.read(trialControllerProvider)!;
    expect(st.completed, isTrue, reason: '完整解出整盘即通关');
    final LevelProgress progress = repo.current.levels['ch0_l03']!;
    expect(progress.status, LevelStatus.completed);
    expect(progress.hintUsed, 0, reason: '试炼关无提示');
  });

  test('连续失败 3 次 → 弹出回看原理演示入口（同章演示关）', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final TrialController ctrl =
        container.read(trialControllerProvider.notifier);
    await ctrl.start('ch0_l03');

    // 三个不同错误（2 分钟内同指纹会被去重，因此用不同格/数字）。
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(4); // 错误 1
    expect(container.read(trialControllerProvider)!.consecutiveFailures, 1);

    ctrl.handleSelectCell(5);
    ctrl.handleDigit(7); // 错误 2
    expect(container.read(trialControllerProvider)!.consecutiveFailures, 2);

    ctrl.handleSelectCell(10);
    ctrl.handleDigit(3); // 错误 3
    final TrialState st = container.read(trialControllerProvider)!;
    expect(st.consecutiveFailures, 3);
    expect(st.showReviewOffer, isTrue, reason: '连续失败 3 次触发回看入口');
    expect(st.reviewDemoLevelId, 'ch0_l01', reason: '同章第一个演示关');
    expect(st.errorCount, 3);
  });

  test('继续挑战：收起回看入口并清零失败计数', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final TrialController ctrl =
        container.read(trialControllerProvider.notifier);
    await ctrl.start('ch0_l03');

    ctrl.handleSelectCell(10);
    ctrl.handleDigit(4);
    ctrl.handleSelectCell(5);
    ctrl.handleDigit(7);
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(3);
    expect(container.read(trialControllerProvider)!.showReviewOffer, isTrue);

    ctrl.acknowledgeReviewOffer();
    final TrialState st = container.read(trialControllerProvider)!;
    expect(st.showReviewOffer, isFalse);
    expect(st.consecutiveFailures, 0);
  });

  test('错误不重置整关：错误填写保留在盘面上', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final TrialController ctrl =
        container.read(trialControllerProvider.notifier);
    await ctrl.start('ch0_l03');

    ctrl.handleSelectCell(10);
    ctrl.handleDigit(4); // 填错，盘面保留 4。

    final GameSession? session = container.read(gameSessionControllerProvider);
    expect(session, isNotNull);
    expect(session!.board.valueAt(10), 4, reason: '不限次数不重置整关，错误保留');
    expect(session.board.isFull, isFalse);
  });
}
