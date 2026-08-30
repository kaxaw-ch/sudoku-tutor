/// 原理演示页（T-EDU-02 / P0-EDU-02，S-03）。
///
/// - 盘面**只读不可填数**：`SudokuBoardView` 不挂任何点击回调；
/// - 教学图层：每步高亮/连线/划除走 `step.visual`（T-UI-07 overlay）；
/// - 默认手动「下一步」+ 自动播放 2s/步可暂停 + 上一步 + 重播 + 进度 `n/m`；
/// - 技巧进度条标出本关脚本中的技巧节点，点击可快速跳转；
/// - **首次进入须完整看完**（`mustWatchToEnd` 时拦截返回），看完最后一步
///   即算完成并写档（hintUsed=0、errorCount=0）；之后可跳过。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/teaching/demo_controller.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/teaching/next_level_button.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';
import 'package:sudoku_tutor/ui/widgets/loading_indicator.dart';

import 'narration_card.dart';
import 'step_control_bar.dart';
import 'technique_progress_bar.dart';

/// 原理演示页。
class DemoPage extends ConsumerStatefulWidget {
  /// 构造演示页。
  const DemoPage({super.key});

  @override
  ConsumerState<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends ConsumerState<DemoPage> {
  bool _disposed = false;
  // 缓存控制器引用：dispose() 里不能用 ref（flutter_riverpod 硬规则：
  // element 卸载中 ref 已不可用，会抛 StateError），须用缓存引用停表。
  DemoController? _ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }
      final String levelId =
          GoRouterState.of(context).pathParameters['levelId'] ?? '';
      if (levelId.isNotEmpty) {
        final DemoController ctrl = ref.read(demoControllerProvider.notifier);
        _ctrl = ctrl;
        ctrl.start(levelId);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // 离开页面即停止自动播放（避免 Timer 泄漏，flutter_test 强校验）。
    _ctrl?.stopAutoPlay();
    super.dispose();
  }

  /// 退出：首次未看完时拦截提示；否则放行返回学习地图。
  void _handleExit() {
    final DemoState? st = ref.read(demoControllerProvider);
    if (st != null && st.mustWatchToEnd) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('首次进入须完整观看本关（看完最后一步即可退出）')),
        );
      return;
    }
    context.goNamed(RouteNames.home);
  }

  /// 下一关同样遵守首次完整观看限制。
  Future<bool> _beforeNextLevel() async {
    final DemoState? st = ref.read(demoControllerProvider);
    if (st != null && st.mustWatchToEnd) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('首次进入须完整观看本关（看完最后一步即可进入下一关）'),
          ),
        );
      return false;
    }
    _ctrl?.stopAutoPlay();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final DemoState? state = ref.watch(demoControllerProvider);
    if (state == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('原理演示')),
        body: const LoadingIndicator(),
      );
    }
    final DemoController controller = ref.read(demoControllerProvider.notifier);
    final Puzzle puzzle = state.level.toLevelPuzzle().toCore();
    final Board board =
        DemoController.boardAt(state.level, state.steps, state.currentIndex);
    final GameSession session = GameSession(
      puzzle: puzzle,
      board: board,
      difficulty: puzzle.difficulty ?? Difficulty.beginner,
      noteMasks: List<int>.of(board.candidateMasks),
      noteMode: false,
      autoCandidates: true,
      selectedIndex: null,
      errorCells: const <int>{},
      elapsedMs: 0,
      paused: false,
      completed: state.completed,
      wrongCount: 0,
      correctCount: 0,
      usedHints: 0,
      markErrors: true,
      highlightSameDigit: true,
    );
    final BoardViewModel viewModel = BoardViewModel.fromSession(
      session,
      teachingOverlay: state.currentVisual,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleExit,
          ),
          title: Text(state.level.title),
          actions: <Widget>[
            NextLevelButton(
              currentLevelId: state.level.id,
              beforeNavigate: _beforeNextLevel,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Chip(
                  label: Text(state.currentStep.techniqueId.zhName),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 520,
                      maxHeight: 520,
                    ),
                    // 只读：不传 onCellTap / onCellLongPress → 点击无输入响应。
                    child: SudokuBoardView(viewModel: viewModel),
                  ),
                ),
              ),
            ),
            DemoTechniqueProgressBar(
              steps: state.steps,
              currentIndex: state.currentIndex,
              targetTechniques: state.level.techniqueTags,
              onStepSelected: controller.jumpTo,
            ),
            const SizedBox(height: AppSpacing.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (
                Widget child,
                Animation<double> animation,
              ) =>
                  FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: NarrationCard(
                key: ValueKey<int>(state.currentIndex),
                narration: state.narration,
                techniqueName: state.currentStep.techniqueId.zhName,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StepControlBar(
              progress: state.progress,
              total: state.stepCount,
              autoPlaying: state.autoPlaying,
              autoPlayFast: state.autoPlayFast,
              onPrevious: controller.previous,
              onNext: controller.next,
              onToggleAutoPlay: controller.toggleAutoPlay,
              onToggleSpeed: controller.toggleSpeed,
              onReplay: controller.replay,
              enableNext: !state.atEnd,
              enableAutoPlay: state.stepCount > 1,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
