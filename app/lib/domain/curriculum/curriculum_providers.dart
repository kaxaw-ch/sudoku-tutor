/// 课程 Riverpod Providers（T-EDU-01 / P0-EDU-01/08/09）。
///
/// 手写 Provider（不用 codegen，架构 §7.1）：
/// - [curriculumRepositoryProvider] —— 课程仓库（rootBundle 读 assets）；
/// - [curriculumIndexProvider] —— 课程索引（`Future`：首次加载）；
/// - [curriculumStateProvider] —— 课程视图状态（索引 + 存档进度 →
///   各章进度/锁状态/关卡三态，T-EDU-06 学习地图直接消费）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/core/core.dart';

import '../session/session_providers.dart';
import '../storage/models/level_progress.dart';
import '../storage/models/progress_state.dart';
import '../storage/progress_repository.dart';
import 'chapter_model.dart';
import 'curriculum_repository.dart';
import 'unlock_service.dart';

/// 课程仓库（默认 rootBundle 读 assets/curriculum）。
final Provider<CurriculumRepository> curriculumRepositoryProvider =
    Provider<CurriculumRepository>(
  (Ref ref) => CurriculumRepository(),
);

/// 课程索引（异步加载）。
final FutureProvider<LevelIndex> curriculumIndexProvider =
    FutureProvider<LevelIndex>(
  (Ref ref) => ref.watch(curriculumRepositoryProvider).loadIndex(),
);

/// 课程视图状态：索引 + 进度 → 章节模型列表（含三态）。
///
/// ⚠️ 本 provider 缓存存档快照：**所有写档点**（关卡完成三处控制器、
/// 设置页重置/导入）都必须 `ref.invalidate(curriculumStateProvider)`
/// 强制重算，学习地图（T-EDU-06）才能拿到最新解锁/星数/进度。
/// 不用 `autoDispose`（riverpod 的 autoDispose FutureProvider 在
/// invalidate 后 dispose 会抛 `Future already completed`——测试与
/// 运行时均已踩坑）。
final FutureProvider<CurriculumState> curriculumStateProvider =
    FutureProvider<CurriculumState>((Ref ref) async {
  final LevelIndex index = await ref.watch(curriculumIndexProvider.future);
  final ProgressRepository repository =
      await ref.watch(progressRepositoryProvider.future);
  final ProgressState progress = await repository.load();
  final UnlockService unlock = UnlockService(index: index);
  return CurriculumState(
    index: index,
    progress: progress,
    chapters: ChapterModel.buildAll(
      index: index,
      progress: progress,
      unlock: unlock,
    ),
  );
});

/// 课程视图状态（不可变聚合）。
class CurriculumState {
  /// 构造课程状态。
  CurriculumState({
    required this.index,
    required this.progress,
    required List<ChapterModel> chapters,
  }) : chapters = List<ChapterModel>.unmodifiable(chapters);

  /// 课程索引。
  final LevelIndex index;

  /// 当前存档进度（快照）。
  final ProgressState progress;

  /// 章节模型列表（按索引顺序）。
  final List<ChapterModel> chapters;

  /// 取某章的模型；不存在返回 `null`。
  ChapterModel? chapterOf(int chapter) {
    for (final ChapterModel model in chapters) {
      if (model.chapter == chapter) {
        return model;
      }
    }
    return null;
  }

  /// 取某关的三态；未登记返回 `locked`。
  LevelStatus statusOf(String levelId) {
    for (final ChapterModel chapter in chapters) {
      for (final LevelTile tile in chapter.levels) {
        if (tile.entry.id == levelId) {
          return tile.status;
        }
      }
    }
    return LevelStatus.locked;
  }

  /// 取某关的星数；未完成/未登记返回 0。
  int starsOf(String levelId) {
    for (final ChapterModel chapter in chapters) {
      for (final LevelTile tile in chapter.levels) {
        if (tile.entry.id == levelId) {
          return tile.stars;
        }
      }
    }
    return 0;
  }

  /// 全部章节的关卡总数。
  int get totalLevels =>
      chapters.fold<int>(0, (int sum, ChapterModel c) => sum + c.totalCount);

  /// 已完成的关卡总数。
  int get completedLevels => chapters.fold<int>(
      0, (int sum, ChapterModel c) => sum + c.completedCount);
}
