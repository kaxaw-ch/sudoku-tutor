/// T-EDU-05 · 验收试炼关结算卡组件测试（S-05）。
///
/// 覆盖：显示用时/错误次数、返回章节与下一关按钮、无下一关时隐藏「下一关」、
/// 用时格式化（`mm:ss`）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/features/trial/result_sheet.dart';
import 'package:sudoku_tutor/ui/widgets/congratulations_animation.dart';

void main() {
  test('用时格式化 mm:ss', () {
    expect(TrialResultSheet.formatDuration(0), '00:00');
    expect(TrialResultSheet.formatDuration(65000), '01:05');
    expect(TrialResultSheet.formatDuration(3723000), '62:03');
  });

  testWidgets('结算卡：用时/错误次数 + 返回章节/下一关', (WidgetTester tester) async {
    bool backTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () => TrialResultSheet.show(
                  context,
                  elapsedMs: 83000,
                  errorCount: 2,
                  hasNext: true,
                  onBackToMap: () => backTapped = true,
                  onNextLevel: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('挑战通过！'), findsOneWidget);
    expect(find.byType(CelebrationTrophy), findsOneWidget);
    expect(find.text('自动核验通过，整盘全部正确。'), findsOneWidget);
    expect(find.text('用时'), findsOneWidget);
    expect(find.text('01:23'), findsOneWidget);
    expect(find.text('错误次数'), findsOneWidget);
    expect(find.text('2 次'), findsOneWidget);
    expect(find.text('返回章节'), findsOneWidget);
    expect(find.text('下一关'), findsOneWidget);

    await tester.tap(find.text('返回章节'));
    await tester.pumpAndSettle();
    expect(backTapped, isTrue);
  });

  testWidgets('点击「下一关」触发 onNextLevel', (WidgetTester tester) async {
    bool nextTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () => TrialResultSheet.show(
                  context,
                  elapsedMs: 1000,
                  errorCount: 0,
                  hasNext: true,
                  onBackToMap: () {},
                  onNextLevel: () => nextTapped = true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一关'));
    await tester.pumpAndSettle();
    expect(nextTapped, isTrue);
  });

  testWidgets('无下一关时隐藏「下一关」按钮', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () => TrialResultSheet.show(
                  context,
                  elapsedMs: 1000,
                  errorCount: 0,
                  hasNext: false,
                  onBackToMap: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('返回章节'), findsOneWidget);
    expect(find.text('下一关'), findsNothing);
  });
}
