/// 练习统计原始数据（P2-STAT-01 的**采集侧**）。
///
/// P0 只采集不展示（P0-STO-03），由 `domain/stats/stats_collector.dart`
/// （T-DOM-06）真实写入，批次 H 的统计看板直接消费本模型，无需迁移。
///
/// 难度档以 `Difficulty.id` 字符串存储（见 `sudoku_core` 的
/// `grading/difficulty.dart`），本文件刻意不依赖 core，保持纯数据。
library;

/// 一局自由练习的原始记录。
class PracticeRecord {
  /// 构造一局记录。
  const PracticeRecord({
    required this.difficultyId,
    required this.startedAt,
    required this.durationMs,
    this.hintCount = 0,
    this.errorCount = 0,
    this.completed = false,
  });

  /// 难度档（`Difficulty.id` 字符串，保持纯数据）。
  final String difficultyId;

  /// 开局时间（epoch 毫秒）。
  final int startedAt;

  /// 本局用时（毫秒）。
  final int durationMs;

  /// 提示次数。
  final int hintCount;

  /// 错误次数。
  final int errorCount;

  /// 是否完成（完整解出）。
  final bool completed;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'difficultyId': difficultyId,
        'startedAt': startedAt,
        'durationMs': durationMs,
        'hintCount': hintCount,
        'errorCount': errorCount,
        'completed': completed,
      };

  /// 由 JSON map 反序列化。
  factory PracticeRecord.fromJson(Map<String, Object?> json) => PracticeRecord(
        difficultyId: json['difficultyId']! as String,
        startedAt: (json['startedAt'] as int?) ?? 0,
        durationMs: (json['durationMs'] as int?) ?? 0,
        hintCount: (json['hintCount'] as int?) ?? 0,
        errorCount: (json['errorCount'] as int?) ?? 0,
        completed: (json['completed'] as bool?) ?? false,
      );
}

/// 练习统计聚合（按难度维度，P2-STAT-01 消费）。
///
/// ⚠️ 值对象约定：构造后请勿修改 [records]（不可变性由约定保证，
/// 换取 const 构造可用）。
class PracticeStats {
  /// 构造统计。
  const PracticeStats({
    this.records = const <PracticeRecord>[],
    this.completedGames = 0,
    this.totalGames = 0,
    this.totalDurationMs = 0,
    this.totalHints = 0,
    this.totalErrors = 0,
  });

  /// 原始局记录（供看板分难度/时间维度重算）。
  final List<PracticeRecord> records;

  /// 完成局数。
  final int completedGames;

  /// 总局数。
  final int totalGames;

  /// 累计用时（毫秒）。
  final int totalDurationMs;

  /// 累计提示次数。
  final int totalHints;

  /// 累计错误次数。
  final int totalErrors;

  /// 完成率（无局时为 0）。
  double get completionRate =>
      totalGames == 0 ? 0 : completedGames / totalGames;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'records': <Map<String, Object?>>[
          for (final PracticeRecord r in records) r.toJson(),
        ],
        'completedGames': completedGames,
        'totalGames': totalGames,
        'totalDurationMs': totalDurationMs,
        'totalHints': totalHints,
        'totalErrors': totalErrors,
      };

  /// 由 JSON map 反序列化（`Difficulty` 仅用于校验难度 ID 合法性）。
  factory PracticeStats.fromJson(Map<String, Object?> json) {
    final Object? raw = json['records'];
    final List<PracticeRecord> records = <PracticeRecord>[
      if (raw is List)
        for (final Object? item in raw)
          PracticeRecord.fromJson(item! as Map<String, Object?>),
    ];
    // 容错：难读的聚合值重算，避免被脏数据带偏。
    int completed = 0;
    int totalMs = 0;
    int hints = 0;
    int errors = 0;
    for (final PracticeRecord r in records) {
      if (r.completed) {
        completed++;
      }
      totalMs += r.durationMs;
      hints += r.hintCount;
      errors += r.errorCount;
    }
    return PracticeStats(
      records: records,
      completedGames: (json['completedGames'] as int?) ?? completed,
      totalGames: (json['totalGames'] as int?) ?? records.length,
      totalDurationMs: (json['totalDurationMs'] as int?) ?? totalMs,
      totalHints: (json['totalHints'] as int?) ?? hints,
      totalErrors: (json['totalErrors'] as int?) ?? errors,
    );
  }
}
