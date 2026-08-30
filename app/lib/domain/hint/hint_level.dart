/// 提示级别模型（P0-PRA-04 / P0-EDU-04，T-DOM-05）。
///
/// 约定：
/// - 提示级别 = 「逐步逼近结论」的三级阶梯，**必须逐级解锁、不可跳级**；
/// - 自由练习仅开放两级（一级=指出可用技巧并高亮区域；二级=点明关键格）；
/// - 教学开放三级（再增三级=给出删数结论，仍是候选删除，不是填数）；
/// - **任何级别都不告知某格填几**（无 Placement 直出，专项测试断言）。
library;

/// 提示级别。
enum HintLevel {
  /// 一级：指出可用技巧并高亮区域。
  level1('level1', '一级'),

  /// 二级：点明关键格（不填数）。
  level2('level2', '二级'),

  /// 三级：给出删数结论（候选删除，教学专用）。
  level3('level3', '三级');

  const HintLevel(this.id, this.zhName);

  /// 稳定标识（序列化用）。
  final String id;

  /// 简体中文名。
  final String zhName;

  /// 级别序（1 起）。
  int get order => index + 1;

  /// 按 [id] 反查；未知返回 `null`。
  static HintLevel? tryParse(String id) {
    for (final HintLevel value in HintLevel.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 提示适用场景。
enum HintScope {
  /// 自由练习：最多两级。
  freePlay('freePlay', '自由练习'),

  /// 教学引导实操：最多三级。
  teaching('teaching', '教学');

  const HintScope(this.id, this.zhName);

  /// 稳定标识。
  final String id;

  /// 简体中文名。
  final String zhName;
}

/// 提示级别规则。
abstract final class HintRules {
  /// 某场景开放的最高级别。
  static int maxLevelOf(HintScope scope) => scope == HintScope.teaching ? 3 : 2;

  /// 由序数构造级别（1..3；越界返回 `null`）。
  static HintLevel? ofOrder(int order) {
    for (final HintLevel level in HintLevel.values) {
      if (level.order == order) {
        return level;
      }
    }
    return null;
  }
}
