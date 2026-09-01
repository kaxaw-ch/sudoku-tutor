/// 演示关步骤控制条（T-EDU-02 / P0-EDU-02，S-03）。
///
/// 双模式统一控制条：上一步 / 下一步 / 自动播放(2s/步，可暂停) / 重播 /
/// 步骤进度 `n/m`。纯展示组件，回调由页面接到 [DemoController]。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

import '../../theme/spacing.dart';

/// 步骤控制条。
class StepControlBar extends StatelessWidget {
  /// 构造步骤控制条。
  const StepControlBar({
    required this.progress,
    required this.total,
    required this.autoPlaying,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleAutoPlay,
    required this.onReplay,
    this.autoPlayFast = false,
    this.onToggleSpeed,
    this.enableNext = true,
    this.enableAutoPlay = true,
    super.key,
  });

  /// 当前步（1-based，`n/m` 中的 n）。
  final int progress;

  /// 总步数（`n/m` 中的 m）。
  final int total;

  /// 是否自动播放中。
  final bool autoPlaying;

  /// 上一步。
  final VoidCallback onPrevious;

  /// 下一步（看完最后一步即算完成）。
  final VoidCallback onNext;

  /// 切换自动播放。
  final VoidCallback onToggleAutoPlay;

  /// 重播（回到第 1 步）。
  final VoidCallback onReplay;

  /// 是否快速自动播放（每秒两步；`false` = 每 2 秒一步）。
  final bool autoPlayFast;

  /// 切换自动播放速度（2s/步 ↔ 每秒两步）；`null` 时不显示速度按钮。
  final VoidCallback? onToggleSpeed;

  /// 是否允许「下一步」（到达最后一步时禁用）。
  final bool enableNext;

  /// 是否允许「自动播放」（空脚本时禁用）。
  final bool enableAutoPlay;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton.filledTonal(
            tooltip: context.l10n.text('上一步'),
            onPressed: progress > 1 ? onPrevious : null,
            icon: const Icon(Icons.skip_previous),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: context.l10n.text('下一步'),
            onPressed: enableNext ? onNext : null,
            icon: const Icon(Icons.skip_next),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: context.l10n
                .text(autoPlaying ? '暂停自动播放' : '自动播放'),
            onPressed: enableAutoPlay ? onToggleAutoPlay : null,
            icon: Icon(autoPlaying ? Icons.pause : Icons.play_arrow),
          ),
          if (onToggleSpeed != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            // 速度切换：每 2 秒一步 ↔ 每秒两步。
            IconButton.filledTonal(
              tooltip: context.l10n.text(
                autoPlayFast
                    ? '速度：每秒两步'
                    : '速度：每 2 秒一步（点击切换每秒两步）',
              ),
              onPressed: enableAutoPlay ? onToggleSpeed : null,
              icon: Icon(autoPlayFast ? Icons.fast_forward : Icons.speed),
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            tooltip: context.l10n.text('重播'),
            onPressed: total > 0 ? onReplay : null,
            icon: const Icon(Icons.replay),
          ),
          const SizedBox(width: AppSpacing.md),
          Chip(
            label: Text('$progress/$total'),
            visualDensity: VisualDensity.compact,
            labelStyle: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
