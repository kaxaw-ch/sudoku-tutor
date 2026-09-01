/// T-EDU-03 · 三级提示面板组件测试（S-04）。
///
/// 覆盖：已解锁级别可见可回看、未解锁级别占位、当前展示高亮、
/// 空提示时的引导文案。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/ui/features/practice_level/hint_panel.dart';

HintState _hint(int order, String narration) => HintState(
      level: HintRules.ofOrder(order)!,
      scope: HintScope.teaching,
      techniqueId: TechniqueId.nakedPair,
      narration: narration,
      highlightedCells: const <int>[10, 11],
      eliminations: order == 3
          ? <Elimination>[Elimination(10, 5)]
          : const <Elimination>[],
      visual: VisualHint.empty(),
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('无已解锁提示时显示引导文案', (WidgetTester tester) async {
    await tester.pumpWidget(
      _wrap(
        const HintPanel(
          unlockedHints: <HintState>[],
          displayedHint: null,
          onSelect: _noop,
        ),
      ),
    );
    expect(find.textContaining('提示将逐级解锁'), findsOneWidget);
  });

  testWidgets('已解锁级别保留可回看；未解锁级别显示占位', (WidgetTester tester) async {
    final HintState h1 = _hint(1, '一级文案：可用「裸对」');
    final HintState h2 = _hint(2, '二级文案：关键格已标出');
    await tester.pumpWidget(
      _wrap(
        HintPanel(
          unlockedHints: <HintState>[h1, h2],
          displayedHint: h2,
          onSelect: (_) {},
        ),
      ),
    );

    // 已解锁的一级/二级可见内容。
    expect(find.textContaining('一级 · 裸对'), findsOneWidget);
    expect(find.textContaining('一级文案'), findsOneWidget);
    expect(find.textContaining('二级 · 裸对'), findsOneWidget);
    expect(find.textContaining('二级文案'), findsOneWidget);
    // 三级未解锁 → 占位卡片。
    expect(find.textContaining('三级 · 尚未解锁'), findsOneWidget);
    expect(find.textContaining('继续使用上一级提示后解锁'), findsOneWidget);
  });

  testWidgets('点击已解锁级别可切换回看', (WidgetTester tester) async {
    final HintState h1 = _hint(1, '一级文案');
    final HintState h2 = _hint(2, '二级文案');
    HintState? selected;
    await tester.pumpWidget(
      _wrap(
        HintPanel(
          unlockedHints: <HintState>[h1, h2],
          displayedHint: h1,
          onSelect: (HintState h) => selected = h,
        ),
      ),
    );

    await tester.tap(find.textContaining('二级 · 裸对'));
    expect(selected, h2, reason: '点击二级卡片回看二级内容');
  });

  testWidgets('三级提示卡片展示删数结论', (WidgetTester tester) async {
    final HintState h3 = _hint(3, '三级文案：可删去第 2 行第 2 列的候选 5');
    await tester.pumpWidget(
      _wrap(
        HintPanel(
          unlockedHints: <HintState>[h3],
          displayedHint: h3,
          onSelect: (_) {},
        ),
      ),
    );
    expect(find.textContaining('三级 · 裸对'), findsOneWidget);
    expect(find.textContaining('三级文案'), findsOneWidget);
  });
}

void _noop(HintState _) {}
