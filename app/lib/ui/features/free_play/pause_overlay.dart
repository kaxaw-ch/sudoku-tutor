/// 暂停遮挡层（S-06 / P0-PRA-08，T-UI-04）。
///
/// 暂停时**遮挡盘面**（半透明遮罩盖住整屏），显示当前用时；单击卡片外
/// 的空白区域继续，仅保留「放弃」按钮。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

import '../../theme/spacing.dart';

/// 暂停遮挡层。
class PauseOverlay extends StatelessWidget {
  /// 构造遮挡层。
  const PauseOverlay({
    required this.elapsedMs,
    required this.onResume,
    required this.onQuit,
    super.key,
  });

  /// 当前用时（毫秒）。
  final int elapsedMs;

  /// 继续（恢复计时并收起遮挡）。
  final VoidCallback onResume;

  /// 放弃本局（清除断点并返回）。
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Semantics(
            button: true,
            label: context.l10n.text('单击空白区域继续'),
            child: GestureDetector(
              key: const ValueKey<String>('pause-resume-area'),
              behavior: HitTestBehavior.opaque,
              onTap: onResume,
              child: ColoredBox(
                color: theme.colorScheme.surface.withValues(alpha: 0.92),
              ),
            ),
          ),
          Center(
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      context.l10n.text('已暂停'),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.l10n.text(
                        '用时 {time}',
                        <String, Object?>{'time': _format(elapsedMs)},
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.touch_app_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          context.l10n.text('单击空白区域继续'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: onQuit,
                      icon: const Icon(Icons.flag_outlined),
                      label: Text(context.l10n.text('放弃')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 毫秒 → `mm:ss`。
  static String _format(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
