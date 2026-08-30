/// 断点续玩提示条（S-07 / P0-PRA-09，T-UI-04）。
///
/// 有断点存档时在难度选择页顶部展示：
/// 「检测到未完成的对局」+ 两个操作（继续上次对局 / 开始新局（将覆盖））。
library;

import 'package:flutter/material.dart';

import '../../theme/spacing.dart';

/// 断点续玩横幅。
class ResumeBanner extends StatelessWidget {
  /// 构造横幅。
  const ResumeBanner({
    required this.onResume,
    required this.onStartNew,
    super.key,
  });

  /// 「继续上次对局」回调。
  final VoidCallback onResume;

  /// 「开始新局（将覆盖）」回调。
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 1,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.play_circle_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '检测到未完成的对局',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '可继续上次对局，或开始新局（将覆盖上次进度）',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: onResume,
                  child: const Text('继续上次对局'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: onStartNew,
                  child: const Text('开始新局（将覆盖）'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
