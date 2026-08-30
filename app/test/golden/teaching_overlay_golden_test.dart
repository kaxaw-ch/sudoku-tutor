/// T-UI-07 · 教学图层 golden 测试（P0-EDU-03 / P0-UI-03/09）。
///
/// 覆盖四类形态（架构 §6.2 十六技巧的典型可视化）：
/// - Fish（X 翼）：pattern 四角 + 虚线矩形 + 删数划除；
/// - Wing（XY 翼）：pivot + pincer + 连线生长 + 删数划除；
/// - UR（唯一矩形）：pattern 四格 + 区域 + 删数划除；
/// - 涂色（简单涂色）：chainStrong / chainWeak 端点 + 连线。
///
/// ⚠️ 生成方式：主理人跑 `flutter test --update-goldens test/golden/teaching_overlay_golden_test.dart`
/// 生成基准图；之后以 `matchesGoldenFile` 断言回归。
///
/// 渲染口径：真实走 `SudokuBoardView`（底层棋盘 + 上层教学图层叠加），
/// 教学图层动画进度取 **steady（完成态）**，保证 golden 确定性。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';

import '../widget/board/board_test_helper.dart';

void main() {
  Future<void> pumpBoard(
    WidgetTester tester,
    VisualHint overlay,
  ) async {
    await tester.binding.setSurfaceSize(const Size(460, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
        home: Center(
          child: SizedBox(
            width: 440,
            height: 440,
            child: SudokuBoardView(
              viewModel: BoardViewModel.fromSession(
                buildSession(),
                teachingOverlay: overlay,
              ),
            ),
          ),
        ),
      ),
    );
    // 教学图层动画播放一帧并到达完成态（稳态渲染）。
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('教学图层 golden：Fish（X 翼）', (WidgetTester tester) async {
    // X 翼：r2c2/r2c8/r7c2/r7c8 为 pattern 角点，虚线矩形，删 r8c3 的 5。
    final VisualHint hint = VisualHint.assemble(
      patternCells: const <int>[10, 16, 64, 70],
      eliminated: const <MapEntry<int, int>>[
        MapEntry<int, int>(65, 5),
      ],
      regions: <RegionMark>[
        RegionMark(
          cornerCells: const <int>[10, 16, 64, 70],
          role: MarkRole.pattern,
          dashed: true,
        ),
      ],
    );
    await pumpBoard(tester, hint);
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/teaching_overlay_fish.png'),
    );
  });

  testWidgets('教学图层 golden：Wing（XY 翼）', (WidgetTester tester) async {
    // XY 翼：pivot r2c2，pincer r2c6 / r6c2，删 r2c1 的候选。
    final VisualHint hint = VisualHint.assemble(
      pivotCells: const <int>[10],
      pincerCells: const <int>[14, 46],
      eliminated: const <MapEntry<int, int>>[
        MapEntry<int, int>(9, 3),
      ],
      links: <LinkMark>[
        LinkMark(fromCell: 10, toCell: 14, digit: 5, strong: true),
        LinkMark(fromCell: 10, toCell: 46, digit: 5, strong: true),
      ],
    );
    await pumpBoard(tester, hint);
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/teaching_overlay_wing.png'),
    );
  });

  testWidgets('教学图层 golden：UR（唯一矩形）', (WidgetTester tester) async {
    // UR：r2c2/r2c5/r5c2/r5c5 四格 pattern + 区域 + 删 r5c5 的 7。
    // ⚠️ region 的 animated 置 false：golden 需确定性（流动虚线动效由
    // 零推断 widget 测试覆盖，不在此处抓帧）。
    final VisualHint hint = VisualHint.assemble(
      patternCells: const <int>[10, 13, 37, 40],
      eliminated: const <MapEntry<int, int>>[
        MapEntry<int, int>(40, 7),
      ],
      regions: <RegionMark>[
        RegionMark(
          cornerCells: const <int>[10, 13, 37, 40],
          role: MarkRole.pattern,
          dashed: true,
          animated: false,
        ),
      ],
    );
    await pumpBoard(tester, hint);
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/teaching_overlay_ur.png'),
    );
  });

  testWidgets('教学图层 golden：涂色（简单涂色）', (WidgetTester tester) async {
    // 涂色：强链端点（绿）r2c2-r2c8，弱链端点（灰绿）r5c2-r5c8。
    final VisualHint hint = VisualHint.assemble(
      chainStrongCells: const <int>[10, 16],
      chainWeakCells: const <int>[37, 43],
      links: <LinkMark>[
        LinkMark(fromCell: 10, toCell: 16, digit: 5, strong: true),
        LinkMark(fromCell: 37, toCell: 43, digit: 5, strong: false),
      ],
    );
    await pumpBoard(tester, hint);
    await expectLater(
      find.byType(SudokuBoardView),
      matchesGoldenFile('goldens/teaching_overlay_colouring.png'),
    );
  });
}
