/// T-UI-01 · 响应式外壳测试（居中限宽 + 最小窗口 900×640 等比缩放）。
///
/// 窗口尺寸用 `tester.view.physicalSize + devicePixelRatio=1.0` 精确控制
/// 逻辑尺寸（`setSurfaceSize` 在此 Flutter 版本下对 `MediaQuery.sizeOf`
/// 不可靠）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/widgets/responsive_shell.dart';

/// 收集全部「实际缩放（x 轴 m00 < 1）」的 Transform —— 这只会来自
/// `ResponsiveShell` 的 `Transform.scale`（MaterialApp 内部的 Transform
/// 均为旋转/位移类，x 轴缩放恒为 1.0）。
///
/// ⚠️ 不能用 `getMaxScaleOnAxis`：`Matrix4` 的 z 轴恒为 1.0，
/// 对缩小矩阵它也会返回 1.0。
Iterable<double> scaledTransforms(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .map((Transform t) => t.transform.storage[0])
    .where((double s) => s < 1.0);

/// 设置逻辑窗口尺寸（dpr=1，便于按 900×640 设计稿比例断言）。
void setWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  test('设计稿尺寸常量 = 900×640', () {
    expect(ResponsiveShell.kDesignWidth, 900);
    expect(ResponsiveShell.kDesignHeight, 640);
  });

  testWidgets('大窗口（≥900×640）：居中限宽，不缩放', (WidgetTester tester) async {
    setWindow(tester, const Size(1200, 800));

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(
          child: SizedBox(width: 400, height: 300),
        ),
      ),
    );

    expect(scaledTransforms(tester), isEmpty, reason: '大窗口不缩放');
    // 限宽：ResponsiveShell 内部有 maxWidth = 640 的 ConstrainedBox。
    final ConstrainedBox box = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(ResponsiveShell),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.maxWidth, ResponsiveShell.kMaxContentWidth);
  });

  testWidgets('小窗口（<900×640）：等比缩放比例 = min(w/900, h/640)',
      (WidgetTester tester) async {
    setWindow(tester, const Size(450, 320));

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(
          child: SizedBox(width: 400, height: 300),
        ),
      ),
    );

    // 恰有一个缩放 Transform，比例 = min(450/900, 320/640) = 0.5。
    expect(scaledTransforms(tester), hasLength(1));
    expect(scaledTransforms(tester).single, closeTo(0.5, 0.001));
  });

  testWidgets('宽度受限时的等比缩放（900 边被拉满）', (WidgetTester tester) async {
    setWindow(tester, const Size(600, 1000));

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(child: Text('x')),
      ),
    );

    // min(600/900, 1000/640) = min(0.667, 1.5625) = 0.667。
    expect(scaledTransforms(tester).single, closeTo(600 / 900, 0.001));
  });

  testWidgets('自定义限宽生效', (WidgetTester tester) async {
    setWindow(tester, const Size(1400, 1000));

    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveShell(
          maxContentWidth: 480,
          child: SizedBox(width: 200, height: 100),
        ),
      ),
    );

    final ConstrainedBox box = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(ResponsiveShell),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.maxWidth, 480);
  });
}
