/// 间距令牌（P0-UI-01 设计系统的一部分）。
///
/// 4 的倍数递增，页面布局统一引用本文件常量，禁止硬编码魔法数字。
library;

/// 间距令牌。
abstract final class AppSpacing {
  /// 最小间距。
  static const double xs = 4;

  /// 小间距。
  static const double sm = 8;

  /// 常规间距。
  static const double md = 16;

  /// 大间距。
  static const double lg = 24;

  /// 特大间距。
  static const double xl = 32;

  /// 棋盘外衬（棋盘与屏幕/卡片边缘的距离）。
  static const double boardInset = 12;
}
