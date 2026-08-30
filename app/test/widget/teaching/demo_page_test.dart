/// T-EDU-02 · 原理演示页 widget 测试。
///
/// 覆盖：
/// - 只读盘面（SudokuBoardView 渲染，点击无输入响应）；
/// - 默认手动「下一步」，进度 `1/2` → `2/2`，看完最后一步写档；
/// - 自动播放（2s/步）可暂停推进；
/// - 首次未看完拦截返回（SnackBar）；看完后可返回；
/// - 旁白卡片 + 步骤控制条渲染。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/demo/demo_page.dart';
import 'package:sudoku_tutor/ui/features/demo/narration_card.dart';
import 'package:sudoku_tutor/ui/features/demo/step_control_bar.dart';
import 'package:sudoku_tutor/ui/features/demo/technique_progress_bar.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

void main() {
  Future<ProviderContainer> pumpDemoPage(
    WidgetTester tester, {
    FakeProgressRepository? repo,
  }) async {
    final FakeProgressRepository progress = repo ?? FakeProgressRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith((Ref ref) async => progress),
        curriculumRepositoryProvider.overrideWithValue(
          CurriculumRepository(
            loader: buildTeachingCurriculumLoader(
              levelJsonById: buildDefaultTeachingLevels(),
            ),
          ),
        ),
      ],
    );
    final GoRouter router = GoRouter(
      initialLocation: '/demo/ch0_l01',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('home-page')),
        ),
        GoRoute(
          path: '/demo/:levelId',
          name: 'demo',
          builder: (_, __) => const DemoPage(),
        ),
        GoRoute(
          path: '/practice/:levelId',
          name: 'practiceLevel',
          builder: (_, __) => const Scaffold(body: Text('practice-page')),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    addTearDown(container.dispose);
    // 等待异步加载关卡。
    for (int i = 0;
        i < 40 && find.byType(SudokuBoardView).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SudokuBoardView), findsOneWidget, reason: '加载后棋盘应渲染');
    for (int i = 0;
        i < 40 && find.byTooltip('下一关：实操关').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return container;
  }

  testWidgets('加载后：只读棋盘 + 技巧进度条 + 旁白卡片 + 控制条', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    expect(find.byType(SudokuBoardView), findsOneWidget);
    expect(find.byType(DemoTechniqueProgressBar), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('demo-step-progress')),
        findsOneWidget);
    expect(find.text('技巧进度'), findsOneWidget);
    expect(find.text('点击技巧节点快速跳转'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('demo-technique-nakedSingle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('demo-technique-hiddenSingle')),
      findsOneWidget,
    );
    expect(find.byType(NarrationCard), findsOneWidget);
    expect(find.byType(StepControlBar), findsOneWidget);
    expect(find.textContaining('1/2'), findsOneWidget);
    expect(find.textContaining('测试旁白（第 1 步）'), findsOneWidget);
    expect(find.byTooltip('上一步'), findsOneWidget);
    expect(find.byTooltip('下一步'), findsOneWidget);
    expect(find.byTooltip('自动播放'), findsOneWidget);
    expect(find.byTooltip('重播'), findsOneWidget);
    expect(find.byTooltip('下一关：实操关'), findsOneWidget);
  });

  testWidgets('点击技巧进度节点 → 快速跳到该技巧首次出现的步骤', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('demo-technique-hiddenSingle')),
    );
    await tester.pump();

    expect(find.textContaining('2/2'), findsOneWidget);
    expect(find.textContaining('测试旁白（第 2 步）'), findsOneWidget);
    expect(find.text('隐性唯一数'), findsWidgets);
  });

  testWidgets('下一关：首次未看完拦截，看完后跨类型进入实操关', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    await tester.tap(find.byTooltip('下一关：实操关'));
    await tester.pump();
    expect(find.textContaining('看完最后一步即可进入下一关'), findsOneWidget);
    expect(find.text('practice-page'), findsNothing);

    await tester.tap(find.byTooltip('下一步'));
    await tester.pump();
    await tester.tap(find.byTooltip('下一关：实操关'));
    await tester.pumpAndSettle();
    expect(find.text('practice-page'), findsOneWidget);
  });

  testWidgets('只读：点击棋盘格子无输入响应（无选中高亮、无值变化）', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    final SudokuBoardView board =
        tester.widget<SudokuBoardView>(find.byType(SudokuBoardView));
    final List<int> before = board.viewModel.values;
    // 点击棋盘中心区域。
    await tester.tap(
      find.byType(SudokuBoardView),
      warnIfMissed: false,
    );
    await tester.pump();
    final SudokuBoardView after =
        tester.widget<SudokuBoardView>(find.byType(SudokuBoardView));
    expect(after.viewModel.values, before, reason: '盘面值不应变化');
    expect(after.viewModel.selectedIndex, isNull, reason: '只读：点击不产生选中');
  });

  testWidgets('手动下一步到结尾 → 进度 2/2 并写档（hintUsed=0、errorCount=0）',
      (WidgetTester tester) async {
    final repo = FakeProgressRepository();
    await pumpDemoPage(tester, repo: repo);

    await tester.tap(find.byTooltip('下一步'));
    await tester.pump();
    expect(find.textContaining('2/2'), findsOneWidget);

    // 看完最后一步 → 已真实写档。
    final LevelProgress progress = repo.current.levels['ch0_l01']!;
    expect(progress.status, LevelStatus.completed);
    expect(progress.hintUsed, 0);
    expect(progress.errorCount, 0);
    // 到结尾后「下一步」禁用。
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip('下一步'),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('自动播放 2s/步：启动后推进到结尾', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    await tester.tap(find.byTooltip('自动播放'));
    await tester.pump();
    expect(find.byTooltip('暂停自动播放'), findsOneWidget, reason: '自动播放已启动');

    // 推进 2s：第一步 → 第二步（结尾），自动停止。
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.textContaining('2/2'), findsOneWidget);
    expect(find.byTooltip('自动播放'), findsOneWidget, reason: '到结尾自动停止');
  });

  testWidgets('首次未看完拦截返回；看完后可返回（跳过）', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    // 未看完：点返回 → 拦截提示，不跳转。
    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget, reason: '首次须完整看完');
    expect(find.text('home-page'), findsNothing);

    // 看完最后一步后再返回 → 放行跳转 home。
    await tester.tap(find.byTooltip('下一步'));
    await tester.pump();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('重播：回到第 1 步并清除完成标记', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    await tester.tap(find.byTooltip('下一步'));
    await tester.pump();
    expect(find.textContaining('2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('重播'));
    await tester.pump();
    expect(find.textContaining('1/2'), findsOneWidget);
  });
}
