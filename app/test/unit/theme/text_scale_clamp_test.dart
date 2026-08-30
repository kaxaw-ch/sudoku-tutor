/// T-UI-01 · 系统字号钳制测试（P0-UI-07：0.85–1.3）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/ui/theme/text_scale_clamp.dart';

void main() {
  test('钳制区间常量为 0.85–1.3', () {
    expect(TextScaleClamp.minScale, 0.85);
    expect(TextScaleClamp.maxScale, 1.3);
  });

  test('超大系统字号（3.0）被钳制到 1.3', () {
    final TextScaler clamped = TextScaler.linear(3.0).clamp(
      minScaleFactor: TextScaleClamp.minScale,
      maxScaleFactor: TextScaleClamp.maxScale,
    );
    expect(clamped.scale(10), closeTo(13.0, 0.001));
  });

  test('超小系统字号（0.4）被钳制到 0.85', () {
    final TextScaler clamped = TextScaler.linear(0.4).clamp(
      minScaleFactor: TextScaleClamp.minScale,
      maxScaleFactor: TextScaleClamp.maxScale,
    );
    expect(clamped.scale(20), closeTo(17.0, 0.001));
  });

  testWidgets('wrap 把 3.0 的系统字号降到 1.3 生效', (WidgetTester tester) async {
    double? scaledSize;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(3.0)),
        child: Builder(
          builder: (BuildContext inner) => TextScaleClamp.wrap(
            inner,
            Builder(
              builder: (BuildContext deepest) {
                scaledSize = MediaQuery.textScalerOf(deepest).scale(14);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    // 14 × 1.3 = 18.2。
    expect(scaledSize, closeTo(18.2, 0.01));
  });

  testWidgets('wrap 把 0.5 的系统字号抬到 0.85 生效', (WidgetTester tester) async {
    double? scaledSize;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
        child: Builder(
          builder: (BuildContext inner) => TextScaleClamp.wrap(
            inner,
            Builder(
              builder: (BuildContext deepest) {
                scaledSize = MediaQuery.textScalerOf(deepest).scale(16);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    // 16 × 0.85 = 13.6。
    expect(scaledSize, closeTo(13.6, 0.01));
  });

  testWidgets('正常字号（1.0）不受钳制影响', (WidgetTester tester) async {
    double? scaledSize;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Builder(
          builder: (BuildContext inner) => TextScaleClamp.wrap(
            inner,
            Builder(
              builder: (BuildContext deepest) {
                scaledSize = MediaQuery.textScalerOf(deepest).scale(14);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    expect(scaledSize, closeTo(14.0, 0.01));
  });
}
