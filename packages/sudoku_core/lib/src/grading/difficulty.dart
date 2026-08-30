/// 五档难度枚举（PRD §6.1 / doc 00 R-07）。
///
/// 说明：本文件按 doc 07 属 T-CORE-08（批次 C），但 `Technique` 接口的
/// `difficulty` 字段强依赖它，故在批次 B 提前落地**仅枚举部分**；
/// `difficulty_grader.dart`（分级算法）仍留待批次 C。
library;

/// 谜题/技巧难度档位（升序）。
enum Difficulty {
  /// 入门。
  beginner('beginner', '入门'),

  /// 简单。
  easy('easy', '简单'),

  /// 中等。
  medium('medium', '中等'),

  /// 困难。
  hard('hard', '困难'),

  /// 大师。
  master('master', '大师');

  const Difficulty(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文档位名。
  final String zhName;

  /// 档位序（0 起，越大越难）。
  int get order => index;

  /// 是否比 [other] 更难。
  bool isHarderThan(Difficulty other) => index > other.index;

  /// 按 [id] 反查；未知返回 `null`。
  static Difficulty? tryParse(String id) {
    for (final Difficulty value in Difficulty.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  /// 取两者中更难的一档。
  static Difficulty max(Difficulty a, Difficulty b) => a.index >= b.index ? a : b;
}
