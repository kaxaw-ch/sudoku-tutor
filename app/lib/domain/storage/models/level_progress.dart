/// 关卡进度模型（P0-STO-03 存档内容之一）。
///
/// 对应架构文档 §4.3 类图中的 `LevelProgress` / `LevelStatus`：
/// 三态（未解锁 / 已解锁 / 已完成）+ 教学关采集字段（P0-EDU-09，
/// 从 P0 起真实采集，供批次 G/H 的错题本与成就系统消费）。
library;

/// 关卡状态（三态）。
enum LevelStatus {
  /// 未解锁（前置未满足，UI 置灰）。
  locked('locked', '未解锁'),

  /// 已解锁但尚未完成。
  unlocked('unlocked', '已解锁'),

  /// 已完成（含全部星级判定）。
  completed('completed', '已完成');

  const LevelStatus(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文语义名。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static LevelStatus? tryParse(String id) {
    for (final LevelStatus value in LevelStatus.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 一关的进度记录（不可变值对象）。
class LevelProgress {
  /// 构造进度记录。
  const LevelProgress({
    required this.levelId,
    this.status = LevelStatus.locked,
    this.stars = 0,
    this.hintUsed = 0,
    this.errorCount = 0,
    this.durationMs = 0,
    this.attempts = 0,
    this.lastPlayedAt = 0,
  });

  /// 关卡 ID（对应课程 `index.json` 中的登记项）。
  final String levelId;

  /// 三态。
  final LevelStatus status;

  /// 星级（0..3，P2-ACH-01 消费）。
  final int stars;

  /// 累计提示次数（P2-ACH-02 消费）。
  final int hintUsed;

  /// 累计错误次数（P0-EDU-04 / 错题本触发条件消费）。
  final int errorCount;

  /// 累计用时（毫秒，int UTC 口径，架构 §7.7）。
  final int durationMs;

  /// 进入次数。
  final int attempts;

  /// 最近一次进入时间（epoch 毫秒；0 = 从未进入）。
  final int lastPlayedAt;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'levelId': levelId,
        'status': status.id,
        'stars': stars,
        'hintUsed': hintUsed,
        'errorCount': errorCount,
        'durationMs': durationMs,
        'attempts': attempts,
        'lastPlayedAt': lastPlayedAt,
      };

  /// 由 JSON map 反序列化；状态缺失/未知时按 `locked` 容错（迁移链的兜底）。
  factory LevelProgress.fromJson(Map<String, Object?> json) => LevelProgress(
        levelId: json['levelId']! as String,
        status: json['status'] is String
            ? LevelStatus.tryParse(json['status']! as String) ??
                LevelStatus.locked
            : LevelStatus.locked,
        stars: (json['stars'] as int?) ?? 0,
        hintUsed: (json['hintUsed'] as int?) ?? 0,
        errorCount: (json['errorCount'] as int?) ?? 0,
        durationMs: (json['durationMs'] as int?) ?? 0,
        attempts: (json['attempts'] as int?) ?? 0,
        lastPlayedAt: (json['lastPlayedAt'] as int?) ?? 0,
      );
}
