/// T-UI-01 · 颜色令牌三插槽测试（P0-UI-01）。
///
/// 覆盖：白/粉/蓝三插槽存在；**仅白色实现，粉/蓝置灰**；
/// 单一种子色；不做深色模式（令牌只面向浅色）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';
import 'package:sudoku_tutor/ui/theme/color_tokens.dart';

void main() {
  test('三插槽齐全：white / pink / blue', () {
    expect(ThemeSlot.values, hasLength(3));
    expect(ThemeSlot.white.zhName, '白色');
    expect(ThemeSlot.pink.zhName, '粉色');
    expect(ThemeSlot.blue.zhName, '蓝色');
  });

  test('仅白色实现，粉/蓝置灰占位', () {
    expect(AppColorTokens.white.isImplemented, isTrue);
    expect(AppColorTokens.forSlot(ThemeSlot.pink).isImplemented, isFalse);
    expect(AppColorTokens.forSlot(ThemeSlot.blue).isImplemented, isFalse);
  });

  test('白色令牌使用单一种子色 Indigo #3F51B5', () {
    const AppColorTokens tokens = AppColorTokens.white;
    expect(tokens.slot, ThemeSlot.white);
    expect(tokens.seedColor, const Color(0xFF3F51B5));
    expect(tokens.background, Colors.white);
  });

  test('forSlot 与 AppTheme.light 一致（单一事实源）', () {
    final ThemeData theme = AppTheme.light();
    expect(theme.colorScheme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, Colors.white);

    // 粉/蓝插槽也可装配（置灰占位），不破坏主题构建。
    expect(AppTheme.light(slot: ThemeSlot.pink).scaffoldBackgroundColor,
        const Color(0xFFF5F5F5));
    expect(AppTheme.light(slot: ThemeSlot.blue).scaffoldBackgroundColor,
        const Color(0xFFF5F5F5));
  });

  test('app_theme 的种子色与白色令牌一致', () {
    expect(AppTheme.seedColor, const Color(0xFF3F51B5));
    expect(AppTheme.seedColor, AppColorTokens.white.seedColor);
  });
}
