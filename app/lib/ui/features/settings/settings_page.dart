/// 设置页（S-08，P0-STO-08 冻结清单逐项一致，T-UI-05）。
///
/// 冻结清单对照（S-08 分组）：
/// - **外观**：应用主题（仅白色可选，粉/蓝置灰预留）与棋盘主题（蓝/绿）；
/// - **玩法**：自动候选数、错误标红、计时显示、相同数字高亮、提示次数
///   （关闭/3/5/不限）；
/// - **反馈**：音效（默认关）、震动（移动端默认开）；
/// - **数据**：见 `DataSection`（导出/导入/清空错题本/重置二次确认/导出日志）；
/// - **关于**：版本号连点 7 次进开发者模式、语言（置灰）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/settings/settings_controller.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

import 'about_section.dart';
import 'data_section.dart';

/// 设置页。
class SettingsPage extends ConsumerWidget {
  /// 构造页面。
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SettingsState> asyncSettings =
        ref.watch(settingsStateProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(RouteNames.home),
        ),
        title: const Text('设置'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: asyncSettings.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace st) => Center(
              child: Text('设置加载失败：$e'),
            ),
            data: (SettingsState settings) => ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              children: <Widget>[
                _AppearanceSection(settings: settings),
                _GameplaySection(settings: settings),
                _FeedbackSection(settings: settings),
                const DataSection(),
                const AboutSection(),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 外观分组：应用主题三插槽 + 可立即切换的蓝/绿棋盘主题。
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection({required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
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
            '外观',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: <Widget>[
              for (final ThemeSlot slot in ThemeSlot.values) ...<Widget>[
                if (slot != ThemeSlot.values.first) const Divider(height: 1),
                // 白色可选（当前实现）；粉/蓝置灰（预留）。
                ListTile(
                  enabled: slot == ThemeSlot.white,
                  leading: Icon(
                    slot == settings.theme
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: slot == settings.theme
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  title: Text(slot.zhName),
                  subtitle: slot == ThemeSlot.white
                      ? const Text('当前主题')
                      : const Text('即将推出'),
                  trailing: slot == ThemeSlot.white
                      ? null
                      : const Icon(Icons.lock_outline),
                  onTap: slot == ThemeSlot.white
                      ? () {
                          if (settings.theme != slot) {
                            ref
                                .read(settingsControllerProvider.notifier)
                                .setTheme(slot);
                          }
                        }
                      : null,
                ),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.grid_4x4_rounded),
                title: const Text('棋盘主题'),
                subtitle: Text(
                  '当前：${settings.boardTheme.zhName} · 做题与教学棋盘同步切换',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: SegmentedButton<BoardThemeStyle>(
                  key: const ValueKey<String>('board-theme-selector'),
                  segments: <ButtonSegment<BoardThemeStyle>>[
                    for (final BoardThemeStyle style in BoardThemeStyle.values)
                      ButtonSegment<BoardThemeStyle>(
                        value: style,
                        icon: _BoardThemeSwatch(
                          color: GamePalette.boardOf(style).selectionFill,
                        ),
                        label: Text(style.zhName),
                      ),
                  ],
                  selected: <BoardThemeStyle>{settings.boardTheme},
                  showSelectedIcon: false,
                  onSelectionChanged: (Set<BoardThemeStyle> selected) {
                    final BoardThemeStyle style = selected.single;
                    if (style != settings.boardTheme) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setBoardTheme(style);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 棋盘主题按钮内的颜色预览点。
class _BoardThemeSwatch extends StatelessWidget {
  const _BoardThemeSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      );
}

/// 玩法分组：自动候选数 / 错误标红 / 计时显示 / 相同数字高亮 / 提示次数。
class _GameplaySection extends ConsumerWidget {
  const _GameplaySection({required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
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
            '玩法',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: <Widget>[
              _SwitchTile(
                icon: Icons.auto_fix_high,
                title: '自动候选数',
                value: settings.autoCandidates,
                onChanged: (bool v) => ref
                    .read(settingsControllerProvider.notifier)
                    .setAutoCandidates(v),
              ),
              const Divider(height: 1),
              _SwitchTile(
                icon: Icons.error_outline,
                title: '标记错误',
                value: settings.markErrors,
                onChanged: (bool v) => ref
                    .read(settingsControllerProvider.notifier)
                    .setMarkErrors(v),
              ),
              const Divider(height: 1),
              _SwitchTile(
                icon: Icons.timer_outlined,
                title: '显示计时',
                value: settings.showTimer,
                onChanged: (bool v) => ref
                    .read(settingsControllerProvider.notifier)
                    .setShowTimer(v),
              ),
              const Divider(height: 1),
              _SwitchTile(
                icon: Icons.filter_9_plus_outlined,
                title: '相同数字高亮',
                value: settings.highlightSameDigit,
                onChanged: (bool v) => ref
                    .read(settingsControllerProvider.notifier)
                    .setHighlightSameDigit(v),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('提示次数'),
                subtitle: const Text('自由练习每局可用提示次数'),
                trailing: DropdownButton<HintQuota>(
                  value: settings.hintQuota,
                  underline: const SizedBox.shrink(),
                  items: <DropdownMenuItem<HintQuota>>[
                    for (final HintQuota quota in HintQuota.values)
                      DropdownMenuItem<HintQuota>(
                        value: quota,
                        child: Text(quota.zhName),
                      ),
                  ],
                  onChanged: (HintQuota? quota) {
                    if (quota != null) {
                      ref
                          .read(settingsControllerProvider.notifier)
                          .setHintQuota(quota);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 反馈分组：音效（默认关）/ 震动（移动端默认开）。
class _FeedbackSection extends ConsumerWidget {
  const _FeedbackSection({required this.settings});

  final SettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
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
            '反馈',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: <Widget>[
              _SwitchTile(
                icon: Icons.volume_up_outlined,
                title: '音效',
                subtitle: '默认关闭（桌面端不可用）',
                value: settings.soundOn,
                onChanged: (bool v) =>
                    ref.read(settingsControllerProvider.notifier).setSoundOn(v),
              ),
              const Divider(height: 1),
              _SwitchTile(
                icon: Icons.vibration,
                title: '震动',
                subtitle: '移动端默认开启',
                value: settings.hapticOn,
                onChanged: (bool v) => ref
                    .read(settingsControllerProvider.notifier)
                    .setHapticOn(v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 带图标的开关行。
class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value,
        onChanged: onChanged,
      );
}
