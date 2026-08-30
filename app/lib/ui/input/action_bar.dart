/// 对局功能条（撤销/重做/擦除/自动笔记/提示/核对/填数与笔记切换）。
///
/// 全部经 [GameInputCallbacks] 分发，与桌面快捷键/移动键盘同一语义。
library;

import 'package:flutter/material.dart';

import 'input_intents.dart';

/// 桌面做题页右侧操作区宽度。
///
/// 为 7 个放大后的功能键预留单行空间，同时保持棋盘仍有充足宽度。
const double kDesktopGamePanelWidth = 456;

/// 功能键统一触控边长。
const double kActionBarButtonExtent = 52;

/// 功能条。
class ActionBar extends StatelessWidget {
  /// 构造功能条。
  const ActionBar({
    required this.callbacks,
    this.canUndo = false,
    this.canRedo = false,
    this.noteMode = false,
    this.autoNotesFilled = false,
    super.key,
  });

  /// 输入回调。
  final GameInputCallbacks callbacks;

  /// 是否可撤销。
  final bool canUndo;

  /// 是否可重做。
  final bool canRedo;

  /// 是否笔记模式。
  final bool noteMode;

  /// 自动候选或一次性自动笔记是否已经填入。
  final bool autoNotesFilled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _BarButton(
          icon: Icons.undo,
          tooltip: '撤销（Ctrl+Z）',
          onTap: canUndo ? callbacks.onUndo : null,
        ),
        _BarButton(
          icon: Icons.redo,
          tooltip: '重做（Ctrl+Y）',
          onTap: canRedo ? callbacks.onRedo : null,
        ),
        _BarButton(
          icon: Icons.backspace_outlined,
          tooltip: '擦除（Del）',
          onTap: callbacks.onClearCell,
        ),
        _BarButton(
          icon: Icons.auto_awesome,
          tooltip: '自动笔记：填写全部合法候选数',
          emphasized: autoNotesFilled,
          onTap: callbacks.onAutoNotes,
        ),
        _BarButton(
          icon: Icons.lightbulb_outline,
          tooltip: '提示（H）',
          onTap: callbacks.onRequestHint,
        ),
        _BarButton(
          icon: Icons.fact_check_outlined,
          tooltip: '核对答案（N）',
          onTap: callbacks.onCheckAnswer,
        ),
        // 高频的填数入口放在最右侧：笔记模式下可一键回到填数。
        _BarButton(
          icon: noteMode ? Icons.edit_note : Icons.dialpad_rounded,
          tooltip: noteMode ? '填数模式（切换回大数字输入）' : '笔记模式（Shift+1-9 记笔记）',
          emphasized: noteMode,
          onTap: callbacks.onToggleNoteMode,
        ),
      ],
    );
  }
}

/// 单个功能按钮。
class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(kActionBarButtonExtent),
        fixedSize: const Size.square(kActionBarButtonExtent),
        backgroundColor: emphasized ? theme.colorScheme.primary : null,
        foregroundColor: emphasized ? theme.colorScheme.onPrimary : null,
      ),
    );
  }
}
