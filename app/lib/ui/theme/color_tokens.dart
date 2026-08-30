/// 主题令牌 —— 白/粉/蓝三插槽（P0-UI-01）。
///
/// PRD P0-UI-01：主题令牌抽象出**白/粉/蓝三套插槽**，本期只实现并交付
/// 「白色为主」一套，另两套占位置灰（UI 层据此将粉色/蓝色选项置灰不可选）。
///
/// ⚠️ 不做深色模式（P0-UI-01 约束）：本设计系统只有浅色一套亮度，
/// 颜色令牌全部面向浅色背景。
///
/// 三插槽通过 [ThemeSlot]（domain 层定义，见 `settings_models.dart`）
/// 与设置项共享同一事实源，UI 层展示与存档字段永不漂移。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

/// 一套完整颜色令牌（不可变）。
class AppColorTokens {
  /// 构造令牌。
  const AppColorTokens({
    required this.slot,
    required this.seedColor,
    required this.background,
    required this.surface,
    required this.isImplemented,
  });

  /// 所属插槽。
  final ThemeSlot slot;

  /// Material 3 单一种子色（`ColorScheme.fromSeed` 的唯一输入，PRD C-16）。
  final Color seedColor;

  /// 页面背景色（白色主题为纯白）。
  final Color background;

  /// 卡片/浮层表面色。
  final Color surface;

  /// 是否已真实实现（白色 = true；粉/蓝占位 = false，UI 置灰）。
  final bool isImplemented;

  /// 白色主题（本期唯一实现，种子色 Indigo `#3F51B5`）。
  static const AppColorTokens white = AppColorTokens(
    slot: ThemeSlot.white,
    seedColor: Color(0xFF3F51B5),
    background: Colors.white,
    surface: Colors.white,
    isImplemented: true,
  );

  /// 按插槽取令牌；粉/蓝返回**置灰占位**（同一灰色系，`isImplemented=false`）。
  static AppColorTokens forSlot(ThemeSlot slot) => switch (slot) {
        ThemeSlot.white => white,
        // 置灰占位：种子色灰 + 浅灰底，保证「可选但明显未实现」的视觉语义。
        ThemeSlot.pink || ThemeSlot.blue => AppColorTokens(
            slot: slot,
            seedColor: const Color(0xFF9E9E9E),
            background: const Color(0xFFF5F5F5),
            surface: const Color(0xFFFAFAFA),
            isImplemented: false,
          ),
      };
}
