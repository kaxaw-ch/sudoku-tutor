/// 章节卡片（T-EDU-06 / S-02：章号/名称/技巧标签/进度 `n/m`）。
///
/// 纵向卡片：点击卡片头**展开/收起**该章关卡格栅（带展开动画）。
/// 课程采用自由选关，所有索引内章节都可展开，且不渲染任何锁态。
///
/// 纯渲染组件：章号/名称/技巧标签/进度全部来自 [ChapterModel]
/// （T-EDU-01 已把索引 + 存档装配好），本组件不计算任何业务数据。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/chapter_model.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';
import 'package:sudoku_tutor/ui/widgets/technique_chip.dart';

import 'level_grid.dart';

/// 章节卡片。
class ChapterCard extends StatefulWidget {
  /// 构造章节卡片。
  const ChapterCard({
    required this.chapter,
    required this.onLevelTap,
    super.key,
  });

  /// 章节视图模型（含自由可选的关卡信息卡）。
  final ChapterModel chapter;

  /// 点击任意关卡的回调（上抛给主页统一跳路由）。
  final void Function(LevelTile tile) onLevelTap;

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  /// 是否已展开关卡格栅。
  bool _expanded = false;

  /// 桌面指针悬停状态，用于轻量抬升反馈。
  bool _hovered = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final ChapterModel model = widget.chapter;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.012 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Card(
          margin: EdgeInsets.zero,
          elevation: _hovered ? 2 : 0,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: <Widget>[
              // 卡片头：全部章节均可点击展开/收起。
              InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildHeader(model),
                ),
              ),
              // 展开动画区：收起时高度塌缩为 0。
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: LevelGrid(
                          levels: model.levels,
                          onLevelTap: widget.onLevelTap,
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡片头内容：章号徽章 + 名称/技巧/进度 + 状态角标。
  Widget _buildHeader(ChapterModel model) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 章号徽章：`第 N 章`（与 index.json 的 0 起章号口径一致）。
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '第 ${model.chapter} 章',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 章名称 + 展开箭头。
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      model.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // 本章技巧标签组（按 rank 升序稳定排序）。
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final TechniqueId id
                      in TechniqueId.values.where(model.techniqueTags.contains))
                    TechniqueChip(label: id.zhName),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // 进度 `n/m`（S-02 文案：已通关 n/m）。
              Text(
                '已通关 ${model.completedCount}/${model.totalCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: model.totalCount == 0
                      ? 0
                      : model.completedCount / model.totalCount,
                ),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (
                  BuildContext context,
                  double value,
                  Widget? child,
                ) =>
                    LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(99),
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
