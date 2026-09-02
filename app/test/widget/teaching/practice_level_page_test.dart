/// T-EDU-03/04 · 引导实操页 widget 测试。
///
/// 覆盖：
/// - 页面装配（棋盘 + 输入层 + 三级提示面板）；
/// - 提示按钮逐级解锁（一级 → 二级 → 三级），次数不限；
/// - 误操作弹窗：填错触发「这一步有问题」（错在哪 + 正确思路 + 明白了）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_message_repository.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/practice_level/hint_panel.dart';
import 'package:sudoku_tutor/ui/features/practice_level/mistake_dialog.dart';
import 'package:sudoku_tutor/ui/features/practice_level/practice_level_page.dart';
import 'package:sudoku_tutor/ui/input/numpad_panel.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

const String kFakeMistakeJson = '''
{
  "schemaVersion": 1,
  "categories": [
    {"id": "wrongFill", "templates": [
      {"what": "你在 {cell} 填入了 {digit}，与终局解不符。", "how": "检查行、列、宫后重新判断。"}
    ]},
    {"id": "deletedTrueCandidate", "templates": [
      {"what": "你删掉了 {cell} 的真候选 {digit}。", "how": "用技巧确认后再删。"}
    ]},
    {"id": "prematureFill", "templates": {"byTechnique": {"default": [
      {"what": "{cell} 应经「{technique}」得出，现在填 {digit} 太早。", "how": "先找出技巧模式再填。"}
    ]}}}
  ]
}
''';

/// 假 scan：恒返回裸对删数型结果。
TechniqueResult _fakeScan(Board board,
        {RuleSet? ruleSet, String? solution81}) =>
    TechniqueResult(
      techniqueId: TechniqueId.nakedPair,
      eliminations: <Elimination>[Elimination(10, 5)],
      visual: VisualHint.assemble(
        patternCells: const <int>[11, 12],
        eliminated: const <MapEntry<int, int>>[MapEntry<int, int>(10, 5)],
        emphasized: const <MapEntry<int, int>>[MapEntry<int, int>(11, 5)],
      ),
    );

void main() {
  Future<ProviderContainer> pumpPracticePage(WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith(
          (Ref ref) async => FakeProgressRepository(),
        ),
        curriculumRepositoryProvider.overrideWithValue(
          CurriculumRepository(
            loader: buildTeachingCurriculumLoader(
              levelJsonById: buildDefaultTeachingLevels(),
            ),
          ),
        ),
        hintServiceProvider.overrideWithValue(
          HintService(
            scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
                _fakeScan(board, ruleSet: ruleSet, solution81: solution81),
          ),
        ),
        mistakeMessageRepositoryProvider.overrideWithValue(
          MistakeMessageRepository(
            loader: (String path) async => kFakeMistakeJson,
          ),
        ),
      ],
    );
    final GoRouter router = GoRouter(
      initialLocation: '/practice/ch0_l02',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('home-page')),
        ),
        GoRoute(
          path: '/practice/:levelId',
          name: 'practiceLevel',
          builder: (_, GoRouterState state) => PracticeLevelPage(
            levelId: state.pathParameters['levelId'] ?? '',
          ),
        ),
        GoRoute(
          path: '/trial/:levelId',
          name: 'trial',
          builder: (_, __) => const Scaffold(body: Text('trial-page')),
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
    // ⚠️ 与 free_play_page_test 同款收尾：手动停表（flutter_test 的
    // verifyInvariants 在 tearDown 前检查 pending timer），再销毁容器。
    addTearDown(() {
      container.read(gameSessionControllerProvider.notifier).timer.dispose();
      container.dispose();
    });
    for (int i = 0;
        i < 40 && find.byType(SudokuBoardView).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SudokuBoardView), findsOneWidget);
    for (int i = 0;
        i < 40 && find.byTooltip('下一关：试炼关').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    return container;
  }

  testWidgets('页面装配：棋盘 + 提示面板引导 + 输入层', (WidgetTester tester) async {
    await pumpPracticePage(tester);

    expect(find.byType(SudokuBoardView), findsOneWidget);
    expect(find.byType(HintPanel), findsOneWidget);
    expect(find.textContaining('提示将逐级解锁'), findsOneWidget);
    expect(find.byType(NumpadPanel), findsOneWidget);
    expect(find.byTooltip('提示（H）'), findsOneWidget);
    expect(find.byTooltip('下一关：试炼关'), findsOneWidget);
  });

  testWidgets('下一关：保存当前盘面后跨类型进入试炼关', (WidgetTester tester) async {
    final ProviderContainer container = await pumpPracticePage(tester);
    final controller = container.read(practiceControllerProvider.notifier);

    controller.handleSelectCell(5);
    controller.handleDigit(6);
    await tester.pump();

    await tester.tap(find.byTooltip('下一关：试炼关'));
    await tester.pumpAndSettle();

    final repository = await container.read(progressRepositoryProvider.future);
    final saved = await repository.loadTeachingSession('ch0_l02');
    expect(saved, isNotNull);
    expect(saved!.board81[5], '6');
    expect(find.text('trial-page'), findsOneWidget);
  });

  testWidgets('提示按钮逐级解锁：一级 → 二级 → 三级', (WidgetTester tester) async {
    await pumpPracticePage(tester);

    // 小窗口下实操页为滚动布局，提示按钮可能在视口外，先滚动到可见。
    await tester.ensureVisible(find.byTooltip('提示（H）'));
    await tester.pump();

    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('一级 · 裸对'), findsOneWidget);

    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('二级 · 裸对'), findsOneWidget);

    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('三级 · 裸对'), findsOneWidget);
  });

  testWidgets('实操提示后填数 → 自动清除棋盘高亮并保留提示卡', (WidgetTester tester) async {
    final ProviderContainer container = await pumpPracticePage(tester);
    await tester.ensureVisible(find.byTooltip('提示（H）'));
    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump(const Duration(milliseconds: 50));

    SudokuBoardView board = tester.widget<SudokuBoardView>(
      find.byType(SudokuBoardView),
    );
    expect(board.viewModel.hintCells, isNotEmpty);
    expect(find.textContaining('一级 · 裸对'), findsOneWidget);

    container.read(practiceControllerProvider.notifier).handleSelectCell(5);
    final NumpadPanel numpad = tester.widget<NumpadPanel>(
      find.byType(NumpadPanel),
    );
    numpad.callbacks.onDigit(6);
    await tester.pump();

    board = tester.widget<SudokuBoardView>(find.byType(SudokuBoardView));
    expect(board.viewModel.hintCells, isEmpty);
    expect(board.viewModel.hintRegions, isEmpty);
    expect(board.viewModel.hintLinks, isEmpty);
    expect(board.viewModel.hintCandidateMarks, isEmpty);
    expect(find.textContaining('一级 · 裸对'), findsOneWidget);
  });

  testWidgets('误操作填错 → 「这一步有问题」弹窗（错在哪 + 正确思路 + 明白了）',
      (WidgetTester tester) async {
    final ProviderContainer container = await pumpPracticePage(tester);

    // 选中 index10（终局解为 5）并填入 4。
    container.read(practiceControllerProvider.notifier).handleSelectCell(10);
    await tester.pump();
    // 滚动布局下数字键盘在视口下方，先滚动到可见再点击。
    await tester.ensureVisible(
      find.descendant(
        of: find.byType(NumpadPanel),
        matching: find.text('4'),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: find.byType(NumpadPanel),
        matching: find.text('4'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MistakeDialog), findsOneWidget);
    expect(find.text('这一步有问题'), findsOneWidget);
    expect(find.text('错在哪'), findsOneWidget);
    expect(find.text('正确思路'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '明白了'), findsOneWidget);

    await tester.tap(find.text('明白了'));
    await tester.pumpAndSettle();
    expect(find.byType(MistakeDialog), findsNothing, reason: '单按钮关闭弹窗');
    expect(
      container.read(gameSessionControllerProvider)!.errorCells,
      contains(10),
    );

    await tester.ensureVisible(find.byTooltip('撤销（Ctrl+Z）'));
    await tester.pump();
    await tester.tap(find.byTooltip('撤销（Ctrl+Z）'));
    await tester.pump();
    expect(
      container.read(gameSessionControllerProvider)!.board.isBlank(10),
      isTrue,
    );
    expect(
      container.read(gameSessionControllerProvider)!.errorCells,
      isEmpty,
      reason: '撤销错误填数后不应残留红框',
    );
    expect(
      container.read(gameSessionControllerProvider)!.redoMoves,
      hasLength(1),
      reason: '撤销后重做按钮应可用',
    );

    await tester.tap(find.byTooltip('重做（Ctrl+Y）'));
    await tester.pump();
    expect(
      container.read(gameSessionControllerProvider)!.board.valueAt(10),
      4,
    );
    expect(
      container.read(gameSessionControllerProvider)!.errorCells,
      contains(10),
      reason: '重做错误填数后应恢复错误标记',
    );
  });

  testWidgets('完成实操关并自动核验通过 → 播放通关动画', (WidgetTester tester) async {
    final ProviderContainer container = await pumpPracticePage(tester);
    final controller = container.read(practiceControllerProvider.notifier);

    controller.handleSelectCell(5);
    controller.handleDigit(6);
    controller.handleSelectCell(10);
    controller.handleDigit(5);
    for (int i = 0;
        i < 30 &&
            find
                .byKey(const ValueKey<String>('congratulations-animation'))
                .evaluate()
                .isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      find.byKey(const ValueKey<String>('congratulations-animation')),
      findsOneWidget,
    );
    expect(find.text('自动核验通过，本关盘面全部正确。'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('太棒了'));
    await tester.pumpAndSettle();
  });
}
