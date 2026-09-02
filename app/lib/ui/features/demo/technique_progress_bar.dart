/// 演示关技巧进度条。
///
/// 整条进度均可点击、拖动。关卡标签会同时包含前置技巧，因此只取其中
/// 等级最高的本关主技巧，并标出该技巧在脚本中的每一次出现位置。
/// 点击技巧按钮先跳到第一次出现的位置，再次点击进入下一个位置。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

const double _kTrackHeight = 6;
const double _kThumbRadius = 10;
const double _kOverlayRadius = 18;

// RoundedRectSliderTrackShape 会把离散滑块的首尾位置各向内收半个
// trackHeight；这里与显式指定的 overlay/track 参数保持同一套几何口径。
const double _kMarkerTrackInset = _kOverlayRadius + _kTrackHeight / 2;

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

  /// 拖动进度或点击技巧节点后的步骤跳转回调。
  final Future<void> Function(int stepIndex) onStepSelected;

  /// 关卡技巧标签（包含前置技巧；等级最高的一项是本关主技巧）。
  final Set<TechniqueId> targetTechniques;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TechniqueId taughtTechnique = _taughtTechniqueOf(
      targetTechniques,
      steps,
    );
    final List<int> keyPointIndices = _keyPointIndicesOf(
      steps,
      taughtTechnique,
    );
    final bool canScrub = steps.length > 1;
    final int currentKeyPointOffset = keyPointIndices.indexOf(currentIndex);
    final int? keyPointDestination = keyPointIndices.isEmpty
        ? null
        : currentKeyPointOffset < 0
            ? keyPointIndices.first
            : currentKeyPointOffset + 1 < keyPointIndices.length
                ? keyPointIndices[currentKeyPointOffset + 1]
                : null;
    final String keyPointTooltip = keyPointIndices.isEmpty
        ? context.l10n.text('本关技巧暂无关键点')
        : currentKeyPointOffset < 0
            ? context.l10n.text('跳到本关技巧第一个关键点')
            : keyPointDestination != null
                ? context.l10n.text('跳到本关技巧下一个关键点')
                : context.l10n.text('已到本关技巧最后一个关键点');

    void selectStep(int stepIndex) {
      if (stepIndex != currentIndex) {
        onStepSelected(stepIndex);
      }
    }

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
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget title = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.route_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        context.l10n.text('技巧进度'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                  final Widget instruction = Text(
                    context.l10n.text('拖动或点击进度条可跳到任意步骤'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                  if (constraints.maxWidth < 440) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        title,
                        const SizedBox(height: AppSpacing.xs),
                        instruction,
                      ],
                    );
                  }
                  return Row(
                    children: <Widget>[
                      title,
                      const Spacer(),
                      instruction,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 44,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double markerSize = 8;
                    final double usableWidth =
                        constraints.maxWidth > _kMarkerTrackInset * 2
                            ? constraints.maxWidth - _kMarkerTrackInset * 2
                            : 0;
                    return Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: _kTrackHeight,
                            trackShape: const RoundedRectSliderTrackShape(),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: _kThumbRadius,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: _kOverlayRadius,
                            ),
                            activeTrackColor: scheme.primary,
                            inactiveTrackColor: scheme.surfaceContainerHighest,
                            thumbColor: scheme.primary,
                            overlayColor:
                                scheme.primary.withValues(alpha: 0.12),
                            // 技巧节点已经由上层单独标出；逐步刻度既过密，
                            // 也会与当前滑块和技巧节点形成重影。
                            tickMarkShape: SliderTickMarkShape.noTickMark,
                          ),
                          child: Slider(
                            key: const ValueKey<String>('demo-step-slider'),
                            value: currentIndex.toDouble(),
                            min: 0,
                            max: canScrub ? (steps.length - 1).toDouble() : 1,
                            divisions: canScrub ? steps.length - 1 : null,
                            label: '${currentIndex + 1}/${steps.length}',
                            semanticFormatterCallback: (double value) =>
                                context.l10n.text(
                              '第 {step} 步，共 {total} 步',
                              <String, Object?>{
                                'step': value.round() + 1,
                                'total': steps.length,
                              },
                            ),
                            onChanged: canScrub
                                ? (double value) => selectStep(value.round())
                                : null,
                          ),
                        ),
                        // 节点仅负责标记；IgnorePointer 保证整条滑杆都可拖动，
                        // 不会被节点的命中区域截断手势。
                        IgnorePointer(
                          child: Stack(
                            children: <Widget>[
                              for (final int keyPointIndex in keyPointIndices)
                                // 当前关键点的位置已由滑块拇指清晰表示，避免
                                // 两个圆点重叠形成截图中的“双节点”。
                                if (keyPointIndex != currentIndex)
                                  Positioned(
                                    left: _kMarkerTrackInset +
                                        usableWidth *
                                            _positionOf(
                                              keyPointIndex,
                                              steps.length,
                                            ) -
                                        markerSize / 2,
                                    top: 18,
                                    child: Container(
                                      key: ValueKey<String>(
                                        'demo-progress-marker-${taughtTechnique.id}-$keyPointIndex',
                                      ),
                                      width: markerSize,
                                      height: markerSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: keyPointIndex < currentIndex
                                            ? scheme.onPrimary
                                            : scheme.surface,
                                        border: Border.all(
                                          color: scheme.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                key: const ValueKey<String>('demo-current-technique-key-point'),
                alignment: Alignment.centerLeft,
                child: _TechniqueKeyPointChip(
                  technique: taughtTechnique,
                  tooltip: keyPointTooltip,
                  onTap: keyPointDestination == null
                      ? null
                      : () => selectStep(keyPointDestination),
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

  /// 关卡标签同时含前置技巧；最高等级的一项与关卡标题中的主技巧一致。
  static TechniqueId _taughtTechniqueOf(
    Set<TechniqueId> levelTechniques,
    List<ScriptStep> steps,
  ) {
    for (final TechniqueId technique in TechniqueId.values.reversed) {
      if (levelTechniques.contains(technique)) {
        return technique;
      }
    }
    // 防御旧数据缺少 techniqueTags：仍选择脚本中等级最高的技巧。
    final Set<TechniqueId> scriptedTechniques = <TechniqueId>{
      for (final ScriptStep step in steps) step.techniqueId,
    };
    for (final TechniqueId technique in TechniqueId.values.reversed) {
      if (scriptedTechniques.contains(technique)) {
        return technique;
      }
    }
    return steps.first.techniqueId;
  }

  /// 只收集本关主技巧的全部出现位置，不混入任何前置/辅助技巧。
  static List<int> _keyPointIndicesOf(
    List<ScriptStep> steps,
    TechniqueId taughtTechnique,
  ) =>
      <int>[
        for (int i = 0; i < steps.length; i++)
          if (steps[i].techniqueId == taughtTechnique) i,
      ];
}

class _TechniqueKeyPointChip extends StatelessWidget {
  const _TechniqueKeyPointChip({
    required this.technique,
    required this.tooltip,
    required this.onTap,
  });

  final TechniqueId technique;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        key: ValueKey<String>('demo-technique-${technique.id}'),
        label: Text(context.l10n.techniqueName(technique)),
        onPressed: onTap,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
