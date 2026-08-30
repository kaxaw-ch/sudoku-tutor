/// 系统字号钳制（P0-UI-07：0.85–1.3）。
///
/// 系统级「超大字号」会把布局撑爆，本组件在 `MaterialApp.builder` 层
/// 用 `MediaQuery.textScaler.clamp` 将字号缩放钳制在 [minScale]–[maxScale]。
/// 与 T-UI-01 主题插槽无关，属于全局可达性护栏。
library;

import 'package:flutter/material.dart';

/// 系统字号钳制器。
abstract final class TextScaleClamp {
  /// 字号下限。
  static const double minScale = 0.85;

  /// 字号上限。
  static const double maxScale = 1.3;

  /// 对 [child] 应用字号钳制。
  ///
  /// 用法：挂在 `MaterialApp.builder`，保证任何系统字号设置下布局不炸。
  static Widget wrap(BuildContext context, Widget? child) {
    final MediaQueryData data = MediaQuery.of(context);
    return MediaQuery(
      data: data.copyWith(
        textScaler: data.textScaler.clamp(
          minScaleFactor: minScale,
          maxScaleFactor: maxScale,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
