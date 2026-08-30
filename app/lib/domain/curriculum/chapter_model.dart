/// 章节视图模型（T-EDU-01 / P0-EDU-08）。
///
/// 把 core 的 [ChapterEntry]/[LevelEntry] 与存档进度（[ProgressState]）
/// 装配成 UI 可直接消费的「章节卡片 + 关卡格栅」数据：
/// - 章级：技巧标签、进度 `n/m`；
/// - 关级：主技巧、关卡类型、完成状态与星数。
library;

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/unlock_service.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';

/// 关卡格栅中的一张小关卡信息卡。
class LevelTile {
  /// 构造关卡瓦片。
  const LevelTile({
    required this.entry,
    required this.status,
    required this.stars,
  });

  /// 关卡登记（来自索引）。
  final LevelEntry entry;

  /// 三态（未解锁/已解锁未完成/已完成）。
  final LevelStatus status;

  /// 星数 0..3（仅 completed 时 >0）。
  final int stars;

  /// 是否已完成。
  bool get isCompleted => status == LevelStatus.completed;

  /// 课程采用自由选关，索引内的关卡始终可进入。
  bool get isUnlocked => true;

  /// 本关主技巧：取技巧标签中级别最高的一项。
  ///
  /// 索引会同时携带解题所需的前置技巧，最高级技巧与关卡标题中的教学目标
  /// 一致；标签为空时由 UI 回退显示关卡标题。
  TechniqueId? get primaryTechnique {
    for (final TechniqueId id in TechniqueId.values.reversed) {
      if (entry.techniqueTags.contains(id)) {
        return id;
      }
    }
    return null;
  }

  /// 供选关卡直接展示的技巧名称。
  String get techniqueLabel => primaryTechnique?.zhName ?? entry.title;

  /// 供选关卡直接展示的完整类型名称。
  String get typeLabel => switch (entry.kind) {
        LevelKind.demo => '教学演示',
        LevelKind.guidedPractice => '引导实操',
        LevelKind.trial => '综合试炼',
      };

  @override
  String toString() => 'LevelTile(${entry.id}, ${status.id}, ★$stars)';
}

/// 章节视图模型。
class ChapterModel {
  /// 构造章节模型。
  ChapterModel({
    required this.entry,
    required this.isUnlocked,
    required List<LevelTile> levels,
  }) : levels = List<LevelTile>.unmodifiable(levels);

  /// 章节登记（来自索引）。
  final ChapterEntry entry;

  /// 本章是否可进入（课程索引中的章节恒为 true，保留字段供旧调用方兼容）。
  final bool isUnlocked;

  /// 章内关卡瓦片（按 `order` 升序）。
  final List<LevelTile> levels;

  /// 章号。
  int get chapter => entry.chapter;

  /// 章标题（索引未提供时按章号生成）。
  String get title => entry.title ?? '第 ${entry.chapter + 1} 章';

  /// 本章目标技巧标签。
  Set<TechniqueId> get techniqueTags => entry.techniqueTags;

  /// 已完成的关卡数。
  int get completedCount => levels.where((LevelTile t) => t.isCompleted).length;

  /// 关卡总数。
  int get totalCount => levels.length;

  /// 进度 `n/m` 中的 n。
  int get progressCount => completedCount;

  /// 进度是否 100%。
  bool get isComplete => completedCount >= totalCount && totalCount > 0;

  /// 进度文本（如 `2/5`）。
  String get progressLabel => '$completedCount/$totalCount';

  @override
  String toString() => 'ChapterModel(ch$chapter, $progressLabel, '
      'unlocked=$isUnlocked)';

  // ------------------------------------------------------------ 装配

  /// 由索引章 + 存档进度装配章节模型。
  static ChapterModel build({
    required ChapterEntry entry,
    required ProgressState progress,
    required UnlockService unlock,
  }) {
    final List<LevelTile> tiles = <LevelTile>[
      for (final LevelEntry level in entry.levels)
        LevelTile(
          entry: level,
          status: unlock.statusOf(level.id, progress),
          stars: progress.levels[level.id]?.stars ?? 0,
        ),
    ];
    return ChapterModel(
      entry: entry,
      isUnlocked: unlock.isChapterUnlocked(entry.chapter, progress),
      levels: tiles,
    );
  }

  /// 由全部索引章装配全部章节模型。
  static List<ChapterModel> buildAll({
    required LevelIndex index,
    required ProgressState progress,
    required UnlockService unlock,
  }) =>
      <ChapterModel>[
        for (final ChapterEntry entry in index.chapters)
          ChapterModel.build(
            entry: entry,
            progress: progress,
            unlock: unlock,
          ),
      ];
}
