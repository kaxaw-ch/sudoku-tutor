/// 技巧标签（T-EDU-06 / P0-UI-01 设计系统的一部分）。
///
/// 章节卡片 / 关卡信息里展示「本章/本关所教技巧」的小胶囊。
/// 本期为**纯展示**（`onTap = null`）；P1 技巧百科上线后，
/// 章节卡片把 `onTap` 接上「跳转百科词条」，本组件无需改动。
library;

import 'package:flutter/material.dart';

/// 技巧标签小胶囊。
class TechniqueChip extends StatelessWidget {
  /// 构造技巧标签。
  const TechniqueChip({
    required this.label,
    this.onTap,
    super.key,
  });

  /// 标签文案（如 `唯一余数`，来自 [TechniqueId.zhName] 的定死译名）。
  final String label;

  /// 点击回调（P1 跳转技巧百科）；`null` = 纯展示。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
