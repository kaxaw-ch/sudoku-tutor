/// T-UI-07 · 教学图层「坐标零推断」断言（P0-EDU-03 / P0-UI-03）。
///
/// 验收铁律：**painter 只消费 `VisualHint`，不自行算候选、不读盘面**。
/// 本测试从三个层面断言：
/// 1. **类型层**：`TeachingOverlayPainter` 构造只接收
///    `geometry + visual + progress`，不接收任何盘面数据（Board/BoardViewModel/
///    candidateMasks）——若未来有人把盘面传入 painter，本测试编译即失败；
/// 2. **行为层**：渲染到真实画布不抛异常；区域矩形坐标由 `cornerCells`
///    经几何换算得出，与「手算网格位置」一致；
/// 3. **数据流层**：`BoardViewModel.fromSession(teachingOverlay:)` 原样透传
///    VisualHint，SudokuBoardView 把该数据直接交给 overlay painter，
///    UI 层无任何候选/盘面计算。
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/ui/board/board_geometry.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/board/teaching_overlay_painter.dart';

import '../board/board_test_helper.dart';

void main() {
  // ------------------------------------------------------------ 类型层

  test('painter 构造签名不含任何盘面数据（UI 零推断）', () {
    final BoardGeometry geometry = BoardGeometry(
      size: const Size(360, 360),
      padding: 12,
    );
    // 仅传 geometry + visual + progress；若需传入 board/candidates，
    // 此构造调用将无法编译——从类型上杜绝「读盘面」。
    final TeachingOverlayPainter painter = TeachingOverlayPainter(
      geometry: geometry,
      visual: VisualHint.empty(),
      progress: TeachingOverlayProgress.steady,
    );
    expect(painter, isNotNull);
  });

  // ------------------------------------------------------------ 行为层

  test('区域矩形坐标由 cornerCells 推导，与手算网格位置一致', () {
    final BoardGeometry geometry = BoardGeometry(
      size: const Size(360, 360),
      padding: 12,
    );
    final TeachingOverlayPainter painter = TeachingOverlayPainter(
      geometry: geometry,
      visual: VisualHint.empty(),
    );

    // X 翼四角：r2c2(10)、r2c8(16)、r7c2(64)、r7c8(70)——0 基 row/col：
    // 10=r1c1、16=r1c7、64=r7c1、70=r7c7，包围矩形 = r1c1..r7c7。
    final Rect rect = painter.regionRectFor(const <int>[10, 16, 64, 70]);
    final Rect expectedTopLeft = geometry.cellRect(1, 1);
    final Rect expectedBottomRight = geometry.cellRect(7, 7);
    expect(rect.left, closeTo(expectedTopLeft.left, 0.001));
    expect(rect.top, closeTo(expectedTopLeft.top, 0.001));
    expect(rect.right, closeTo(expectedBottomRight.right, 0.001));
    expect(rect.bottom, closeTo(expectedBottomRight.bottom, 0.001));
  });

  test('渲染到真实画布不抛异常（覆盖 cells/regions/links/candidateMarks）', () {
    final BoardGeometry geometry = BoardGeometry(
      size: const Size(360, 360),
      padding: 12,
    );
    final VisualHint hint = VisualHint.assemble(
      patternCells: const <int>[10, 16, 64, 70],
      pivotCells: const <int>[29],
      pincerCells: const <int>[28, 30],
      chainStrongCells: const <int>[37, 43],
      eliminated: const <MapEntry<int, int>>[
        MapEntry<int, int>(5, 6),
      ],
      emphasized: const <MapEntry<int, int>>[
        MapEntry<int, int>(11, 5),
      ],
      regions: <RegionMark>[
        RegionMark(
          cornerCells: const <int>[10, 16, 64, 70],
          role: MarkRole.pattern,
          dashed: true,
          animated: true,
        ),
      ],
      links: <LinkMark>[
        LinkMark(fromCell: 29, toCell: 28, digit: 3, strong: true),
        LinkMark(fromCell: 37, toCell: 43, digit: 5, strong: false),
      ],
    );
    final TeachingOverlayPainter painter = TeachingOverlayPainter(
      geometry: geometry,
      visual: hint,
      progress: TeachingOverlayProgress.steady,
    );

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    painter.paint(canvas, const Size(360, 360));
    recorder.endRecording();
    // 上述执行未抛异常即通过；动画进度 0 时也应安全。
    final TeachingOverlayPainter atZero = TeachingOverlayPainter(
      geometry: geometry,
      visual: hint,
      progress: const TeachingOverlayProgress(
        highlightOpacity: 0,
        linkGrow: 0,
        strike: 0,
      ),
    );
    final ui.PictureRecorder recorder2 = ui.PictureRecorder();
    atZero.paint(Canvas(recorder2), const Size(360, 360));
    recorder2.endRecording();
  });

  // ------------------------------------------------------------ 数据流层

  test('BoardViewModel 原样透传 teachingOverlay（不加工不推断）', () {
    final VisualHint hint = VisualHint.assemble(
      patternCells: const <int>[10, 16],
    );
    final BoardViewModel viewModel = BoardViewModel.fromSession(
      buildSession(),
      teachingOverlay: hint,
    );
    expect(identical(viewModel.teachingOverlay, hint), isTrue,
        reason: '透传同一实例，UI 不做任何数据加工');
  });

  testWidgets('SudokuBoardView 渲染教学图层不崩溃（叠加层生效）', (WidgetTester tester) async {
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
          animated: true,
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(460, 460));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Center(
          child: SizedBox(
            width: 440,
            height: 440,
            child: SudokuBoardView(
              viewModel: BoardViewModel.fromSession(
                buildSession(),
                teachingOverlay: hint,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(SudokuBoardView), findsOneWidget);
  });
}
