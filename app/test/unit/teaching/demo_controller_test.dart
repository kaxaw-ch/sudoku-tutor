/// T-EDU-02 · 原理演示关控制器单测。
///
/// 覆盖：播放状态机（next/previous/replay/自动播放切换/进度 n/m）、
/// 首次完整看完落盘（recordCompletion：hintUsed=0、errorCount=0）、
/// seenBefore（之后可跳过）、空脚本防御、完成幂等。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/teaching/demo_controller.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

/// 装配容器并返回 (仓库, 容器)，测试可断言写档结果。
(FakeProgressRepository, ProviderContainer) makeContainer({
  FakeProgressRepository? repo,
  Map<String, String>? levels,
}) {
  final FakeProgressRepository progress = repo ?? FakeProgressRepository();
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      progressRepositoryProvider.overrideWith((Ref ref) async => progress),
      curriculumRepositoryProvider.overrideWithValue(
        CurriculumRepository(
          loader: buildTeachingCurriculumLoader(
            levelJsonById: levels ?? buildDefaultTeachingLevels(),
          ),
        ),
      ),
    ],
  );
  return (progress, container);
}

void main() {
  test('start：加载两步演示关，进度 1/2，首次须看完', () async {
    final (FakeProgressRepository repo, ProviderContainer container) =
        makeContainer();
    addTearDown(container.dispose);

    final DemoController ctrl = container.read(demoControllerProvider.notifier);
    await ctrl.start('ch0_l01');

    final DemoState st = container.read(demoControllerProvider)!;
    expect(st.stepCount, 2);
    expect(st.progress, 1, reason: '初始展示第 1 步');
    expect(st.completed, isFalse);
    expect(st.seenBefore, isFalse);
    expect(st.mustWatchToEnd, isTrue, reason: '首次进入须完整看完');
    expect(st.currentStep.techniqueId, TechniqueId.nakedSingle);
    // 进入次数已落盘。
    expect(repo.current.levels['ch0_l01']!.attempts, 1);
  });

  test('看完最后一步即算完成并写档（hintUsed=0、errorCount=0）', () async {
    final (FakeProgressRepository repo, ProviderContainer container) =
        makeContainer();
    addTearDown(container.dispose);

    final DemoController ctrl = container.read(demoControllerProvider.notifier);
    await ctrl.start('ch0_l01');
    await ctrl.next();

    final DemoState st = container.read(demoControllerProvider)!;
    expect(st.progress, 2);
    expect(st.completed, isTrue, reason: '看完最后一步即算完成');
    expect(st.mustWatchToEnd, isFalse, reason: '完成后可退出');
    final LevelProgress progress = repo.current.levels['ch0_l01']!;
    expect(progress.status, LevelStatus.completed);
    expect(progress.hintUsed, 0);
    expect(progress.errorCount, 0);
    expect(progress.stars, 3);
    // attempts = 1 次进入（recordEntry）+ 1 次完成（recordCompletion）。
    expect(progress.attempts, 2);
    // 幂等：再次 next 不重复写档（attempts 不再 +1）。
    await ctrl.next();
    expect(repo.current.levels['ch0_l01']!.attempts, 2);
  });

  test('再次进入 seenBefore=true，可直接跳过（不拦截）', () async {
    final (_, ProviderContainer container) = makeContainer(
      repo: FakeProgressRepository(
        initial: const ProgressState(
          schemaVersion: 1,
          deviceId: 'd',
          levels: <String, LevelProgress>{
            'ch0_l01': LevelProgress(
              levelId: 'ch0_l01',
              status: LevelStatus.completed,
              stars: 3,
            ),
          },
        ),
      ),
    );
    addTearDown(container.dispose);

    final DemoController ctrl = container.read(demoControllerProvider.notifier);
    await ctrl.start('ch0_l01');

    final DemoState st = container.read(demoControllerProvider)!;
    expect(st.seenBefore, isTrue);
    expect(st.mustWatchToEnd, isFalse, reason: '已看过，之后可跳过');
  });

  test('previous / replay：回看上一步、重播回到第 1 步并清除完成标记', () async {
    final (FakeProgressRepository repo, ProviderContainer container) =
        makeContainer();
    addTearDown(container.dispose);
    final DemoController ctrl = container.read(demoControllerProvider.notifier);

    await ctrl.start('ch0_l01');
    await ctrl.next(); // → 第 2 步（最后一步），completed=true
    expect(container.read(demoControllerProvider)!.completed, isTrue);

    ctrl.previous(); // 回看第 1 步
    var st = container.read(demoControllerProvider)!;
    expect(st.progress, 1);
    expect(st.completed, isTrue, reason: '完成状态不回退');

    ctrl.replay();
    st = container.read(demoControllerProvider)!;
    expect(st.progress, 1);
    expect(st.completed, isFalse, reason: '重播视为重新观看');
    expect(st.autoPlaying, isFalse);

    // 重播后再看完仍可写档（attempts：进入1 + 首次完成1 + 重播完成1 = 3）。
    await ctrl.next();
    expect(container.read(demoControllerProvider)!.completed, isTrue);
    expect(repo.current.levels['ch0_l01']!.attempts, 3);
  });

  test('toggleAutoPlay：切换 2s/步自动播放；stopAutoPlay 停止', () async {
    final (_, ProviderContainer container) = makeContainer();
    addTearDown(container.dispose);
    final DemoController ctrl = container.read(demoControllerProvider.notifier);

    await ctrl.start('ch0_l01');
    ctrl.toggleAutoPlay();
    expect(container.read(demoControllerProvider)!.autoPlaying, isTrue);

    ctrl.toggleAutoPlay();
    expect(container.read(demoControllerProvider)!.autoPlaying, isFalse);

    ctrl.toggleAutoPlay();
    ctrl.stopAutoPlay();
    expect(container.read(demoControllerProvider)!.autoPlaying, isFalse);
  });

  test('空脚本防御：start 后直接视为完成并写档', () async {
    final Map<String, String> levels = buildDefaultTeachingLevels();
    levels['assets/curriculum/ch0_l01.json'] = buildTeachingLevelJson(
      id: 'ch0_l01',
      kind: 'demo',
      steps: const <Map<String, Object?>>[],
    );
    final (FakeProgressRepository repo, ProviderContainer container) =
        makeContainer(levels: levels);
    addTearDown(container.dispose);

    final DemoController ctrl = container.read(demoControllerProvider.notifier);
    await ctrl.start('ch0_l01');

    final DemoState st = container.read(demoControllerProvider)!;
    expect(st.stepCount, 0);
    expect(st.completed, isTrue);
    expect(repo.current.levels['ch0_l01']!.status, LevelStatus.completed);
  });
}
