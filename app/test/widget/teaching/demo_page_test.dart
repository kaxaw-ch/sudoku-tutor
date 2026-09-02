/// T-EDU-02 · 原理演示页 widget 测试。
///
/// 覆盖：
/// - 只读盘面（SudokuBoardView 渲染，点击无输入响应）；
/// - 默认手动「下一步」，进度 `1/2` → `2/2`，看完最后一步写档；
/// - 自动播放（2s/步）可暂停推进；
/// - 进度条可完整拖动并跳到任意步骤；
/// - 无须看完即可返回或进入下一关；
/// - 宽屏双栏与窄屏单栏均无布局溢出。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
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
          builder: (_, GoRouterState state) => DemoPage(
            levelId: state.pathParameters['levelId'] ?? '',
          ),
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
    expect(
        find.byKey(const ValueKey<String>('demo-step-slider')), findsOneWidget);
    expect(find.text('技巧进度'), findsOneWidget);
    expect(find.text('拖动或点击进度条可跳到任意步骤'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('demo-technique-nakedSingle')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('demo-technique-hiddenSingle')),
      findsNothing,
      reason: '关键点区域只展示本关主技巧，不展示辅助技巧',
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
    expect(
        find.byKey(const ValueKey<String>('demo-wide-layout')), findsOneWidget);
  });

  testWidgets('只有一个主技巧关键点：到达后停止且不跳到辅助技巧', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    final Finder keyPoint =
        find.byKey(const ValueKey<String>('demo-technique-nakedSingle'));
    expect(find.byTooltip('已到本关技巧最后一个关键点'), findsOneWidget);
    expect(
      tester.widget<ActionChip>(keyPoint).onPressed,
      isNull,
      reason: '本关主技巧没有下一个位置时应停止，不得跳到隐性唯一数',
    );
    expect(find.textContaining('1/2'), findsOneWidget);
  });

  testWidgets('拖动整条进度滑杆 → 可直接跳到目标步骤', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    final Finder slider =
        find.byKey(const ValueKey<String>('demo-step-slider'));
    final Rect rect = tester.getRect(slider);
    await tester.dragFrom(
      Offset(rect.left + 24, rect.center.dy),
      Offset(rect.width - 48, 0),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2/2'), findsOneWidget);
    expect(find.textContaining('测试旁白（第 2 步）'), findsOneWidget);
  });

  testWidgets('下一关：无需看完即可跨类型进入实操关', (WidgetTester tester) async {
    await pumpDemoPage(tester);

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

  testWidgets('无需看完即可直接返回学习地图', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('home-page'), findsOneWidget);
  });

  testWidgets('重播：回到第 1 步且不重复结算', (WidgetTester tester) async {
    await pumpDemoPage(tester);

    await tester.tap(find.byTooltip('下一步'));
    await tester.pump();
    expect(find.textContaining('2/2'), findsOneWidget);

    await tester.tap(find.byTooltip('重播'));
    await tester.pump();
    expect(find.textContaining('1/2'), findsOneWidget);
  });

  testWidgets('360×640 窄屏：切换为可滚动单栏且不产生布局异常', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpDemoPage(tester);

    expect(find.byKey(const ValueKey<String>('demo-compact-layout')),
        findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('只显示本关主技巧，连续点击遍历该技巧的全部关键点', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    int currentIndex = 0;
    final List<int> selectedIndices = <int>[];
    final List<ScriptStep> steps = <ScriptStep>[
      ScriptStep(order: 1, techniqueId: TechniqueId.nakedSingle),
      ScriptStep(order: 2, techniqueId: TechniqueId.hiddenSingle),
      ScriptStep(order: 3, techniqueId: TechniqueId.nakedSingle),
      ScriptStep(order: 4, techniqueId: TechniqueId.hiddenSingle),
      ScriptStep(order: 5, techniqueId: TechniqueId.nakedSingle),
    ];

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 360,
                  child: DemoTechniqueProgressBar(
                    steps: steps,
                    currentIndex: currentIndex,
                    targetTechniques: const <TechniqueId>{
                      TechniqueId.nakedSingle,
                      TechniqueId.hiddenSingle,
                    },
                    onStepSelected: (int stepIndex) async {
                      selectedIndices.add(stepIndex);
                      setState(() => currentIndex = stepIndex);
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    await tester.pump();

    final Finder keyPoint =
        find.byKey(const ValueKey<String>('demo-current-technique-key-point'));
    final Finder nakedSingle =
        find.byKey(const ValueKey<String>('demo-technique-nakedSingle'));
    final Finder hiddenSingle =
        find.byKey(const ValueKey<String>('demo-technique-hiddenSingle'));

    expect(keyPoint, findsOneWidget);
    expect(hiddenSingle, findsOneWidget);
    expect(nakedSingle, findsNothing);
    expect(find.byTooltip('跳到本关技巧第一个关键点'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('demo-progress-marker-hiddenSingle-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('demo-progress-marker-hiddenSingle-3'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('demo-progress-marker-nakedSingle-0'),
      ),
      findsNothing,
      reason: '进度条不得标出前置技巧关键点',
    );
    expect(
      find.descendant(of: keyPoint, matching: find.byType(CircleAvatar)),
      findsNothing,
      reason: '技巧按钮前不再显示关键点所在步数',
    );

    // 第一次点击进入本关主技巧第一次出现的位置。
    await tester.tap(hiddenSingle);
    await tester.pump();
    expect(selectedIndices, <int>[1]);
    expect(
      tester
          .widget<Slider>(
            find.byKey(const ValueKey<String>('demo-step-slider')),
          )
          .value,
      1,
    );
    expect(find.byTooltip('跳到本关技巧下一个关键点'), findsOneWidget);

    // 再次点击进入同一技巧的下一个出现位置。
    await tester.tap(hiddenSingle);
    await tester.pump();
    expect(selectedIndices, <int>[1, 3]);
    expect(hiddenSingle, findsOneWidget);
    expect(nakedSingle, findsNothing);
    expect(find.byTooltip('已到本关技巧最后一个关键点'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('demo-progress-marker-hiddenSingle-3'),
      ),
      findsNothing,
      reason: '当前关键点由滑块表示，不应再叠加一个圆点',
    );
    expect(tester.takeException(), isNull);
  });
}
