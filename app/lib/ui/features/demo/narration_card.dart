/// 演示关旁白卡片（T-EDU-02 / P0-EDU-02，S-03 下半区）。
///
/// 展示当前步骤的技巧名 + 讲解旁白；纯展示组件，不持有播放状态。
library;

import 'package:flutter/material.dart';

import '../../theme/spacing.dart';

/// 旁白卡片。
class NarrationCard extends StatelessWidget {
  /// 构造旁白卡片。
  const NarrationCard({
    required this.narration,
    required this.techniqueName,
    super.key,
  });

  /// 当前步骤旁白。
  final String narration;

  /// 当前步骤技巧名。
  final String techniqueName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.menu_book_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('本步技巧：$techniqueName', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              narration,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
