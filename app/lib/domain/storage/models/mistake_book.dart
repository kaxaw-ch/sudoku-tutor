/// 错题本数据结构（P1-WRG-01 的**采集侧**）。
///
/// P0 只采集不展示（P0-STO-03 / P0-STO-08「清空错题本」入口），
/// 批次 G 的 `T-WRG-01` 负责收录/移出/容量淘汰逻辑，本文件只提供
/// 存档字段与 JSON 编解码，保证「P0 起真实采集、P1 免迁移」。
library;

/// 一条错题记录。
class MistakeEntry {
  /// 构造错题记录。
  const MistakeEntry({
    required this.levelId,
    this.errorCount = 0,
    this.trialFailCount = 0,
    this.lastMistakeAt = 0,
  });

  /// 出错的关卡 ID（重玩原关卡原盘面，T-WRG-01）。
  final String levelId;

  /// 同关错误次数（触发阈值 `kMistakeBookErrorThreshold = 2`）。
  final int errorCount;

  /// 试炼失败次数（触发阈值 `kMistakeBookTrialFailThreshold = 1`）。
  final int trialFailCount;

  /// 最近一次出错时间（epoch 毫秒）。
  final int lastMistakeAt;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'levelId': levelId,
        'errorCount': errorCount,
        'trialFailCount': trialFailCount,
        'lastMistakeAt': lastMistakeAt,
      };

  /// 由 JSON map 反序列化。
  factory MistakeEntry.fromJson(Map<String, Object?> json) => MistakeEntry(
        levelId: json['levelId']! as String,
        errorCount: (json['errorCount'] as int?) ?? 0,
        trialFailCount: (json['trialFailCount'] as int?) ?? 0,
        lastMistakeAt: (json['lastMistakeAt'] as int?) ?? 0,
      );
}

/// 错题本容器（上限 100 条淘汰最旧，由批次 G 消费）。
///
/// ⚠️ 值对象约定：构造后请勿修改 [entries]（不可变性由约定保证，
/// 换取 const 构造可用，使 `ProgressState` 默认值保持 const）。
class MistakeBook {
  /// 构造错题本。
  const MistakeBook({this.entries = const <MistakeEntry>[]});

  /// 全部错题（按收录先后）。
  final List<MistakeEntry> entries;

  /// 条目数。
  int get length => entries.length;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'entries': <Map<String, Object?>>[
          for (final MistakeEntry e in entries) e.toJson(),
        ],
      };

  /// 由 JSON map 反序列化。
  factory MistakeBook.fromJson(Map<String, Object?> json) {
    final Object? raw = json['entries'];
    if (raw is! List) {
      return const MistakeBook();
    }
    return MistakeBook(
      entries: <MistakeEntry>[
        for (final Object? item in raw)
          MistakeEntry.fromJson(item! as Map<String, Object?>),
      ],
    );
  }
}
