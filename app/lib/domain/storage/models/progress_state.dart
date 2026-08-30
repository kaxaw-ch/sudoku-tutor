/// 存档根模型 `ProgressState`（P0-STO-03~05）。
///
/// 对应架构文档 §4.3 类图：进度 + 设置 + 错题本 + 统计的聚合根，
/// 携带 `schemaVersion`（迁移链入口）、`deviceId`、可空 `userId`/`profileId`
/// （P0-STO-05：本期不使用，仅预留字段，不引入账号体系与网络层）。
library;

import 'level_progress.dart';
import 'mistake_book.dart';
import 'practice_stats.dart';
import 'settings_models.dart';

/// 存档模型（不可变值对象）。
class ProgressState {
  /// 构造存档模型。
  const ProgressState({
    required this.schemaVersion,
    required this.deviceId,
    this.userId,
    this.profileId,
    this.levels = const <String, LevelProgress>{},
    this.settings = const SettingsState(),
    this.mistakeBook = const MistakeBook(),
    this.stats = const PracticeStats(),
    this.onboardingDone = false,
    this.lastSavedAt = 0,
  });

  /// 当前存档 schema 版本（迁移链目标版本）。
  final int schemaVersion;

  /// 设备标识（首启生成 UUIDv4，不采集任何硬件标识，架构 §7.7）。
  final String deviceId;

  /// 预留：可空用户标识（本期不使用）。
  final String? userId;

  /// 预留：可空档案标识（本期不使用）。
  final String? profileId;

  /// 关卡进度表（key = 关卡 ID）。
  final Map<String, LevelProgress> levels;

  /// 全局设置。
  final SettingsState settings;

  /// 错题本（P0 只采集不展示）。
  final MistakeBook mistakeBook;

  /// 练习统计（P0 只采集不展示）。
  final PracticeStats stats;

  /// 首启引导是否已完成（P0-UI-08）。
  final bool onboardingDone;

  /// 最近一次保存时间（epoch 毫秒，int UTC，架构 §7.7）。
  final int lastSavedAt;

  /// 返回替换部分字段后的副本。
  ProgressState copyWith({
    int? schemaVersion,
    String? deviceId,
    String? userId,
    String? profileId,
    Map<String, LevelProgress>? levels,
    SettingsState? settings,
    MistakeBook? mistakeBook,
    PracticeStats? stats,
    bool? onboardingDone,
    int? lastSavedAt,
  }) =>
      ProgressState(
        schemaVersion: schemaVersion ?? this.schemaVersion,
        deviceId: deviceId ?? this.deviceId,
        userId: userId ?? this.userId,
        profileId: profileId ?? this.profileId,
        levels: levels ?? this.levels,
        settings: settings ?? this.settings,
        mistakeBook: mistakeBook ?? this.mistakeBook,
        stats: stats ?? this.stats,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      );

  /// 序列化为 JSON map（顶层即存档文件结构）。
  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'deviceId': deviceId,
        if (userId != null) 'userId': userId,
        if (profileId != null) 'profileId': profileId,
        'levels': <String, Map<String, Object?>>{
          for (final MapEntry<String, LevelProgress> e in levels.entries)
            e.key: e.value.toJson(),
        },
        'settings': settings.toJson(),
        'mistakeBook': mistakeBook.toJson(),
        'stats': stats.toJson(),
        'onboardingDone': onboardingDone,
        'lastSavedAt': lastSavedAt,
      };

  /// 由 JSON map 反序列化（字段缺失按默认值容错）。
  factory ProgressState.fromJson(Map<String, Object?> json) {
    final Map<String, LevelProgress> levels = <String, LevelProgress>{};
    final Object? rawLevels = json['levels'];
    if (rawLevels is Map) {
      for (final MapEntry<Object?, Object?> e in rawLevels.entries) {
        levels[e.key! as String] =
            LevelProgress.fromJson(e.value! as Map<String, Object?>);
      }
    }
    final Object? rawSettings = json['settings'];
    return ProgressState(
      schemaVersion: (json['schemaVersion'] as int?) ?? 1,
      deviceId: (json['deviceId'] as String?) ?? '',
      userId: json['userId'] as String?,
      profileId: json['profileId'] as String?,
      levels: levels,
      settings: rawSettings is Map
          ? SettingsState.fromJson(rawSettings as Map<String, Object?>)
          : const SettingsState(),
      mistakeBook: json['mistakeBook'] is Map
          ? MistakeBook.fromJson(json['mistakeBook']! as Map<String, Object?>)
          : const MistakeBook(),
      stats: json['stats'] is Map
          ? PracticeStats.fromJson(json['stats']! as Map<String, Object?>)
          : const PracticeStats(),
      onboardingDone: (json['onboardingDone'] as bool?) ?? false,
      lastSavedAt: (json['lastSavedAt'] as int?) ?? 0,
    );
  }
}
