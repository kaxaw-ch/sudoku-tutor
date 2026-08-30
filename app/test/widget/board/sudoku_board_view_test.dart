/// T-UI-02 · 棋盘容器 widget 测试（手势与渲染装配）。
///
/// 覆盖：点击/长按格子的坐标换算回调、选中态下同行列宫高亮装配、
/// 相同数字高亮两级装配、错误标红集合透传。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/session_rules.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';

import 'board_test_helper.dart';

void main() {
  /// 棋盘 400×400，padding 12 → 单格 41.78，原点 12。
  Offset cellCenter(int row, int col) {
    const double side = 400;
    const double padding = 12;
    final double cell = (side - padding * 2) / 9;
    final double origin = (side - cell * 9) / 2;
    return Offset(
        origin + col * cell + cell / 2, origin + row * cell + cell / 2);
  }

  Future<void> pumpBoard(
    WidgetTester tester, {
    required BoardViewModel viewModel,
    void Function(int)? onTap,
    void Function(int)? onLongPress,
  }) async {
    await tester.binding.setSurfaceSize(const Size(420, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 400,
            child: SudokuBoardView(
              viewModel: viewModel,
              onCellTap: onTap,
              onCellLongPress: onLongPress,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('点击格子 → onCellTap 回调正确索引', (WidgetTester tester) async {
    int? tapped;
    await pumpBoard(
      tester,
      viewModel: buildViewModel(),
      onTap: (int i) => tapped = i,
    );
    await tester.tapAt(cellCenter(0, 0));
    await tester.pump();
    expect(tapped, 0);

    await tester.tapAt(cellCenter(4, 5));
    await tester.pump();
    expect(tapped, 4 * 9 + 5);
  });

  testWidgets('点击棋盘外 → 无回调', (WidgetTester tester) async {
    int? tapped;
    await pumpBoard(
      tester,
      viewModel: buildViewModel(),
      onTap: (int i) => tapped = i,
    );
    await tester.tapAt(const Offset(5, 5)); // 内边距区域。
    await tester.pump();
    expect(tapped, isNull);
  });

  testWidgets('长按格子 → onCellLongPress 回调', (WidgetTester tester) async {
    int? longPressed;
    await pumpBoard(
      tester,
      viewModel: buildViewModel(),
      onLongPress: (int i) => longPressed = i,
    );
    await tester.longPressAt(cellCenter(2, 3));
    await tester.pump();
    expect(longPressed, 2 * 9 + 3);
  });

  test('渲染数据装配：选中格同行列宫高亮 + 相同数字两级', () {
    final GameSession session = buildSession(selectedIndex: 0);
    final BoardViewModel vm = BoardViewModel.fromSession(session);
    // 选中格 0（行 0 列 0）→ peer 高亮含 (0,1)（同行）与 (1,0)（同列）。
    expect(vm.peerHighlight, contains(1));
    expect(vm.peerHighlight, contains(9));
    expect(vm.peerHighlight, isNot(contains(0)), reason: '选中格本身从 peer 排除');
    // 选中格的值 = 5（给定格 0 的值）。
    expect(vm.selectedValue, 5);
    // 相同数字高亮：格 0 已填 5 → 强高亮。
    expect(
      vm.sameDigitHighlights[0],
      SameDigitHighlight.strongFilled,
    );
    // 错误集透传。
    final BoardViewModel vmError = buildViewModel(errorCells: const <int>{3});
    expect(vmError.errorCells, contains(3));
  });
}
