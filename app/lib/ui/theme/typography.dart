/// 排版令牌（P0-UI-01 设计系统的一部分）。
///
/// 定义基础字号常量与统一 `TextTheme` 构建器，供 `AppTheme` 装配；
/// 页面代码只应引用 `Theme.of(context).textTheme`，不直接散写字号。
library;

import 'package:flutter/material.dart';

/// 排版令牌。
abstract final class AppTypography {
  /// 大标题（页面级标题）。
  static const double headline = 24;

  /// 中标题（区块标题）。
  static const double title = 18;

  /// 正文。
  static const double body = 14;

  /// 辅助说明。
  static const double caption = 12;

  /// 在 M3 默认字号表基础上覆盖关键档位，保证全端一致。
  static TextTheme build(ColorScheme scheme) {
    final TextTheme base = ThemeData(colorScheme: scheme).textTheme;
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(fontSize: headline),
      titleMedium: base.titleMedium?.copyWith(fontSize: title),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: body),
      bodySmall: base.bodySmall?.copyWith(fontSize: caption),
    );
  }
}
