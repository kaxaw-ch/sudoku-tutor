/// `MaterialApp.router` 装配（主题 / 本地化 / 字号钳制 / 响应式外壳）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/app/router.dart';
import 'package:sudoku_tutor/domain/settings/settings_controller.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';
import 'package:sudoku_tutor/ui/theme/text_scale_clamp.dart';
import 'package:sudoku_tutor/ui/widgets/responsive_shell.dart';

/// 应用根 Widget。
class SudokuTutorApp extends ConsumerStatefulWidget {
  /// 构造应用根；[router] 可注入以便 Widget 测试替换路由表。
  ///
  /// [initialLocation] 为初始路由（首启未完成 → `/onboarding`，
  /// 否则 → `/home`），由 [SudokuTutorAppState] 组装路由时使用；
  /// 测试可显式指定，生产由 `bootstrap()` 依据存档决定。
  const SudokuTutorApp({
    super.key,
    this.router,
    this.initialLocation = RoutePaths.home,
  });

  /// 可选的外部路由表（测试注入用）。
  final GoRouter? router;

  /// 初始路由位置。
  final String initialLocation;

  @override
  ConsumerState<SudokuTutorApp> createState() => _SudokuTutorAppState();
}

class _SudokuTutorAppState extends ConsumerState<SudokuTutorApp> {
  late final GoRouter _router =
      widget.router ?? buildRouter(initialLocation: widget.initialLocation);

  @override
  Widget build(BuildContext context) {
    final BoardThemeStyle boardTheme = ref.watch(
      settingsStateProvider.select(
        (AsyncValue<SettingsState> value) =>
            value.valueOrNull?.boardTheme ?? BoardThemeStyle.green,
      ),
    );
    final String language = ref.watch(
      settingsStateProvider.select(
        (AsyncValue<SettingsState> value) =>
            AppLanguages.normalize(value.valueOrNull?.language),
      ),
    );
    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          context.l10n.text('数独教学'),
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light(
        boardTheme: boardTheme,
      ),
      // 中文为默认语言；设置加载后按持久化偏好即时切换。
      locale: language == AppLanguages.english
          ? const Locale(AppLanguages.english)
          : const Locale(AppLanguages.chinese, 'CN'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 组装顺序：字号钳制在内、响应式缩放在外。
      builder: (BuildContext context, Widget? child) => ResponsiveShell(
        child: TextScaleClamp.wrap(context, child),
      ),
    );
  }
}
