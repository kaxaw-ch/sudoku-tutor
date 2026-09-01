/// 误操作即时纠正弹窗（T-EDU-04 / P0-EDU-05）。
///
/// - 标题「这一步有问题」；
/// - 两段：**错在哪** + **正确思路指引**；
/// - **不直接给答案**（文案由 `MistakeMessageRepository` 渲染，只讲思路）；
/// - 单按钮「明白了」。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

import '../../../domain/teaching/mistake_message_repository.dart';
import '../../theme/spacing.dart';

/// 误操作弹窗。
class MistakeDialog extends StatelessWidget {
  /// 构造弹窗。
  const MistakeDialog({required this.message, super.key});

  /// 弹窗文案（「错在哪」+「正确思路」两段）。
  final MistakeMessage message;

  /// 便捷显示：`showDialog` 包装。
  static Future<void> show(BuildContext context, MistakeMessage message) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) => MistakeDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Colors.deepOrange),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(context.l10n.text('这一步有问题'))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Section(
            label: context.l10n.text('错在哪'),
            text: message.what,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          _Section(
            label: context.l10n.text('正确思路'),
            text: message.how,
            color: theme.colorScheme.primary,
          ),
        ],
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.text('明白了')),
        ),
      ],
    );
  }
}

/// 弹窗内的一节（标签 + 正文）。
class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.text,
    required this.color,
  });

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
      ],
    );
  }
}
