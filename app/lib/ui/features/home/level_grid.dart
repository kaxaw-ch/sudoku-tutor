/// 关卡格栅（T-EDU-06 / S-02：每关一张“技巧 + 类型”信息卡）。
///
/// 纯渲染组件：只消费 [ChapterModel] 装配好的 [LevelTile] 列表，
/// 每张卡直接展示章内序号、主技巧和完整类型（教学演示/引导实操/综合试炼）；
/// 已完成关卡附对勾与星数。课程采用自由选关，因此这里没有锁态或禁用分支。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/domain/curriculum/chapter_model.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 关卡格栅。
class LevelGrid extends StatelessWidget {
  /// 构造关卡格栅。
  const LevelGrid({
    required this.levels,
    required this.onLevelTap,
    super.key,
  });

  /// 章内关卡瓦片（按 `order` 升序）。
  final List<LevelTile> levels;

  /// 点击已解锁关卡的回调（参数为关卡瓦片；页面据此按类型跳路由）。
  final void Function(LevelTile tile) onLevelTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 720
            ? 4
            : constraints.maxWidth >= 480
                ? 3
                : constraints.maxWidth >= 300
                    ? 2
                    : 1;
        final double cardWidth =
            (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final LevelTile tile in levels)
              SizedBox(
                key: ValueKey<String>('level-square-${tile.entry.id}'),
                width: cardWidth,
                child: _LevelCard(
                  tile: tile,
                  onTap: () => onLevelTap(tile),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 单个小关卡信息卡。
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.tile, required this.onTap});

  /// 关卡瓦片。
  final LevelTile tile;

  /// 点击进入本关。
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool completed = tile.isCompleted;
    return Material(
      color: completed
          ? scheme.primaryContainer.withValues(alpha: 0.68)
          : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: completed
              ? scheme.primary.withValues(alpha: 0.32)
              : scheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    context.l10n.text(
                      '第 {order} 小关',
                      <String, Object?>{'order': tile.entry.order},
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (completed) ...<Widget>[
                    Icon(Icons.check_circle, size: 17, color: scheme.primary),
                    const SizedBox(width: 3),
                    Text(
                      '★${tile.stars}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else
                    Icon(
                      Icons.play_circle_outline,
                      size: 18,
                      color: scheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tile.primaryTechnique == null
                    ? context.l10n.lessonTitle(
                        tile.entry.id,
                        tile.entry.title,
                      )
                    : context.l10n.techniqueName(tile.primaryTechnique!),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  context.l10n.levelKindName(tile.entry.kind),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
