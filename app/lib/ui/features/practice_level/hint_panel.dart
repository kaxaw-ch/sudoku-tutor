/// 三级提示面板（T-EDU-03 / P0-EDU-04，S-04）。
///
/// 展示三级梯度的解锁状态：
/// - **必须逐级解锁**（一级 → 二级 → 三级）：未解锁级别显示占位卡片；
/// - **已用级别保留可回看**：已解锁级别全部可见，点击可切换展示；
/// - 任何级别都不显示「某格填几」（`HintState` 结构上无 Placement）。
library;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';

import '../../theme/spacing.dart';

/// 三级提示面板。
class HintPanel extends StatelessWidget {
  /// 构造提示面板。
  const HintPanel({
    required this.unlockedHints,
    required this.displayedHint,
    required this.onSelect,
    this.compact = false,
    super.key,
  });

  /// 已解锁的全部提示（按级别升序）。
  final List<HintState> unlockedHints;

  /// 当前展示的提示（高亮）。
  final HintState? displayedHint;

  /// 点击已解锁级别 → 回看该级别内容。
  final ValueChanged<HintState> onSelect;

  /// 紧凑模式（减少纵向占位）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (unlockedHints.isEmpty) {
      final SemanticColorStyle colors = GamePalette.hintLevelStyleOf(1);
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Card(
          key: const ValueKey<String>('hint-panel-empty'),
          color: colors.container,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            child: Row(
              children: <Widget>[
                Icon(Icons.lightbulb_outline, color: colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n
                        .text('点击「提示」按钮，提示将逐级解锁：一级→二级→三级。'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Map<int, HintState> byOrder = <int, HintState>{
      for (final HintState hint in unlockedHints) hint.level.order: hint,
    };
    final int activeOrder =
        displayedHint?.level.order ?? byOrder.keys.lastOrNull ?? 1;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) =>
          FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey<String>(
          'hint-panel-${displayedHint?.sceneFingerprint}-${unlockedHints.length}',
        ),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int order = 1;
              order <= HintRules.maxLevelOf(HintScope.teaching);
              order++)
            _LevelCard(
              order: order,
              hint: byOrder[order],
              active: order == activeOrder,
              compact: compact,
              onSelect: byOrder[order] == null
                  ? null
                  : () => onSelect(byOrder[order]!),
            ),
        ],
      ),
    );
  }
}

/// 单个级别卡片。
class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.order,
    required this.hint,
    required this.active,
    required this.compact,
    required this.onSelect,
  });

  final int order;
  final HintState? hint;
  final bool active;
  final bool compact;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final HintLevel? level = HintRules.ofOrder(order);
    final String levelName = level == null
        ? context.l10n.text(
            '第 {order} 级',
            <String, Object?>{'order': order},
          )
        : context.l10n.hintLevelName(level);
    final bool unlocked = hint != null;
    final SemanticColorStyle colors = GamePalette.hintLevelStyleOf(order);

    final Color background = unlocked
        ? colors.container.withValues(alpha: active ? 1 : 0.52)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final Color foreground = !unlocked
        ? theme.colorScheme.outline
        : active
            ? colors.accent
            : theme.colorScheme.onSurface;

    final String techniqueLabel = unlocked
        ? context.l10n.techniqueName(hint!.techniqueId)
        : context.l10n.text('尚未解锁');
    final String narration = unlocked
        ? context.l10n.hintNarration(hint!)
        : context.l10n.text('继续使用上一级提示后解锁');

    return AnimatedScale(
      scale: active ? 1 : 0.985,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.fromLTRB(
          AppSpacing.md,
          compact ? 2 : 4,
          AppSpacing.md,
          compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: !unlocked
                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.55)
                : active
                    ? colors.accent.withValues(alpha: 0.72)
                    : colors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onSelect,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 4,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: unlocked
                        ? colors.accent
                        : theme.colorScheme.outlineVariant,
                    child: Text(
                      '$order',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: unlocked
                            ? theme.colorScheme.surface
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '$levelName · $techniqueLabel',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!compact) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            narration,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: foreground,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (unlocked)
                    Icon(
                      active ? Icons.check_circle : Icons.chevron_right,
                      size: 18,
                      color: foreground,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
