/// 验收试炼关结算卡（T-EDU-05 / P0-EDU-06/07，S-05）。
///
/// 通关后弹出：用时 / 错误次数 /「返回章节」/「下一关」。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

import '../../theme/spacing.dart';
import '../../widgets/congratulations_animation.dart';

/// 试炼关结算卡。
class TrialResultSheet extends StatelessWidget {
  /// 构造结算卡。
  const TrialResultSheet({
    required this.elapsedMs,
    required this.errorCount,
    required this.onBackToMap,
    this.onNextLevel,
    this.hasNext = false,
    super.key,
  });

  /// 通关用时（毫秒）。
  final int elapsedMs;

  /// 本关累计错误次数。
  final int errorCount;

  /// 是否还有下一关。
  final bool hasNext;

  /// 返回章节（学习地图）。
  final VoidCallback onBackToMap;

  /// 进入下一关（无下一关时为 `null` → 按钮隐藏）。
  final VoidCallback? onNextLevel;

  /// 便捷显示。
  static Future<void> show(
    BuildContext context, {
    required int elapsedMs,
    required int errorCount,
    required VoidCallback onBackToMap,
    VoidCallback? onNextLevel,
    bool hasNext = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => TrialResultSheet(
        elapsedMs: elapsedMs,
        errorCount: errorCount,
        hasNext: hasNext,
        onBackToMap: onBackToMap,
        onNextLevel: onNextLevel,
      ),
    );
  }

  /// 毫秒 → `mm:ss`。
  static String formatDuration(int ms) {
    final int totalSeconds = ms ~/ 1000;
    return '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(totalSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const CelebrationTrophy(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(context.l10n.text('挑战通过！'))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(context.l10n.text('自动核验通过，整盘全部正确。')),
          const SizedBox(height: AppSpacing.md),
          _StatRow(
            label: context.l10n.text('用时'),
            value: formatDuration(elapsedMs),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatRow(
            label: context.l10n.text('错误次数'),
            value: context.l10n.text(
              '{count} 次',
              <String, Object?>{'count': errorCount},
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: onBackToMap,
          child: Text(context.l10n.text('返回章节')),
        ),
        if (hasNext && onNextLevel != null)
          FilledButton(
            onPressed: onNextLevel,
            child: Text(context.l10n.text('下一关')),
          ),
      ],
    );
  }
}

/// 结算卡中的一行统计。
class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(label, style: theme.textTheme.bodyLarge),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
