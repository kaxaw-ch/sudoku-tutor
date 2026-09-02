/// 原理演示页（T-EDU-02 / P0-EDU-02，S-03）。
///
/// - 盘面**只读不可填数**：`SudokuBoardView` 不挂任何点击回调；
/// - 教学图层：每步高亮/连线/划除走 `step.visual`（T-UI-07 overlay）；
/// - 默认手动「下一步」+ 自动播放 2s/步可暂停 + 上一步 + 重播 + 进度 `n/m`；
/// - 进度条可拖动到任意步骤，并只标出本关主技巧的全部关键点；
/// - 可随时返回或进入下一关；到达最后一步时完成本关并写档；
/// - 宽屏使用棋盘/讲解双栏，窄屏改为可滚动单栏，避免控件挤压溢出。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/teaching/demo_controller.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
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
  const DemoPage({required this.levelId, super.key});

  /// 当前路由指定的关卡 id。
  final String levelId;

  @override
  ConsumerState<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends ConsumerState<DemoPage> {
  bool _disposed = false;
  String? _requestedLevelId;
  // 缓存控制器引用：dispose() 里不能用 ref（flutter_riverpod 硬规则：
  // element 卸载中 ref 已不可用，会抛 StateError），须用缓存引用停表。
  DemoController? _ctrl;

  @override
  void initState() {
    super.initState();
    _scheduleStart(widget.levelId);
  }

  @override
  void didUpdateWidget(covariant DemoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levelId != widget.levelId) {
      _scheduleStart(widget.levelId);
    }
  }

  void _scheduleStart(String levelId) {
    if (levelId.isEmpty || levelId == _requestedLevelId) {
      return;
    }
    _requestedLevelId = levelId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || _requestedLevelId != levelId) {
        return;
      }
      final DemoController ctrl = ref.read(demoControllerProvider.notifier);
      _ctrl = ctrl;
      ctrl.start(levelId);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // 离开页面即停止自动播放（避免 Timer 泄漏，flutter_test 强校验）。
    _ctrl?.stopAutoPlay();
    super.dispose();
  }

  /// 随时退出并返回学习地图，不设置强制观看门槛。
  void _handleExit() {
    _ctrl?.stopAutoPlay();
    context.goNamed(RouteNames.home);
  }

  /// 进入下一关前只需停止自动播放。
  Future<bool> _beforeNextLevel() async {
    _ctrl?.stopAutoPlay();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final DemoState? state = ref.watch(demoControllerProvider);
    if (state == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.text('原理演示'))),
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
    final bool showTechniqueChip = MediaQuery.sizeOf(context).width >= 1000;

    // 控制与旁白在窄屏可换行、可滚动；在宽屏放到棋盘右侧，充分利用横向空间。
    final Widget lessonPanel = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
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
            narration: context.l10n.scriptNarration(
              state.currentStep,
              state.narration,
            ),
            techniqueName:
                context.l10n.techniqueName(state.currentStep.techniqueId),
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
            tooltip: context.l10n.text('返回'),
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleExit,
          ),
          title: Text(
            context.l10n.lessonTitle(state.level.id, state.level.title),
          ),
          actions: <Widget>[
            NextLevelButton(
              currentLevelId: state.level.id,
              beforeNavigate: _beforeNextLevel,
            ),
            if (showTechniqueChip)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Chip(
                    label: Text(
                      context.l10n.techniqueName(state.currentStep.techniqueId),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth >= 760) {
                return Padding(
                  key: const ValueKey<String>('demo-wide-layout'),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 560,
                              maxHeight: 560,
                            ),
                            // 只读：不传输入回调。
                            child: SudokuBoardView(viewModel: viewModel),
                          ),
                        ),
                      ),
                      const VerticalDivider(width: AppSpacing.xl),
                      SizedBox(
                        width: constraints.maxWidth >= 1100 ? 460 : 400,
                        child: SingleChildScrollView(child: lessonPanel),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                key: const ValueKey<String>('demo-compact-layout'),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: AspectRatio(
                            aspectRatio: 1,
                            // 只读：不传输入回调。
                            child: SudokuBoardView(viewModel: viewModel),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    lessonPanel,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
