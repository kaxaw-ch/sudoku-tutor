/// Material 3 主题装配（P0-UI-01：单一种子色、白色主题、不做深色模式）。
///
/// 装配链：`AppColorTokens`（三插槽令牌）→ `ColorScheme.fromSeed` → `ThemeData`。
/// - **单一种子色**：全部派生色只由 `AppColorTokens.seedColor` 一处给出
///   （PRD C-16，M3 自动生成 tonal palette）；
/// - **白/粉/蓝三插槽**：`AppColorTokens.forSlot(slot)`，本期仅白色实现，
///   粉/蓝置灰占位（`isImplemented=false`，UI 据此置灰）；
/// - **不做深色模式**：仅 `Brightness.light`，不提供 `dark()`。
///
/// 系统字号钳制见 `text_scale_clamp.dart`（独立文件，`MaterialApp.builder` 挂载）。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

import 'color_tokens.dart';
import 'game_palette.dart';
import 'typography.dart';

/// 应用主题构建器。
abstract final class AppTheme {
  /// 主题种子色（PRD C-16 单一种子色 Indigo，与白色令牌 `seedColor` 一致）。
  static const Color seedColor = Color(0xFF3F51B5);

  /// 白色（浅色）主题。
  ///
  /// [slot] 可换应用主题插槽（粉/蓝为置灰占位）；[boardTheme] 独立控制
  /// 所有做题与教学棋盘的蓝色/绿色配色。
  static ThemeData light({
    ThemeSlot slot = ThemeSlot.white,
    BoardThemeStyle boardTheme = BoardThemeStyle.green,
  }) {
    final AppColorTokens tokens = AppColorTokens.forSlot(slot);
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: tokens.seedColor,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[
        GamePalette.boardOf(boardTheme),
      ],
      scaffoldBackgroundColor: tokens.background,
      textTheme: AppTypography.build(scheme),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface.withValues(alpha: 0.96),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
        surfaceTintColor: scheme.surfaceTint,
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        surfaceTintColor: scheme.surfaceTint,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.windows: _SoftPageTransitionsBuilder(),
          TargetPlatform.macOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.linux: _SoftPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// 轻量淡入上移动画，统一桌面与移动端页面切换节奏。
class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.025, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
