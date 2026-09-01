/// 移动端数字键盘（T-UI-03，P0-UI-04）。
///
/// - **不弹系统键盘**：常驻自绘键盘；
/// - 数字 1-9 排布 3×3，每键带「已出现次数」角标；已出现 9 次置灰仍可点；
/// - 底部一行：自动笔记、擦除、填数/笔记切换（[showFunctionRow]=false 时隐藏——
///   桌面横向布局中功能条已有相同操作，避免重复键）。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

import 'input_intents.dart';

/// 数字键盘总高（固定值）。
///
/// ⚠️ 必须固定：若让键盘随宽度自适应（如 `GridView.count + shrinkWrap`，
/// 键高 = 键宽 ÷ 比例），在宽窗口（如 800px）下键盘会爆高到 600px+，
/// 把棋盘 `Expanded` 挤成 0 高 → `BoardGeometry` 断言崩溃 / Column 溢出。
/// 固定高度后键在行内自适应宽度、高度由三行均分，任何窗口都稳定。
const double kNumpadHeight = 368;

/// 只显示 3×3 数字区时的高度。
const double kNumpadDigitsOnlyHeight = 288;

/// 移动端数字键盘。
class NumpadPanel extends StatelessWidget {
  /// 构造键盘。
  const NumpadPanel({
    required this.callbacks,
    required this.digitCounts,
    required this.noteMode,
    this.autoNotesFilled = false,
    this.showFunctionRow = true,
    super.key,
  });

  /// 输入回调。
  final GameInputCallbacks callbacks;

  /// 数字出现次数表（索引 0..9；`digitCounts[d]` = 数字 d 在全盘出现次数）。
  final List<int> digitCounts;

  /// 是否笔记模式。
  final bool noteMode;

  /// 自动候选或一次性自动笔记是否已经填入。
  final bool autoNotesFilled;

  /// 是否显示底部功能行（笔记/擦除）。
  ///
  /// 桌面横向布局传 `false`：功能条已含这些键，避免重复；
  /// 移动端竖排保持 `true`（笔记键是主路径）。
  final bool showFunctionRow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: showFunctionRow ? kNumpadHeight : kNumpadDigitsOnlyHeight,
      child: Column(
        children: <Widget>[
          // 3×3 数字区：三行，每行三个键自适应均分宽度。
          for (int r = 0; r < 3; r++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int c = 0; c < 3; c++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _DigitKey(
                            digit: r * 3 + c + 1,
                            count: digitCounts.length > r * 3 + c + 1
                                ? digitCounts[r * 3 + c + 1]
                                : 0,
                            fullyPlaced: digitCounts.length > r * 3 + c + 1 &&
                                digitCounts[r * 3 + c + 1] >= 9,
                            onTap: () => callbacks.onDigit(r * 3 + c + 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (showFunctionRow) ...<Widget>[
            const SizedBox(height: 4),
            // 底部功能行：把高频的填数/笔记切换固定在最右侧。
            Row(
              children: <Widget>[
                Expanded(
                  child: _FunctionKey(
                    icon: Icons.auto_awesome,
                    label: '自动笔记',
                    emphasized: autoNotesFilled,
                    onTap: callbacks.onAutoNotes,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FunctionKey(
                    icon: Icons.backspace_outlined,
                    label: '擦除',
                    onTap: callbacks.onClearCell,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FunctionKey(
                    icon: noteMode ? Icons.edit_note : Icons.dialpad_rounded,
                    label: noteMode ? '填数' : '笔记',
                    emphasized: noteMode,
                    onTap: callbacks.onToggleNoteMode,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 单个数字键。
class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.count,
    required this.fullyPlaced,
    required this.onTap,
  });

  final int digit;
  final int count;
  final bool fullyPlaced;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = fullyPlaced
        ? theme.colorScheme.outlineVariant
        : theme.colorScheme.onSurface;
    return Material(
      key: ValueKey<String>('numpad-digit-$digit'),
      color: fullyPlaced
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.primaryContainer.withValues(alpha: 0.44),
      elevation: fullyPlaced ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: fullyPlaced
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap, // 置灰仍可点。
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Text(
              '$digit',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            Positioned(
              top: 4,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fullyPlaced
                        ? theme.colorScheme.outline
                        : theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 底部功能键。
class _FunctionKey extends StatelessWidget {
  const _FunctionKey({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color fg =
        emphasized ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return Material(
      color: emphasized
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 23, color: fg),
              const SizedBox(height: 3),
              Text(context.l10n.text(label),
                  style: theme.textTheme.labelSmall?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
