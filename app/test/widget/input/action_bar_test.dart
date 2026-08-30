/// 做题功能条的统一主题配色与激活态测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/input/action_bar.dart';
import 'package:sudoku_tutor/ui/input/input_intents.dart';

void main() {
  const GameInputCallbacks callbacks = GameInputCallbacks(
    onDigit: _noopDigit,
    onToggleNoteMode: _noop,
    onAutoNotes: _noop,
    onClearCell: _noop,
    onUndo: _noop,
    onRedo: _noop,
    onRequestHint: _noop,
    onCheckAnswer: _noop,
    onPause: _noop,
  );

  testWidgets('七种功能按钮统一放大，右下功能条不再提供暂停', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: kDesktopGamePanelWidth - 48,
              child: ActionBar(
                callbacks: callbacks,
                canUndo: true,
                canRedo: true,
              ),
            ),
          ),
        ),
      ),
    );

    final List<IconButton> buttons = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .toList(growable: false);
    expect(buttons, hasLength(7));
    for (final IconButton button in buttons) {
      expect(
        button.style?.fixedSize?.resolve(<WidgetState>{}),
        const Size.square(kActionBarButtonExtent),
      );
    }
    final Set<double> rows = <double>{
      for (final IconButton button in buttons)
        tester.getCenter(find.byWidget(button)).dy,
    };
    expect(rows, hasLength(1), reason: '桌面右侧操作区内的功能键应保持同一行');
    expect(find.byTooltip('暂停（Esc）'), findsNothing);
  });

  testWidgets('笔记与自动笔记开启后改为实色激活态', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionBar(
            callbacks: callbacks,
            noteMode: true,
            autoNotesFilled: true,
          ),
        ),
      ),
    );

    final ColorScheme scheme = Theme.of(
      tester.element(find.byType(ActionBar)),
    ).colorScheme;
    for (final String tooltip in <String>[
      '填数模式（切换回大数字输入）',
      '自动笔记：填写全部合法候选数',
    ]) {
      final IconButton button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(tooltip),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        scheme.primary,
      );
    }

    final double fillX = tester.getCenter(find.byTooltip('填数模式（切换回大数字输入）')).dx;
    final double checkX = tester.getCenter(find.byTooltip('核对答案（N）')).dx;
    expect(fillX, greaterThan(checkX), reason: '填数模式按钮应固定在功能条最右侧');
    expect(find.byIcon(Icons.edit_note), findsOneWidget,
        reason: '笔记模式激活时按要求显示笔记图标');
  });

  testWidgets('不可用的提示按钮保持中性灰且无法点击', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ActionBar(
            callbacks: GameInputCallbacks(onDigit: _noopDigit),
          ),
        ),
      ),
    );

    final Finder finder = find.ancestor(
      of: find.byTooltip('提示（H）'),
      matching: find.byType(IconButton),
    );
    final IconButton button = tester.widget<IconButton>(finder);
    expect(button.onPressed, isNull);
    expect(button.style?.backgroundColor?.resolve(<WidgetState>{}), isNull);
  });
}

void _noop() {}

void _noopDigit(int _) {}
