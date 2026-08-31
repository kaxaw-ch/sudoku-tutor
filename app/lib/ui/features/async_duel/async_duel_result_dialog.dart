/// 离线异步对决完成后的成绩码弹窗。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sudoku_tutor/domain/duel/async_duel_codec.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 离线挑战结算弹窗。
abstract final class AsyncDuelResultDialog {
  /// 显示成绩并返回是否前往对决大厅。
  static Future<bool?> show(
    BuildContext context, {
    required AsyncDuelResult result,
  }) {
    final String code = AsyncDuelCodec.encodeResult(result);
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: const Icon(Icons.emoji_events, size: 44),
        title: const Text('挑战完成！'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  '${result.playerName} · 用时 ${_formatDuration(result.elapsedMs)}'
                  ' · 错误 ${result.wrongCount}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '计分 ${_formatDuration(result.scoreMs)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    code,
                    key: const ValueKey<String>('duel-result-code'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  '把成绩码发给对方，再到对决大厅比较胜负。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('成绩码已复制')));
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制成绩码'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('返回对决大厅'),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int milliseconds) {
    final int totalSeconds = milliseconds ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
