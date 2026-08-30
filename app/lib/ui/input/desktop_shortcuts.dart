/// 桌面快捷键（P0-UI-05，T-UI-03）。
///
/// 用 Flutter 官方 `Shortcuts/Actions` 处理，不依赖 `RawKeyboard`：
/// - 方向键 ↑↓←→ → [MoveSelectionIntent]；
/// - 数字键 1-9（含小键盘）→ [InputDigitIntent]；
/// - `Shift+1-9` → [ToggleNoteIntent]（笔记）；
/// - `Del` / `Backspace` → [ClearCellIntent]；
/// - `Ctrl+Z` → 撤销；`Ctrl+Y` / `Ctrl+Shift+Z` → 重做；
/// - `N` → 核对答案；`H` → 请求提示；`Esc` → 暂停。
///
/// 所有意图经 [GameInputCallbacks] 分发到对局控制器；测试可直接注入回调。
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'input_intents.dart';

/// 桌面快捷键包装。
class DesktopShortcuts extends StatelessWidget {
  /// 构造快捷键层。
  const DesktopShortcuts({
    required this.callbacks,
    required this.child,
    super.key,
  });

  /// 输入回调。
  final GameInputCallbacks callbacks;

  /// 包裹的子树。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        // ---- 方向键 ----
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            MoveSelectionIntent(MoveDirection.up),
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            MoveSelectionIntent(MoveDirection.down),
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            MoveSelectionIntent(MoveDirection.left),
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            MoveSelectionIntent(MoveDirection.right),
        // ---- 数字键 1-9（主键盘 + 小键盘，keyId 连续递增）----
        for (int d = 1; d <= 9; d++) ...<ShortcutActivator, Intent>{
          SingleActivator(
                  LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + d)):
              InputDigitIntent(d),
          SingleActivator(
                  LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + d)):
              InputDigitIntent(d),
        },
        // ---- Shift+1-9 → 笔记 ----
        for (int d = 1; d <= 9; d++)
          SingleActivator(
            LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + d),
            shift: true,
          ): ToggleNoteIntent(d),
        // ---- 清除 ----
        const SingleActivator(LogicalKeyboardKey.delete): ClearCellIntent(),
        const SingleActivator(LogicalKeyboardKey.backspace): ClearCellIntent(),
        // ---- 撤销 / 重做 ----
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            UndoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            RedoIntent(),
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): RedoIntent(),
        // ---- 功能键 ----
        const SingleActivator(LogicalKeyboardKey.keyN): CheckAnswerIntent(),
        const SingleActivator(LogicalKeyboardKey.keyH): RequestHintIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): PauseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          InputDigitIntent: InputDigitAction(callbacks.onDigit),
          ToggleNoteIntent: ToggleNoteAction(
            callbacks.onToggleNote ?? (_) {},
          ),
          ToggleNoteModeIntent: SimpleAction(
            callbacks.onToggleNoteMode ?? () {},
            ToggleNoteModeIntent,
          ),
          ClearCellIntent: SimpleAction(
            callbacks.onClearCell ?? () {},
            ClearCellIntent,
          ),
          UndoIntent: SimpleAction(callbacks.onUndo ?? () {}, UndoIntent),
          RedoIntent: SimpleAction(callbacks.onRedo ?? () {}, RedoIntent),
          RequestHintIntent: SimpleAction(
            callbacks.onRequestHint ?? () {},
            RequestHintIntent,
          ),
          CheckAnswerIntent: SimpleAction(
            callbacks.onCheckAnswer ?? () {},
            CheckAnswerIntent,
          ),
          PauseIntent: SimpleAction(callbacks.onPause ?? () {}, PauseIntent),
          MoveSelectionIntent: MoveSelectionAction(
            callbacks.onMoveSelection ?? (_) {},
          ),
        },
        child: child,
      ),
    );
  }
}
