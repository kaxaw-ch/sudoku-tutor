/// 设置页 · 关于分组（S-08，P0-EDU-10，T-UI-05）。
///
/// - 版本号行：**连点 7 次**进入开发者模式（P0-EDU-10 / S-08），
///   由 [DeveloperMode] 计数，达阈值后写入设置并导航开发者页；
/// - 语言行：简体中文 / English 即时切换并持久化；
/// - 应用名 / 版权信息。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/settings/developer_mode.dart';
import 'package:sudoku_tutor/domain/settings/settings_controller.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 应用版本号（与 `pubspec.yaml` 同步；连点阈值见 [kDeveloperTapThreshold]）。
const String kAppVersion = '0.1.0';

/// 关于分组。
class AboutSection extends ConsumerWidget {
  /// 构造分组。
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final DeveloperMode mode = ref.watch(developerModeProvider);
    final bool developerUnlocked =
        ref.watch(settingsStateProvider).valueOrNull?.developerMode ?? false;
    final String language = AppLanguages.normalize(
      ref.watch(settingsStateProvider).valueOrNull?.language,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            context.l10n.text('关于'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.apps),
                title: Text(context.l10n.text('数独教学')),
                subtitle: Text(
                  context.l10n.text(
                    '版本 {version}',
                    const <String, Object?>{'version': kAppVersion},
                  ),
                ),
                trailing: developerUnlocked
                    ? const Icon(Icons.verified, color: Colors.green)
                    : null,
                onTap: () => _onVersionTap(context, ref, mode),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(context.l10n.text('语言')),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: SegmentedButton<String>(
                    key: const ValueKey<String>('language-selector'),
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: AppLanguages.chinese,
                        label: Text(context.l10n.text('简体中文')),
                      ),
                      ButtonSegment<String>(
                        value: AppLanguages.english,
                        // Language names stay in their native form so the
                        // selector remains understandable in either locale.
                        label: const Text('English'),
                      ),
                    ],
                    selected: <String>{language},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<String> selected) => ref
                        .read(settingsControllerProvider.notifier)
                        .setLanguage(selected.single),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.text('隐私说明')),
                subtitle: Text(
                  context.l10n.text('完全离线运行，本地存档，无网络上报'),
                ),
                enabled: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 版本号连点：计数达阈值 → 解锁开发者模式并导航。
  void _onVersionTap(BuildContext context, WidgetRef ref, DeveloperMode mode) {
    final bool reached = mode.registerTap();
    if (!reached) {
      return;
    }
    ref.read(settingsControllerProvider.notifier).enableDeveloperMode();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(context.l10n.text('开发者模式已开启'))),
      );
    context.goNamed(RouteNames.developer);
  }
}
