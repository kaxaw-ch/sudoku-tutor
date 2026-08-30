/// 解锁服务（T-EDU-01 / P0-EDU-08，三态 P0-EDU-09）。
///
/// 课程采用自由选关：索引中登记的全部章节、关卡始终可进入。
/// 通关进度只负责 `completed` 状态与星级展示，不再作为后续内容的门槛。
///
/// 三态判定（P0-EDU-09）：
/// - `completed`：存档中该关 `status == completed`；
/// - `unlocked`：已解锁但未完成；
/// - `locked`：其余。
library;

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';

/// 解锁服务。
class UnlockService {
  /// 构造解锁服务；[index] 为课程索引（提供章节与关卡登记）。
  UnlockService({required LevelIndex index}) : _index = index;

  final LevelIndex _index;

  /// 课程索引（只读访问，供 UI/测试查询）。
  LevelIndex get index => _index;

  // ------------------------------------------------------------ 章节

  /// 章节是否可进入：只要在课程索引中登记即为可进入。
  bool isChapterUnlocked(int chapter, ProgressState progress) {
    return _index.chapters
        .any((ChapterEntry entry) => entry.chapter == chapter);
  }

  // ------------------------------------------------------------ 关卡

  /// 关卡是否可进入：索引中登记的关卡全部可自由选择。
  bool isLevelUnlocked(String levelId, ProgressState progress) {
    return _index.byId(levelId) != null;
  }

  /// 关卡三态（P0-EDU-09）。
  LevelStatus statusOf(String levelId, ProgressState progress) {
    if (isCompleted(levelId, progress)) {
      return LevelStatus.completed;
    }
    return isLevelUnlocked(levelId, progress)
        ? LevelStatus.unlocked
        : LevelStatus.locked;
  }

  /// 该关是否已在存档中标记完成。
  bool isCompleted(String levelId, ProgressState progress) =>
      progress.levels[levelId]?.status == LevelStatus.completed;
}
