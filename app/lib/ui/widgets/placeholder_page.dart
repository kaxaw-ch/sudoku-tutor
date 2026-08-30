/// 空态占位页：路由表已固化、页面尚未交付时的统一承接页。
///
/// ⚠️ 每个占位页都必须写明**将在哪个批次/任务交付**，避免占位页被遗忘。
library;

import 'package:flutter/material.dart';

/// 通用占位页。
class PlaceholderPage extends StatelessWidget {
  /// 构造占位页。
  const PlaceholderPage({
    required this.title,
    required this.milestone,
    super.key,
  });

  /// 页面标题。
  final String title;

  /// 计划交付的批次与任务号，如 `批次 E · T-UI-04`。
  final String milestone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.construction_outlined,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text('「$title」尚未交付', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '计划交付：$milestone',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
