/// T-UI-02 · 棋盘 golden 测试（P0-UI-02）。
///
/// 覆盖两套棋盘主题及三种代表性渲染状态：
/// - 基础盘面（给定格 + 玩家已填 + 候选数 3×3 微排布）；
/// - 选中 + 同行列宫弱高亮 + 相同数字强高亮 + 错误标红（只描边不填底）；
/// - 手动笔记模式候选渲染 + 提示 MarkRole 高亮。
///
/// ⚠️ 生成方式：`flutter test --update-goldens test/golden/board_golden_test.dart`
/// 首先生成基准图，之后以 `matchesGoldenFile` 断言回归。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';

import '../widget/board/board_test_helper.dart';

void main() {
  Future<void> pumpBoard(
    WidgetTester tester,
    BoardViewModel viewModel, {
    BoardThemeStyle boardTheme = BoardThemeStyle.green,
  }) async {
    await tester.binding.setSurfaceSize(const Size(440, 440));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          extensions: <ThemeExtension<dynamic>>[
            GamePalette.boardOf(boardTheme),
          ],
        ),
        home: Center(
          child: SizedBox(
            width: 420,
            height: 420,
            child: SudokuBoardView(viewModel: viewModel),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('棋盘 golden：基础盘面（给定 + 玩家 + 候选）', (WidgetTester tester) async {
    await pumpBoard(tester, buildViewModel());
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/board_basic.png'),
    );
  });

  testWidgets('棋盘 golden：经典蓝色基础盘面', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      buildViewModel(),
      boardTheme: BoardThemeStyle.blue,
    );
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/board_blue_basic.png'),
    );
  });

  testWidgets('棋盘 golden：经典蓝色选中与关联层级', (WidgetTester tester) async {
    await pumpBoard(
      tester,
      buildViewModel(
        selectedIndex: 0,
        errorCells: const <int>{3},
        highlightSameDigit: true,
      ),
      boardTheme: BoardThemeStyle.blue,
    );
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/board_blue_selected_error.png'),
    );
  });

  testWidgets('棋盘 golden：选中 + 弱高亮 + 相同数字强高亮 + 错误描边',
      (WidgetTester tester) async {
    // 选中格 0（值 5）→ 同行列宫高亮 + 相同数字 5 强高亮；错误格 3 描边。
    await pumpBoard(
      tester,
      buildViewModel(
        selectedIndex: 0,
        errorCells: const <int>{3},
        highlightSameDigit: true,
      ),
    );
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/board_selected_error.png'),
    );
  });

  testWidgets('棋盘 golden：手动笔记模式候选 + 提示 MarkRole 高亮',
      (WidgetTester tester) async {
    final VisualHint hint = VisualHint.assemble(
      patternCells: const <int>[10, 11, 19, 20],
      pivotCells: const <int>[29],
      pincerCells: const <int>[28, 30],
      eliminated: const <MapEntry<int, int>>[
        MapEntry<int, int>(5, 6),
      ],
    );
    await pumpBoard(
      tester,
      buildViewModel(noteMode: true, hintVisual: hint),
    );
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/board_note_hint.png'),
    );
  });
}
