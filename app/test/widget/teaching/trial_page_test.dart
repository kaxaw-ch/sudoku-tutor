/// T-EDU-05 · 验收试炼页 widget 测试。
///
/// 覆盖：
/// - 提示按钮置灰（onPressed=null）+「试炼关不提供提示」说明；
/// - 顶部标明「本关需用到：XX 技巧」；
/// - 连续失败 3 次 → 回看原理演示弹窗（继续挑战可关闭）；
/// - 通关 → 结算卡（用时/错误次数/返回章节）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_bank_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/domain/teaching/trial_controller.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/demo/demo_page.dart';
import 'package:sudoku_tutor/ui/features/trial/result_sheet.dart';
import 'package:sudoku_tutor/ui/features/trial/trial_page.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

/// 试炼池（2 空格题，标注目标技巧 hiddenSingle）。
TrialPool _pool() => TrialPool(
      chapter: 0,
      targetTechniques: const <TechniqueId>{TechniqueId.hiddenSingle},
      puzzles: <Puzzle>[
        Puzzle(
          given: <int>[
            for (final String ch in kTeachingPuzzle81.split(''))
              ch == '.' ? 0 : int.parse(ch),
          ],
          solution: <int>[
            for (final String ch in kTeachingSolution81.split(''))
              int.parse(ch),
          ],
          techniques: const <TechniqueId>{TechniqueId.hiddenSingle},
        ),
      ],
    );

void main() {
  Future<ProviderContainer> pumpTrialPage(WidgetTester tester) async {
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
        puzzleBankRepositoryProvider.overrideWithValue(
          FakePuzzleBankRepository(pool: _pool()),
        ),
      ],
    );
    final GoRouter router = GoRouter(
      initialLocation: '/trial/ch0_l03',
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
          path: '/trial/:levelId',
          name: 'trial',
          builder: (_, GoRouterState state) => TrialPage(
            levelId: state.pathParameters['levelId'] ?? '',
          ),
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
    return container;
  }

  testWidgets('提示按钮置灰 + 说明 + 顶部目标技巧', (WidgetTester tester) async {
    await pumpTrialPage(tester);

    expect(find.textContaining('本关需用到：隐性唯一数'), findsOneWidget);
    expect(find.textContaining('试炼关不提供提示'), findsOneWidget);
    expect(find.byTooltip('已经是最后一关'), findsOneWidget);
    // 提示按钮（tooltip 仍是「提示（H）」）已置灰。
    final IconButton hintButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('提示（H）'),
        matching: find.byType(IconButton),
      ),
    );
    expect(hintButton.onPressed, isNull, reason: '试炼关提示按钮置灰');
  });

  testWidgets('连续失败 3 次 → 回看原理演示弹窗；继续挑战可关闭', (WidgetTester tester) async {
    final ProviderContainer container = await pumpTrialPage(tester);
    final TrialController ctrl =
        container.read(trialControllerProvider.notifier);

    ctrl.handleSelectCell(10);
    ctrl.handleDigit(4);
    ctrl.handleSelectCell(5);
    ctrl.handleDigit(7);
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('连续失败 3 次'), findsOneWidget);
    expect(find.text('回看原理演示'), findsOneWidget);
    expect(find.text('继续挑战'), findsOneWidget);

    await tester.tap(find.text('继续挑战'));
    await tester.pumpAndSettle();
    expect(find.textContaining('连续失败 3 次'), findsNothing);
  });

  testWidgets('通关 → 结算卡（用时/错误次数/返回章节）', (WidgetTester tester) async {
    final ProviderContainer container = await pumpTrialPage(tester);
    final TrialController ctrl =
        container.read(trialControllerProvider.notifier);

    // 普通填数解满整盘（其余为给定格）。
    ctrl.handleSelectCell(5);
    ctrl.handleDigit(6);
    ctrl.handleSelectCell(10);
    ctrl.handleDigit(5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TrialResultSheet), findsOneWidget);
    expect(find.text('挑战通过！'), findsOneWidget);
    expect(find.text('错误次数'), findsOneWidget);
    expect(find.text('返回章节'), findsOneWidget);

    // 关闭结算卡后返回章节。
    await tester.tap(find.text('返回章节'));
    await tester.pumpAndSettle();
    expect(find.text('home-page'), findsOneWidget);
  });
}
