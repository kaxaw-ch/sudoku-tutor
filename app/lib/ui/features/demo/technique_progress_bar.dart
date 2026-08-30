/// 演示关技巧进度条。
///
/// 在线性步骤进度上标出每种技巧首次出现的位置，并提供可点击的技巧节点，
/// 让玩家可直接跳到目标技巧开始讲解的步骤。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 带技巧节点的演示进度条。
class DemoTechniqueProgressBar extends StatelessWidget {
  /// 构造技巧进度条。
  const DemoTechniqueProgressBar({
    required this.steps,
    required this.currentIndex,
    required this.onStepSelected,
    this.targetTechniques = const <TechniqueId>{},
    super.key,
  });

  /// 本关全部脚本步骤。
  final List<ScriptStep> steps;

  /// 当前步骤索引（0-based）。
  final int currentIndex;

  /// 点击技巧节点后的步骤跳转回调。
  final Future<void> Function(int stepIndex) onStepSelected;

  /// 关卡索引标注的目标技巧；其节点显示“重点”。
  final Set<TechniqueId> targetTechniques;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<_TechniqueMilestone> milestones = _milestonesOf(steps);
    final double progress = (currentIndex + 1) / steps.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.route_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '技巧进度',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '点击技巧节点快速跳转',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 20,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double markerSize = 16;
                    final double usableWidth = constraints.maxWidth > markerSize
                        ? constraints.maxWidth - markerSize
                        : 0;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Positioned(
                          left: markerSize / 2,
                          right: markerSize / 2,
                          top: 6,
                          child: LinearProgressIndicator(
                            key: const ValueKey<String>('demo-step-progress'),
                            value: progress,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(99),
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                        for (final _TechniqueMilestone milestone in milestones)
                          Positioned(
                            left: usableWidth *
                                _positionOf(milestone.stepIndex, steps.length),
                            top: 1,
                            child: Tooltip(
                              message:
                                  '${milestone.technique.zhName}：第 ${milestone.stepIndex + 1} 步',
                              child: InkWell(
                                key: ValueKey<String>(
                                  'demo-progress-marker-${milestone.technique.id}',
                                ),
                                customBorder: const CircleBorder(),
                                onTap: () =>
                                    onStepSelected(milestone.stepIndex),
                                child: Container(
                                  width: markerSize,
                                  height: markerSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: milestone.stepIndex <= currentIndex
                                        ? scheme.primary
                                        : scheme.surface,
                                    border: Border.all(
                                      color: scheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < milestones.length; i++) ...<Widget>[
                      if (i > 0) const SizedBox(width: AppSpacing.xs),
                      _MilestoneChip(
                        milestone: milestones[i],
                        selected: steps[currentIndex].techniqueId ==
                            milestones[i].technique,
                        isTarget:
                            targetTechniques.contains(milestones[i].technique),
                        onTap: () => onStepSelected(milestones[i].stepIndex),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double _positionOf(int index, int total) =>
      total <= 1 ? 0 : index / (total - 1);

  /// 每种技巧只保留首次出现位置，保持脚本出现顺序。
  static List<_TechniqueMilestone> _milestonesOf(List<ScriptStep> steps) {
    final Set<TechniqueId> seen = <TechniqueId>{};
    return <_TechniqueMilestone>[
      for (int i = 0; i < steps.length; i++)
        if (seen.add(steps[i].techniqueId))
          _TechniqueMilestone(steps[i].techniqueId, i),
    ];
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({
    required this.milestone,
    required this.selected,
    required this.isTarget,
    required this.onTap,
  });

  final _TechniqueMilestone milestone;
  final bool selected;
  final bool isTarget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      key: ValueKey<String>('demo-technique-${milestone.technique.id}'),
      avatar: CircleAvatar(
        child: Text('${milestone.stepIndex + 1}'),
      ),
      label: Text(
        '${milestone.technique.zhName}${isTarget ? ' · 重点' : ''}',
      ),
      tooltip: '跳到第 ${milestone.stepIndex + 1} 步',
      onPressed: onTap,
      backgroundColor:
          selected ? Theme.of(context).colorScheme.primaryContainer : null,
      side: selected
          ? BorderSide(color: Theme.of(context).colorScheme.primary)
          : null,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TechniqueMilestone {
  const _TechniqueMilestone(this.technique, this.stepIndex);

  final TechniqueId technique;
  final int stepIndex;
}
