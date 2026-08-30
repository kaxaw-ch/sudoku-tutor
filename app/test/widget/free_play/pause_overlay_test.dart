/// T-UI-04 · 暂停遮挡层测试（S-06 / P0-PRA-08）。
///
/// 覆盖：
/// - 遮挡盘面（半透明遮罩在 Stack 中铺满）；
/// - 用时 `mm:ss` 格式化展示；
/// - 单击空白区域继续；暂停卡片仅保留「放弃」按钮。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/features/free_play/pause_overlay.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

void main() {
  Future<void> pumpOverlay(
    WidgetTester tester, {
    required int elapsedMs,
    required VoidCallback onResume,
    required VoidCallback onQuit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              const Positioned.fill(child: ColoredBox(color: Colors.white)),
              PauseOverlay(
                elapsedMs: elapsedMs,
                onResume: onResume,
                onQuit: onQuit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('暂停遮挡：文案与用时展示', (WidgetTester tester) async {
    await pumpOverlay(
      tester,
      elapsedMs: 65000,
      onResume: () {},
      onQuit: () {},
    );
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('用时 01:05'), findsOneWidget, reason: '65000ms = 01:05');
    expect(find.text('单击空白区域继续'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    expect(find.text('放弃'), findsOneWidget);
  });

  testWidgets('用时格式：0ms → 00:00，59s → 00:59', (WidgetTester tester) async {
    await pumpOverlay(
      tester,
      elapsedMs: 0,
      onResume: () {},
      onQuit: () {},
    );
    expect(find.text('用时 00:00'), findsOneWidget);

    await pumpOverlay(
      tester,
      elapsedMs: 59000,
      onResume: () {},
      onQuit: () {},
    );
    expect(find.text('用时 00:59'), findsOneWidget);
  });

  testWidgets('单击空白区域继续；点击放弃不会误触继续', (WidgetTester tester) async {
    int resumed = 0;
    int quit = 0;
    await pumpOverlay(
      tester,
      elapsedMs: 1000,
      onResume: () => resumed++,
      onQuit: () => quit++,
    );

    final Rect resumeArea = tester.getRect(
      find.byKey(const ValueKey<String>('pause-resume-area')),
    );
    await tester.tapAt(resumeArea.topLeft + const Offset(16, 16));
    expect(resumed, 1);
    expect(quit, 0);

    await tester.tap(find.text('放弃'));
    expect(quit, 1);
    expect(resumed, 1);
  });
}
