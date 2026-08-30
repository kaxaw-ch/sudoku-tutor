/// 功能条统一主题配色 golden：默认同色，激活态使用主题实色。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/input/action_bar.dart';
import 'package:sudoku_tutor/ui/input/input_intents.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

void main() {
  testWidgets('功能条 golden：统一主题色 + 笔记激活态', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(620, 140));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: ActionBar(
              callbacks: GameInputCallbacks(
                onDigit: _noopDigit,
                onToggleNoteMode: _noop,
                onAutoNotes: _noop,
                onClearCell: _noop,
                onUndo: _noop,
                onRedo: _noop,
                onRequestHint: _noop,
                onCheckAnswer: _noop,
                onPause: _noop,
              ),
              canUndo: true,
              canRedo: true,
              noteMode: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(ActionBar),
      matchesGoldenFile('goldens/action_palette.png'),
    );
  });
}

void _noop() {}

void _noopDigit(int _) {}
