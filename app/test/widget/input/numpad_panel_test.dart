library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/input/input_intents.dart';
import 'package:sudoku_tutor/ui/input/numpad_panel.dart';

void main() {
  testWidgets('数字键具备足够触控高度，自动笔记按钮可用', (WidgetTester tester) async {
    int autoNotesTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: NumpadPanel(
                callbacks: GameInputCallbacks(
                  onDigit: (_) {},
                  onToggleNoteMode: () {},
                  onAutoNotes: () => autoNotesTaps++,
                  onClearCell: () {},
                ),
                digitCounts: List<int>.filled(10, 0),
                noteMode: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(NumpadPanel)).height, kNumpadHeight);
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('numpad-digit-1')))
          .height,
      greaterThanOrEqualTo(88),
    );

    await tester.tap(find.text('自动笔记'));
    expect(autoNotesTaps, 1);

    final Color unifiedColor = Theme.of(
      tester.element(find.byType(NumpadPanel)),
    ).colorScheme.surfaceContainerHighest;
    for (final String label in <String>['笔记', '自动笔记', '擦除']) {
      final Material key = tester.widget<Material>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(key.color, unifiedColor);
    }
    expect(find.byIcon(Icons.dialpad_rounded), findsOneWidget,
        reason: '普通填数状态下的“笔记”入口显示数字键盘图标');
  });

  testWidgets('笔记模式下“填数”按钮位于功能行最右侧且可切换', (WidgetTester tester) async {
    int toggleTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: NumpadPanel(
                callbacks: GameInputCallbacks(
                  onDigit: (_) {},
                  onToggleNoteMode: () => toggleTaps++,
                  onAutoNotes: () {},
                  onClearCell: () {},
                ),
                digitCounts: List<int>.filled(10, 0),
                noteMode: true,
              ),
            ),
          ),
        ),
      ),
    );

    final Finder fill = find.text('填数');
    expect(fill, findsOneWidget);
    expect(find.byIcon(Icons.edit_note), findsOneWidget,
        reason: '笔记模式激活时的“填数”入口显示笔记图标');
    expect(
      tester.getCenter(fill).dx,
      greaterThan(tester.getCenter(find.text('擦除')).dx),
    );
    await tester.tap(fill);
    expect(toggleTaps, 1);
  });
}
