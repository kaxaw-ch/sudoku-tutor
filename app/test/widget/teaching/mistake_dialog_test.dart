/// T-EDU-04 · 误操作即时纠正弹窗组件测试。
///
/// 覆盖：标题「这一步有问题」、两段（错在哪 + 正确思路）、
/// 单个「明白了」按钮（不给答案）、点击后关闭。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_message_repository.dart';
import 'package:sudoku_tutor/ui/features/practice_level/mistake_dialog.dart';

void main() {
  testWidgets('展示「错在哪 + 正确思路」两段 + 单按钮', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => Center(
              child: ElevatedButton(
                onPressed: () => MistakeDialog.show(
                  context,
                  const MistakeMessage(
                    what: '你在第 2 行第 2 列填入了 5，与终局解不符。',
                    how: '检查行、列、宫后重新判断。',
                  ),
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

    expect(find.text('这一步有问题'), findsOneWidget);
    expect(find.text('错在哪'), findsOneWidget);
    expect(find.textContaining('与终局解不符'), findsOneWidget);
    expect(find.text('正确思路'), findsOneWidget);
    expect(find.textContaining('重新判断'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '明白了'), findsOneWidget);
    // 不给答案：不存在「正确答案/填 6」等直出文案。
    expect(find.textContaining('填 6'), findsNothing);

    await tester.tap(find.text('明白了'));
    await tester.pumpAndSettle();
    expect(find.text('这一步有问题'), findsNothing, reason: '点击后弹窗关闭');
  });
}
