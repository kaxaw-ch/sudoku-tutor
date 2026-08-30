/// T-EDU-01 · 解锁服务与三态单测（P0-EDU-08/09）。
///
/// 覆盖：
/// - 索引中全部章节与关卡均可自由进入；
/// - 关卡状态只区分未通关 `unlocked` 与已通关 `completed`；
/// - `ChapterModel` 装配（进度 n/m、锁状态、关卡瓦片）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/chapter_model.dart';
import 'package:sudoku_tutor/domain/curriculum/unlock_service.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';

/// 构造两章索引：ch0 三关 + ch1 一关。
LevelIndex buildIndex() => LevelIndex(
      chapters: <ChapterEntry>[
        ChapterEntry(
          chapter: 0,
          title: '第 0 章',
          levels: <LevelEntry>[
            LevelEntry(
              id: 'ch0_l01',
              chapter: 0,
              order: 1,
              kind: LevelKind.demo,
              title: 'L1',
              file: 'ch0_l01.json',
            ),
            LevelEntry(
              id: 'ch0_l02',
              chapter: 0,
              order: 2,
              kind: LevelKind.guidedPractice,
              title: 'L2',
              file: 'ch0_l02.json',
            ),
            LevelEntry(
              id: 'ch0_l03',
              chapter: 0,
              order: 3,
              kind: LevelKind.trial,
              title: 'L3',
              file: 'ch0_l03.json',
            ),
          ],
        ),
        ChapterEntry(
          chapter: 1,
          title: '第 1 章',
          levels: <LevelEntry>[
            LevelEntry(
              id: 'ch1_l01',
              chapter: 1,
              order: 1,
              kind: LevelKind.demo,
              title: 'L1',
              file: 'ch1_l01.json',
            ),
          ],
        ),
      ],
    );

/// 干净存档（无任何完成记录）。
ProgressState cleanState() => const ProgressState(
      schemaVersion: 1,
      deviceId: 'device',
    );

/// 构造含指定完成关卡的存档。
ProgressState stateWith(Set<String> completedIds) {
  return ProgressState(
    schemaVersion: 1,
    deviceId: 'device',
    levels: <String, LevelProgress>{
      for (final String id in completedIds)
        id: LevelProgress(levelId: id, status: LevelStatus.completed, stars: 3),
    },
  );
}

void main() {
  final LevelIndex index = buildIndex();
  late UnlockService unlock;

  setUp(() {
    unlock = UnlockService(index: index);
  });

  group('章节自由选择', () {
    test('索引中的第 0 章与第 1 章始终可进入', () {
      expect(unlock.isChapterUnlocked(0, cleanState()), isTrue);
      expect(unlock.isChapterUnlocked(1, cleanState()), isTrue);
    });

    test('不存在的章节仍不可进入', () {
      expect(unlock.isChapterUnlocked(99, cleanState()), isFalse);
    });
  });

  group('关卡自由选择与状态', () {
    test('干净存档中所有已登记关卡均为 unlocked', () {
      for (final String id in <String>[
        'ch0_l01',
        'ch0_l02',
        'ch0_l03',
        'ch1_l01',
      ]) {
        expect(unlock.statusOf(id, cleanState()), LevelStatus.unlocked);
      }
    });

    test('已完成的关 → completed（覆盖任何解锁状态）', () {
      expect(
        unlock.statusOf('ch0_l01', stateWith(<String>{'ch0_l01'})),
        LevelStatus.completed,
      );
    });

    test('未登记关卡 → locked', () {
      expect(unlock.statusOf('nope', cleanState()), LevelStatus.locked);
    });
  });

  group('ChapterModel 装配', () {
    test('进度 n/m 与锁状态正确', () {
      final ChapterModel model = ChapterModel.build(
        entry: index.chapters[0],
        progress: stateWith(<String>{'ch0_l01'}),
        unlock: unlock,
      );
      expect(model.isUnlocked, isTrue);
      expect(model.progressLabel, '1/3');
      expect(model.totalCount, 3);
      expect(model.completedCount, 1);
      expect(model.isComplete, isFalse);
      expect(model.levels, hasLength(3));
      expect(model.levels[0].status, LevelStatus.completed);
      expect(model.levels[1].status, LevelStatus.unlocked);
      expect(model.levels[2].status, LevelStatus.unlocked);
    });

    test('全章完成 → isComplete=true', () {
      final ChapterModel model = ChapterModel.build(
        entry: index.chapters[0],
        progress: stateWith(<String>{'ch0_l01', 'ch0_l02', 'ch0_l03'}),
        unlock: unlock,
      );
      expect(model.isComplete, isTrue);
      expect(model.progressLabel, '3/3');
    });

    test('buildAll 装配全部章节且全部可进入', () {
      final List<ChapterModel> models = ChapterModel.buildAll(
        index: index,
        progress: stateWith(<String>{'ch0_l01', 'ch0_l02', 'ch0_l03'}),
        unlock: unlock,
      );
      expect(models, hasLength(2));
      expect(models[0].isUnlocked, isTrue);
      expect(models[1].isUnlocked, isTrue, reason: '章节不再受前置进度限制');
    });
  });
}
