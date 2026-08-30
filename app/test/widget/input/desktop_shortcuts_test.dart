/// T-UI-03 · 桌面快捷键 widget 测试（P0-UI-05）。
///
/// 覆盖：数字键 1-9、小键盘、Shift+1-9（笔记）、Del、Ctrl+Z、Ctrl+Y、
/// Ctrl+Shift+Z、N、H、Esc、方向键 —— 全部经 [GameInputCallbacks] 触发。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/input/desktop_shortcuts.dart';
import 'package:sudoku_tutor/ui/input/input_intents.dart';

void main() {
  /// 模拟一次完整按键（down + up）。
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    LogicalKeyboardKey? modifier,
  }) async {
    if (modifier != null) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyDownEvent(key);
    await tester.sendKeyUpEvent(key);
    if (modifier != null) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();
  }

  Future<List<String>> runTest(
    WidgetTester tester, {
    required void Function(GameInputCallbacks callbacks) bind,
  }) async {
    final List<String> invoked = <String>[];
    final GameInputCallbacks callbacks = GameInputCallbacks(
      onDigit: (int d) => invoked.add('digit$d'),
      onToggleNote: (int d) => invoked.add('note$d'),
      onToggleNoteMode: () => invoked.add('toggleNoteMode'),
      onClearCell: () => invoked.add('clear'),
      onUndo: () => invoked.add('undo'),
      onRedo: () => invoked.add('redo'),
      onRequestHint: () => invoked.add('hint'),
      onCheckAnswer: () => invoked.add('check'),
      onPause: () => invoked.add('pause'),
      onMoveSelection: (MoveDirection dir) => invoked.add('move${dir.id}'),
    );
    bind(callbacks);
    await tester.pumpWidget(
      MaterialApp(
        // ⚠️ Focus 必须在 DesktopShortcuts 内部：按键事件从焦点节点向上冒泡，
        // Shortcuts/Actions 在祖先路径上才能拦截（Focus 在外部则事件不会经过它）。
        home: DesktopShortcuts(
          callbacks: callbacks,
          child: Focus(
            autofocus: true,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      ),
    );
    return invoked;
  }

  testWidgets('数字键 1-9 触发 onDigit', (WidgetTester tester) async {
    final List<String> invoked = await runTest(tester, bind: (_) {});
    for (int d = 1; d <= 9; d++) {
      await press(
          tester, LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + d));
    }
    expect(invoked, <String>[
      for (int d = 1; d <= 9; d++) 'digit$d',
    ]);
  });

  testWidgets('小键盘 1-9 触发 onDigit', (WidgetTester tester) async {
    final List<String> invoked = await runTest(tester, bind: (_) {});
    await press(
        tester, LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + 5));
    expect(invoked, <String>['digit5']);
  });

  testWidgets('Shift+1-9 触发 onToggleNote', (WidgetTester tester) async {
    final List<String> invoked = await runTest(tester, bind: (_) {});
    await press(
      tester,
      LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + 3),
      modifier: LogicalKeyboardKey.shiftLeft,
    );
    expect(invoked, <String>['note3']);
  });

  testWidgets('Del 触发清除；Ctrl+Z / Ctrl+Y / Ctrl+Shift+Z 触发撤销重做',
      (WidgetTester tester) async {
    final List<String> invoked = await runTest(tester, bind: (_) {});
    await press(tester, LogicalKeyboardKey.delete);
    await press(
      tester,
      LogicalKeyboardKey.keyZ,
      modifier: LogicalKeyboardKey.controlLeft,
    );
    await press(
      tester,
      LogicalKeyboardKey.keyY,
      modifier: LogicalKeyboardKey.controlLeft,
    );
    await press(
      tester,
      LogicalKeyboardKey.keyZ,
      modifier: LogicalKeyboardKey.controlLeft,
    );
    await press(tester, LogicalKeyboardKey.keyZ,
        modifier: LogicalKeyboardKey.controlLeft);
    // 第四次 Ctrl+Z 也触发撤销。
    expect(invoked, <String>['clear', 'undo', 'redo', 'undo', 'undo']);
  });

  testWidgets('N 核对 / H 提示 / Esc 暂停', (WidgetTester tester) async {
    final List<String> invoked = await runTest(tester, bind: (_) {});
    await press(tester, LogicalKeyboardKey.keyN);
    await press(tester, LogicalKeyboardKey.keyH);
    await press(tester, LogicalKeyboardKey.escape);
    expect(invoked, <String>['check', 'hint', 'pause']);
  });

  testWidgets('方向键触发选区移动', (WidgetTester tester) async {
    final List<String> invoked = await runTest(tester, bind: (_) {});
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(invoked, <String>['moveup', 'movedown', 'moveleft', 'moveright']);
  });

  testWidgets('Ctrl+Shift+Z 触发重做', (WidgetTester tester) async {
    final List<String> invoked = await runTest(tester, bind: (_) {});
    // 同时按下 Control + Shift + Z。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(invoked, <String>['redo']);
  });
}
