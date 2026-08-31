/// T-UI-04 · 自由练习页测试（S-06，P0-PRA-*）。
///
/// 覆盖：
/// - 棋盘渲染（`SudokuBoardView`）与顶部标题「自由练习 · 难度」；
/// - 功能条存在（ActionBar 撤销/重做/擦除/笔记/提示/核对），不重复暂停；
/// - 移动端数字键盘（NumpadPanel）渲染，tap 数字键真正填数进对局；
/// - 手动暂停 → `PauseOverlay` 遮挡盘面 + 单击空白恢复；
/// - 提示按钮 → 提示卡片出现（注入假 scan，规避真实 Isolate）；
/// - 无断点时对局页不出现 ResumeBanner。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/duel/async_duel_codec.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/game_session_controller.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/free_play/free_play_page.dart';
import 'package:sudoku_tutor/ui/features/free_play/pause_overlay.dart';
import 'package:sudoku_tutor/ui/features/free_play/resume_banner.dart';
import 'package:sudoku_tutor/ui/input/action_bar.dart';
import 'package:sudoku_tutor/ui/input/numpad_panel.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';

/// 假 scan：恒返回 nakedPair 删数型技巧结果（确定性，不触发真实引擎）。
TechniqueResult _fakeScanResult() => TechniqueResult(
      techniqueId: TechniqueId.nakedPair,
      eliminations: <Elimination>[Elimination(10, 5)],
      visual: VisualHint.assemble(
        patternCells: const <int>[11, 12],
        eliminated: <MapEntry<int, int>>[const MapEntry<int, int>(10, 5)],
        emphasized: <MapEntry<int, int>>[const MapEntry<int, int>(11, 5)],
      ),
    );

void main() {
  /// 装配自由练习页：路由直达 /free-play/session（extra 为 null 走
  /// 「续玩失败 → 中等难度新局」兜底），全部依赖注入假实现。
  Future<ProviderContainer> pumpFreePlayPage(
    WidgetTester tester,
    FakeProgressRepository repo, {
    Object? launch,
  }) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        puzzleBankRepositoryProvider.overrideWithValue(
          FakePuzzleBankRepository(),
        ),
        hintServiceProvider.overrideWithValue(
          HintService(
            scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
                _fakeScanResult(),
          ),
        ),
      ],
    );
    final GoRouter router = GoRouter(
      initialLocation: '/free-play/session',
      routes: <RouteBase>[
        GoRoute(
          path: '/free-play/session',
          name: 'freePlay',
          builder: (_, __) => const FreePlayPage(),
        ),
      ],
    );
    if (launch != null) {
      router.go('/free-play/session', extra: launch);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    // 收尾：同步停表 + 销毁容器，避免测试结束 pending timer。
    // ⚠️ 不能 `await discardSession()`：其内部 `await _repository()`
    // （provider 的 async build future）在 testWidgets 的 FakeAsync 停止后
    // **永不 resolve → 用例挂起**（实测：flutter_test 的 tearDown 在
    // verifyInvariants 之后、FakeAsync 已退出时执行）。同步 `timer.dispose()`
    // 取消计时器即可；对局断点清理非本测试关注点。
    addTearDown(() {
      container.read(gameSessionControllerProvider.notifier).timer.dispose();
      container.dispose();
    });
    // 等待开局异步链路（settings 加载 → 选题 → startNew → 发布状态 → UI 翻转）。
    for (int i = 0;
        i < 30 &&
            (container.read(gameSessionControllerProvider) == null ||
                find.byType(SudokuBoardView).evaluate().isEmpty);
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      container.read(gameSessionControllerProvider),
      isNotNull,
      reason: '对局应在多次 pump 后启动',
    );
    expect(
      find.byType(SudokuBoardView),
      findsOneWidget,
      reason: '棋盘应在 UI 翻转（_starting=false）后渲染',
    );
    return container;
  }

  testWidgets('棋盘渲染 + 顶部标题 + 功能条存在', (WidgetTester tester) async {
    await pumpFreePlayPage(tester, FakeProgressRepository());

    expect(find.byType(SudokuBoardView), findsOneWidget);
    expect(find.textContaining('自由练习 · '), findsOneWidget);
    expect(find.byType(ActionBar), findsOneWidget);
    // 功能条各键 tooltip（桌面快捷键语义）。
    expect(find.byTooltip('撤销（Ctrl+Z）'), findsOneWidget);
    expect(find.byTooltip('重做（Ctrl+Y）'), findsOneWidget);
    expect(find.byTooltip('擦除（Del）'), findsOneWidget);
    expect(find.byTooltip('自动笔记：填写全部合法候选数'), findsOneWidget);
    expect(find.byTooltip('提示（H）'), findsOneWidget);
    expect(find.byTooltip('核对答案（N）'), findsOneWidget);
    expect(find.byTooltip('暂停（Esc）'), findsNothing);
    expect(find.byTooltip('暂停'), findsOneWidget, reason: '暂停只保留在顶部');
    // 移动端（测试默认 android）应显示常驻数字键盘。
    expect(find.byType(NumpadPanel), findsOneWidget);
    // 无断点时对局页不出现续玩横幅。
    expect(find.byType(ResumeBanner), findsNothing);
  });

  testWidgets('tap 数字键盘 → 真正填数进对局', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());

    final GameSessionController controller =
        container.read(gameSessionControllerProvider.notifier);
    // 选中第一个空格。
    final GameSession session = container.read(gameSessionControllerProvider)!;
    int blank = -1;
    for (int i = 0; i < 81; i++) {
      if (session.board.isBlank(i)) {
        blank = i;
        break;
      }
    }
    controller.selectCell(blank);

    // 点数字键盘的「1」。
    await tester.tap(
      find.descendant(
        of: find.byType(NumpadPanel),
        matching: find.text('1'),
      ),
    );
    await tester.pump();

    final GameSession after = container.read(gameSessionControllerProvider)!;
    expect(after.board.valueAt(blank), 1, reason: '填数应写入盘面');
    expect(after.undoMoves, hasLength(1), reason: '填数应入撤销栈');
  });

  testWidgets('点击做题页空白区域 → 取消当前选中', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());
    final GameSessionController controller =
        container.read(gameSessionControllerProvider.notifier);
    final GameSession session = container.read(gameSessionControllerProvider)!;
    final int blank = session.board.blankCells().first;

    controller.selectCell(blank);
    await tester.pump();
    expect(
      container.read(gameSessionControllerProvider)!.selectedIndex,
      blank,
    );

    final Rect background =
        tester.getRect(find.byKey(const ValueKey<String>('game-background')));
    await tester.tapAt(background.topLeft + const Offset(2, 2));
    await tester.pump();

    expect(
      container.read(gameSessionControllerProvider)!.selectedIndex,
      isNull,
    );
  });

  testWidgets('自动笔记按钮 → 为全部空格填写合法候选且不进入笔记模式', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());
    GameSession session = container.read(gameSessionControllerProvider)!;
    expect(session.autoCandidates, isFalse, reason: '新默认应关闭自动候选');
    expect(session.board.candidateMasks.every((int mask) => mask == 0), isTrue);

    await tester.ensureVisible(find.text('自动笔记'));
    await tester.tap(find.text('自动笔记'));
    await tester.pump();

    session = container.read(gameSessionControllerProvider)!;
    expect(session.autoNotesFilled, isTrue);
    expect(session.noteMode, isFalse);
    expect(
      session.board.blankCells().every(
            (int cell) => session.board.candidateMasks[cell] != 0,
          ),
      isTrue,
    );

    await tester.tap(find.byTooltip('撤销（Ctrl+Z）'));
    await tester.pump();
    session = container.read(gameSessionControllerProvider)!;
    expect(session.autoNotesFilled, isFalse);
    expect(session.board.candidateMasks.every((int mask) => mask == 0), isTrue);

    await tester.tap(find.byTooltip('重做（Ctrl+Y）'));
    await tester.pump();
    session = container.read(gameSessionControllerProvider)!;
    expect(session.autoNotesFilled, isTrue);
    expect(
      session.board.blankCells().every(
            (int cell) => session.board.candidateMasks[cell] != 0,
          ),
      isTrue,
    );
  });

  testWidgets('手动暂停 → PauseOverlay 遮挡 + 单击空白恢复', (WidgetTester tester) async {
    await pumpFreePlayPage(tester, FakeProgressRepository());

    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();

    expect(find.byType(PauseOverlay), findsOneWidget);
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.textContaining('用时 '), findsOneWidget);
    expect(find.text('单击空白区域继续'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    expect(find.text('放弃'), findsOneWidget);

    // 单击遮罩空白处 → 遮挡收起。
    final Rect resumeArea = tester.getRect(
      find.byKey(const ValueKey<String>('pause-resume-area')),
    );
    await tester.tapAt(resumeArea.topLeft + const Offset(12, 12));
    await tester.pump();
    expect(find.byType(PauseOverlay), findsNothing);
  });

  testWidgets('短暂 inactive 恢复不误暂停；持续失焦才自动暂停', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 200));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 700));

    expect(container.read(gameSessionControllerProvider)!.paused, isFalse);
    expect(find.byType(PauseOverlay), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 700));

    expect(container.read(gameSessionControllerProvider)!.paused, isTrue);
    expect(find.byType(PauseOverlay), findsOneWidget);

    // 测试结束前恢复 binding 状态；产品语义仍要求玩家点击遮罩继续。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(container.read(gameSessionControllerProvider)!.paused, isTrue);
  });

  testWidgets('进入后台立即暂停，重复生命周期通知不会反向恢复', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(container.read(gameSessionControllerProvider)!.paused, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(container.read(gameSessionControllerProvider)!.paused, isTrue);
    expect(find.byType(PauseOverlay), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('无需点击屏幕，顶部计时 UI 每秒自动刷新', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());
    final int beforeSeconds =
        container.read(gameSessionControllerProvider)!.elapsedMs ~/ 1000;

    // TimerService 按真实 DateTime 累计；先让真实时钟前进，再推进测试节拍。
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1100)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    final GameSession after = container.read(gameSessionControllerProvider)!;
    final int afterSeconds = after.elapsedMs ~/ 1000;
    expect(afterSeconds, greaterThan(beforeSeconds));
    final String label = '${(afterSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(afterSeconds % 60).toString().padLeft(2, '0')}';
    expect(find.text(label), findsOneWidget, reason: '计时应由节拍主动触发页面重建');
  });

  testWidgets('提示按钮 → 提示卡片出现（两级逐级推进）', (WidgetTester tester) async {
    await pumpFreePlayPage(tester, FakeProgressRepository());

    // 一级提示：技巧名 + 区域高亮。
    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();
    expect(find.textContaining('一级'), findsOneWidget);
    expect(find.textContaining('此处可运用「裸对」'), findsOneWidget);

    // 二级提示：点明关键格。
    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();
    expect(find.textContaining('二级'), findsOneWidget);
    expect(find.textContaining('的关键格已标出'), findsOneWidget);

    // 当前结论已展开完毕时给出原因，避免按钮看似失效。
    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();
    expect(find.textContaining('当前这一步的提示已全部展开'), findsOneWidget);
  });

  testWidgets('提示后操作盘面 → 自动去除棋盘高亮但保留提示文字', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());
    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();

    SudokuBoardView board = tester.widget<SudokuBoardView>(
      find.byType(SudokuBoardView),
    );
    expect(board.viewModel.hintCells, isNotEmpty);
    expect(find.textContaining('此处可运用「裸对」'), findsOneWidget);

    final GameSession session = container.read(gameSessionControllerProvider)!;
    final int blank = session.board.blankCells().first;
    final NumpadPanel numpad = tester.widget<NumpadPanel>(
      find.byType(NumpadPanel),
    );
    numpad.callbacks.onDigit(session.solution![blank]);
    await tester.pump();
    board = tester.widget<SudokuBoardView>(find.byType(SudokuBoardView));
    expect(board.viewModel.hintCells, isNotEmpty,
        reason: '未选中格时数字输入未改变盘面，不应误判为提示已使用');

    container.read(gameSessionControllerProvider.notifier).selectCell(blank);
    numpad.callbacks.onDigit(session.solution![blank]);
    await tester.pump();

    board = tester.widget<SudokuBoardView>(find.byType(SudokuBoardView));
    expect(board.viewModel.hintCells, isEmpty);
    expect(board.viewModel.hintRegions, isEmpty);
    expect(board.viewModel.hintLinks, isEmpty);
    expect(board.viewModel.hintCandidateMarks, isEmpty);
    expect(find.textContaining('此处可运用「裸对」'), findsOneWidget);
  });

  testWidgets('填满且自动核验通过 → 播放恭喜动画', (WidgetTester tester) async {
    final ProviderContainer container =
        await pumpFreePlayPage(tester, FakeProgressRepository());
    final GameSessionController controller =
        container.read(gameSessionControllerProvider.notifier);
    final GameSession session = container.read(gameSessionControllerProvider)!;
    final List<int> solution = session.solution!;

    for (final int cell in session.board.blankCells()) {
      controller.selectCell(cell);
      controller.inputDigit(solution[cell]);
    }
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.byKey(const ValueKey<String>('congratulations-animation')),
      findsOneWidget,
    );
    expect(find.text('自动核验通过，整盘全部正确。'), findsOneWidget);

    await tester.tap(find.text('太棒了'));
    await tester.pumpAndSettle();
  });

  testWidgets('离线挑战使用固定规则，完成后生成成绩码而非普通恭喜动画', (WidgetTester tester) async {
    final AsyncDuelChallenge challenge = AsyncDuelChallenge.create(
      challengerName: '甲',
      puzzle: buildTestPuzzle(difficulty: Difficulty.medium),
      difficulty: Difficulty.medium,
      createdAtMs: 1700000000000,
    );
    final ProviderContainer container = await pumpFreePlayPage(
      tester,
      FakeProgressRepository(),
      launch: FreePlayLaunchChallenge(
        challenge: challenge,
        playerName: '乙',
      ),
    );

    expect(find.text('离线对决 · 中等'), findsOneWidget);
    expect(find.text('离线同题竞速'), findsOneWidget);
    final ActionBar actionBar =
        tester.widget<ActionBar>(find.byType(ActionBar));
    expect(actionBar.callbacks.onRequestHint, isNull);
    expect(actionBar.callbacks.onCheckAnswer, isNull);
    expect(actionBar.callbacks.onAutoNotes, isNull);
    expect(container.read(gameSessionControllerProvider)!.recordStats, isFalse);

    final GameSessionController controller =
        container.read(gameSessionControllerProvider.notifier);
    final GameSession session = container.read(gameSessionControllerProvider)!;
    for (final int cell in session.board.blankCells()) {
      controller.selectCell(cell);
      controller.inputDigit(session.solution![cell]);
    }
    await tester.pump();
    await tester.pump();

    expect(find.text('挑战完成！'), findsOneWidget);
    final SelectableText resultCode = tester.widget<SelectableText>(
      find.byKey(const ValueKey<String>('duel-result-code')),
    );
    expect(resultCode.data, startsWith('SDKR1.'));
    expect(find.byKey(const ValueKey<String>('congratulations-animation')),
        findsNothing);
  });
}
