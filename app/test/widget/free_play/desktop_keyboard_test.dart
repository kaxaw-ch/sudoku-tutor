/// 自由练习页 · 桌面（Windows）路径测试。
///
/// 覆盖：
/// - 桌面键盘：选中空格后按数字键真正填数（回归：Focus 必须在
///   DesktopShortcuts 内部，写反则按键冒泡不经过 Shortcuts）；
/// - 桌面横向布局（用户要求）：棋盘在左，右侧上=技巧讲解区、
///   下=1-9 数字键盘 + 功能条（桌面也渲染 NumpadPanel）。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/free_play/free_play_page.dart';
import 'package:sudoku_tutor/ui/input/action_bar.dart';
import 'package:sudoku_tutor/ui/input/numpad_panel.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';

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
  /// 装配 Windows 平台自由练习页（横向布局路径），返回容器。
  ///
  /// ⚠️ 调用方必须在测试体内 `debugDefaultTargetPlatformOverride = null`
  /// 还原（flutter_test 的 verifyInvariants 在 addTearDown 之前检查）。
  Future<ProviderContainer> pumpWindowsFreePlay(
    WidgetTester tester,
    FakeProgressRepository repo,
  ) async {
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
    addTearDown(() {
      container.read(gameSessionControllerProvider.notifier).timer.dispose();
      container.dispose();
    });
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    for (int i = 0;
        i < 30 &&
            (container.read(gameSessionControllerProvider) == null ||
                find.byType(SudokuBoardView).evaluate().isEmpty);
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(SudokuBoardView), findsOneWidget);
    return container;
  }

  testWidgets('桌面键盘：选中空格后按数字键 1 真正填数', (WidgetTester tester) async {
    // 强制 Windows 平台（桌面路径）。
    // ⚠️ 必须在测试体内还原（flutter_test 的 verifyInvariants 在
    // addTearDown 之前检查 debugDefaultTargetPlatformOverride）。
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final FakeProgressRepository repo = FakeProgressRepository();
    final ProviderContainer container = await pumpWindowsFreePlay(tester, repo);

    // 选中第一个空格（controller 直选，等价于点击棋盘）。
    final GameSession session = container.read(gameSessionControllerProvider)!;
    int blank = -1;
    for (int i = 0; i < 81; i++) {
      if (session.board.isBlank(i)) {
        blank = i;
        break;
      }
    }
    expect(blank, greaterThanOrEqualTo(0));
    container.read(gameSessionControllerProvider.notifier).selectCell(blank);
    await tester.pump();

    // 按键盘数字键 1（桌面主键盘）。
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();

    final GameSession after = container.read(gameSessionControllerProvider)!;
    expect(after.board.valueAt(blank), 1, reason: '桌面键盘数字键应写入盘面');

    // 测试体内还原平台覆盖。
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('桌面横向布局：棋盘在左，数字键盘与功能条在右', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final FakeProgressRepository repo = FakeProgressRepository();
    await pumpWindowsFreePlay(tester, repo);

    // 桌面横向：数字键盘也渲染（右侧下方 1-9 键盘）。
    expect(find.byType(NumpadPanel), findsOneWidget,
        reason: '桌面横向布局应显示 1-9 数字键盘');
    expect(find.byType(ActionBar), findsOneWidget);

    // 几何断言：棋盘整体在左，数字键盘/功能条在右。
    final Rect boardRect = tester.getRect(find.byType(SudokuBoardView));
    final Rect numpadRect = tester.getRect(find.byType(NumpadPanel));
    final Rect actionRect = tester.getRect(find.byType(ActionBar));
    expect(numpadRect.left, greaterThan(boardRect.right), reason: '数字键盘应在棋盘右侧');
    expect(actionRect.left, greaterThan(boardRect.right), reason: '功能条应在棋盘右侧');
    // 右侧内部：数字键盘在功能条上方。
    expect(numpadRect.bottom, lessThan(actionRect.top + 0.01),
        reason: '数字键盘应在功能条上方');

    debugDefaultTargetPlatformOverride = null;
  });
}
