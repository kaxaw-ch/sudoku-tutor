/// 输入意图 —— 桌面快捷键与移动键盘的统一语义（P0-UI-04/05，T-UI-03）。
///
/// 桌面端经 `Shortcuts/Actions` 把物理按键映射为 [Intent]；
/// 移动端自绘键盘直接调用同一组回调（[GameInputCallbacks]）。
/// 两端的「意图 → 对局控制器」映射收敛到 [GameInputCallbacks]，零漂移。
library;

import 'package:flutter/widgets.dart';

/// 选区移动方向（桌面方向键）。
enum MoveDirection {
  /// 上。
  up('up'),

  /// 下。
  down('down'),

  /// 左。
  left('left'),

  /// 右。
  right('right');

  const MoveDirection(this.id);

  /// 稳定标识。
  final String id;
}

// ================================================================ Intents

/// 在选中格输入数字 [digit]。
class InputDigitIntent extends Intent {
  /// 构造意图。
  const InputDigitIntent(this.digit);

  /// 数字 1..9。
  final int digit;
}

/// 为选中格切换数字 [digit] 的手动笔记（Shift+1-9）。
class ToggleNoteIntent extends Intent {
  /// 构造意图。
  const ToggleNoteIntent(this.digit);

  /// 数字 1..9。
  final int digit;
}

/// 切换笔记模式（主路径：笔记模式键）。
class ToggleNoteModeIntent extends Intent {
  /// 构造意图。
  const ToggleNoteModeIntent();
}

/// 清除选中格（Del / Backspace）。
class ClearCellIntent extends Intent {
  /// 构造意图。
  const ClearCellIntent();
}

/// 撤销（Ctrl+Z）。
class UndoIntent extends Intent {
  /// 构造意图。
  const UndoIntent();
}

/// 重做（Ctrl+Y / Ctrl+Shift+Z）。
class RedoIntent extends Intent {
  /// 构造意图。
  const RedoIntent();
}

/// 请求提示（H）。
class RequestHintIntent extends Intent {
  /// 构造意图。
  const RequestHintIntent();
}

/// 核对答案（N）。
class CheckAnswerIntent extends Intent {
  /// 构造意图。
  const CheckAnswerIntent();
}

/// 暂停 / 退出（Esc）。
class PauseIntent extends Intent {
  /// 构造意图。
  const PauseIntent();
}

/// 移动选区（方向键）。
class MoveSelectionIntent extends Intent {
  /// 构造意图。
  const MoveSelectionIntent(this.direction);

  /// 方向。
  final MoveDirection direction;
}

// ================================================================ 回调聚合

/// 输入回调聚合 —— 桌面快捷键与移动键盘共用的一组回调。
///
/// UI 页面层把 [GameInputCallbacks] 接到 `GameSessionController` 的方法：
/// `onDigit → inputDigit`、`onUndo → undo` 等，输入层不感知控制器。
class GameInputCallbacks {
  /// 构造回调聚合（全部可空，未提供则对应输入被忽略）。
  const GameInputCallbacks({
    required this.onDigit,
    this.onToggleNote,
    this.onToggleNoteMode,
    this.onAutoNotes,
    this.onClearCell,
    this.onUndo,
    this.onRedo,
    this.onRequestHint,
    this.onCheckAnswer,
    this.onPause,
    this.onMoveSelection,
    this.onSelectCell,
  });

  /// 输入数字（填数；笔记模式下由控制器转笔记）。
  final void Function(int digit) onDigit;

  /// 切换指定数字的笔记。
  final void Function(int digit)? onToggleNote;

  /// 切换笔记模式。
  final VoidCallback? onToggleNoteMode;

  /// 一次性为全部空格填写合法候选数。
  final VoidCallback? onAutoNotes;

  /// 清除选中格。
  final VoidCallback? onClearCell;

  /// 撤销。
  final VoidCallback? onUndo;

  /// 重做。
  final VoidCallback? onRedo;

  /// 请求提示。
  final VoidCallback? onRequestHint;

  /// 核对答案。
  final VoidCallback? onCheckAnswer;

  /// 暂停/继续。
  final VoidCallback? onPause;

  /// 移动选区。
  final void Function(MoveDirection direction)? onMoveSelection;

  /// 直接选中一格。
  final void Function(int index)? onSelectCell;
}

// ================================================================ Actions

/// 数字输入 Action。
class InputDigitAction extends Action<InputDigitIntent> {
  /// 构造 Action。
  InputDigitAction(this.onInvoke);

  /// 回调。
  final void Function(int) onInvoke;

  @override
  Object? invoke(InputDigitIntent intent) {
    onInvoke(intent.digit);
    return null;
  }
}

/// 笔记切换 Action。
class ToggleNoteAction extends Action<ToggleNoteIntent> {
  /// 构造 Action。
  ToggleNoteAction(this.onInvoke);

  /// 回调。
  final void Function(int) onInvoke;

  @override
  Object? invoke(ToggleNoteIntent intent) {
    onInvoke(intent.digit);
    return null;
  }
}

/// 无参回调 Action（笔记模式/清除/撤销/重做/提示/核对/暂停）。
class SimpleAction extends Action<Intent> {
  /// 构造 Action；[handles] 指定要响应的 Intent 类型。
  SimpleAction(this.onInvoke, this._handles);

  /// 回调。
  final VoidCallback onInvoke;

  final Type _handles;

  @override
  bool isEnabled(Intent intent) => intent.runtimeType == _handles;

  @override
  Object? invoke(Intent intent) {
    onInvoke();
    return null;
  }
}

/// 选区移动 Action。
class MoveSelectionAction extends Action<MoveSelectionIntent> {
  /// 构造 Action。
  MoveSelectionAction(this.onInvoke);

  /// 回调。
  final void Function(MoveDirection) onInvoke;

  @override
  Object? invoke(MoveSelectionIntent intent) {
    onInvoke(intent.direction);
    return null;
  }
}
