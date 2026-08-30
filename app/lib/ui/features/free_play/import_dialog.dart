/// 文本导入对话框（S-07 底部入口 / P0-PRA-10，T-UI-04）。
///
/// - 支持手输 81 位字符串 / 多行粘贴，以及「从剪贴板导入」一键粘贴；
/// - 走 [PuzzleImportService]：格式校验（`E_IMPORT_001`）与唯一解校验
///   （`E_IMPORT_002`），错误以中文提示展示在对话框内；
/// - 成功回调 [onImported]，由调用方（难度选择页）把题目直接送入对局。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_import_service.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';

import '../../theme/spacing.dart';

/// 文本导入对话框。
class ImportDialog extends ConsumerStatefulWidget {
  /// 构造对话框。
  const ImportDialog({super.key});

  /// 打开对话框并返回导入结果（`Puzzle` 或 `null` 表示取消/失败）。
  static Future<Puzzle?> show(BuildContext context) => showDialog<Puzzle>(
        context: context,
        builder: (_) => const ImportDialog(),
      );

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _importing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 从剪贴板读取并填入输入框。
  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    final String? text = data?.text;
    if (text == null || text.trim().isEmpty) {
      setState(() => _error = '剪贴板为空');
      return;
    }
    setState(() {
      _controller.text = text;
      _error = null;
    });
  }

  /// 执行导入。
  Future<void> _import() async {
    final String raw = _controller.text;
    if (raw.trim().isEmpty) {
      setState(() => _error = '请输入 81 位题目字符串');
      return;
    }
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final PuzzleImportService service = ref.read(puzzleImportServiceProvider);
      final Puzzle puzzle = await service.import(raw);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(puzzle);
    } on AppError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message; // E_IMPORT_001 / E_IMPORT_002 中文消息。
        _importing = false;
      });
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '导入失败：$e';
        _importing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('从文本导入题目'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '粘贴 81 位题目字符串（0/./空格表示空格，可含换行与竖线）。'
              '导入前将校验格式与唯一解。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              enabled: !_importing,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: '例如：530070000600195000…',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                TextButton.icon(
                  onPressed: _importing ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('从剪贴板导入'),
                ),
                Text(
                  '建议 81 位',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _importing ? null : _import,
          child: _importing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('导入'),
        ),
      ],
    );
  }
}
