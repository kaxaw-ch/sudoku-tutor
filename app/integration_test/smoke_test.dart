/// T-QA-04 · 端到端冒烟测试（P0-QA-07）。
///
/// 覆盖链路：**启动 → 自由练习 → 填数 → 提示 → 退出 → 续玩**。
///
/// 实现说明：
/// - 沙箱无法跑真机，故用 `testWidgets` + `IntegrationTestWidgetsFlutterBinding`
///   以 widget 模拟方式走完全流程（同一条路由/状态机，非 mock UI）；
/// - 全部依赖注入内存假实现（存档仓储 / 题库 / 提示扫描），
///   保证确定性、不触发真实 Isolate 与 path_provider；
/// - 由主理人在锁文件清理窗口内运行 `flutter test integration_test` 验证。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sudoku_tutor/app/app.dart';
import 'package:sudoku_tutor/app/router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/game_session_controller.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/free_play/resume_banner.dart';

import '../test/helpers/fake_progress_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 假提示扫描（恒返回 nakedPair 删数结果，规避真实 Isolate）。
  HintService fakeHintService() => HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            TechniqueResult(
          techniqueId: TechniqueId.nakedPair,
          eliminations: <Elimination>[Elimination(10, 5)],
          visual: VisualHint.assemble(
            patternCells: const <int>[11, 12],
            eliminated: <MapEntry<int, int>>[
              const MapEntry<int, int>(10, 5),
            ],
            emphasized: <MapEntry<int, int>>[
              const MapEntry<int, int>(11, 5),
            ],
          ),
        ),
      );

  testWidgets('冒烟：启动 → 自由练习 → 填数 → 提示 → 退出 → 续玩',
      (WidgetTester tester) async {
    final FakeProgressRepository repo = FakeProgressRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        puzzleBankRepositoryProvider.overrideWithValue(
          FakePuzzleBankRepository(),
        ),
        hintServiceProvider.overrideWithValue(fakeHintService()),
      ],
    );
    addTearDown(() async {
      // 先 pump 清掉 pending 的帧回调（free_play_page 首帧 _launch 等），
      // 避免测试结束后异步回调读到已 dispose 的 container / FocusManager。
      // 用 pump（非 pumpAndSettle）避免无限动画导致 tearDown 超时。
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await container
          .read(gameSessionControllerProvider.notifier)
          .discardSession();
      container.dispose();
    });

    // ① 启动：应用可挂载并渲染首页。
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: SudokuTutorApp(router: buildRouter()),
      ),
    );
    await tester.pump();
    // 学习地图主页（T-EDU-06 重写后）：AppBar 标题同步渲染。
    expect(find.text('学习地图'), findsOneWidget);

    // ② 进入自由练习：首页 → 难度选择 → 选择「入门」。
    await tester.tap(find.text('自由练习'));
    for (int i = 0;
        i < 30 && find.text('选择难度').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('选择难度'), findsOneWidget);
    await tester.tap(find.text('入门'));
    // 等待对局启动（settings 加载 → 选题 → startNew）。
    for (int i = 0;
        i < 30 && container.read(gameSessionControllerProvider) == null;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final GameSessionController controller =
        container.read(gameSessionControllerProvider.notifier);
    expect(
      container.read(gameSessionControllerProvider),
      isNotNull,
      reason: '自由练习对局应启动',
    );
    expect(find.textContaining('自由练习 · '), findsOneWidget);
    expect(find.byType(SudokuBoardView), findsOneWidget);

    // ③ 填数：选中一个空格，点数字键盘「1」。
    final GameSession session = container.read(gameSessionControllerProvider)!;
    int blank = -1;
    for (int i = 0; i < 81; i++) {
      if (session.board.isBlank(i)) {
        blank = i;
        break;
      }
    }
    controller.selectCell(blank);
    // 桌面端无 NumpadPanel（仅移动端渲染）。冒烟定位是「状态机链路」而非输入法：
    // 填数直接走 controller（与 ④ 用 tap 提示按钮而非 H 键的精神一致）；
    // 桌面快捷键本身由 test/widget/input/desktop_shortcuts_test.dart 独立覆盖。
    controller.inputDigit(1);
    await tester.pump();
    expect(
      container.read(gameSessionControllerProvider)!.board.valueAt(blank),
      1,
      reason: '填数已写入盘面',
    );

    // ④ 提示：点击提示按钮 → 提示卡片出现。
    await tester.tap(find.byTooltip('提示（H）'));
    await tester.pump();
    expect(find.textContaining('一级'), findsOneWidget, reason: '提示卡片出现');
    expect(
      container.read(gameSessionControllerProvider)!.usedHints,
      1,
      reason: '提示配额已消费',
    );

    // ⑤ 退出：模拟系统返回 → PopScope 拦截并自动保存断点 → 回难度选择页。
    await tester.binding.handlePopRoute();
    // 用有限轮询（非 pumpAndSettle，防无限动画/loading 挂死）。
    for (int i = 0;
        i < 30 && find.text('选择难度').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('选择难度'), findsOneWidget, reason: '退出后回到难度选择页');
    // 保存断点在 goNamed 之前 await 完成，但保险起见轮询等落档（防异步时序）。
    for (int i = 0; i < 30 && repo.snapshot == null; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(repo.snapshot, isNotNull, reason: '退出自动保存断点');

    // 断点横幅出现（续玩入口）。
    for (int i = 0;
        i < 30 && find.byType(ResumeBanner).evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(ResumeBanner), findsOneWidget);
    expect(find.text('检测到未完成的对局'), findsOneWidget);

    // ⑥ 续玩：点击「继续上次对局」→ 恢复同一局（盘面/难度一致）。
    await tester.tap(find.text('继续上次对局'));
    for (int i = 0;
        i < 50 && container.read(gameSessionControllerProvider) == null;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      container.read(gameSessionControllerProvider),
      isNotNull,
      reason: '续玩应恢复对局',
    );
    final GameSession restored = container.read(gameSessionControllerProvider)!;
    expect(restored.board.valueAt(blank), 1, reason: '续玩盘面保留已填数字');
    expect(restored.difficulty, Difficulty.beginner, reason: '难度保持一致');
    // 等 UI 从 loading 翻转为对局页（_launch → setState(_starting=false)）。
    for (int i = 0;
        i < 50 && find.text('自由练习 · 入门').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('自由练习 · 入门'), findsOneWidget);
  });
}
