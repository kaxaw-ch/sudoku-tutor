/// 路由常量（架构文档 §3.3.1）。
///
/// 约定：路径常量集中在此，**页面与业务代码不得硬编码字符串路径**。
library;

/// 全部路由路径常量。
abstract final class RoutePaths {
  /// 学习地图主页（S-02）。
  static const String home = '/';

  /// 首启引导（S-01）。
  static const String onboarding = '/onboarding';

  /// 原理演示页（S-03）。
  static const String demo = '/demo/:levelId';

  /// 引导实操页（S-04）。
  static const String practiceLevel = '/practice/:levelId';

  /// 验收试炼页（S-05）。
  static const String trial = '/trial/:levelId';

  /// 难度选择页（S-07）。
  static const String difficulty = '/free-play';

  /// 自由练习对局页（S-06）。
  static const String freePlay = '/free-play/session';

  /// 设置页（S-08）。
  static const String settings = '/settings';

  /// 数独技巧百科。
  static const String wiki = '/wiki';

  /// 开发者模式页（S-12）。
  static const String developer = '/settings/developer';

  /// 用具体 `levelId` 填充带参路由。
  static String withLevelId(String template, String levelId) =>
      template.replaceAll(':levelId', levelId);
}

/// 全部路由名称常量（`go_router` 具名跳转用）。
abstract final class RouteNames {
  /// 学习地图主页。
  static const String home = 'home';

  /// 首启引导。
  static const String onboarding = 'onboarding';

  /// 原理演示页。
  static const String demo = 'demo';

  /// 引导实操页。
  static const String practiceLevel = 'practiceLevel';

  /// 验收试炼页。
  static const String trial = 'trial';

  /// 难度选择页。
  static const String difficulty = 'difficulty';

  /// 自由练习对局页。
  static const String freePlay = 'freePlay';

  /// 设置页。
  static const String settings = 'settings';

  /// 数独技巧百科。
  static const String wiki = 'wiki';

  /// 开发者模式页。
  static const String developer = 'developer';
}
