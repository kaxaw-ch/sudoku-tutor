/// 自动核验通过后的恭喜动画测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/widgets/congratulations_animation.dart';

void main() {
  testWidgets('展示彩屑、核验文案并可关闭', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => FilledButton(
              onPressed: () => CongratulationsAnimation.show(context),
              child: const Text('完成'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('完成'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey<String>('congratulations-animation')),
      findsOneWidget,
    );
    expect(find.text('恭喜完成！'), findsOneWidget);
    expect(find.text('自动核验通过，整盘全部正确。'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);

    await tester.tap(find.text('太棒了'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('congratulations-animation')),
      findsNothing,
    );
  });
}
