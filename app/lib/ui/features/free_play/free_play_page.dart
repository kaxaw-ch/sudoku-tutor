/// 自由练习页（S-06，P0-PRA-*，T-UI-04）。
///
/// 结构（自上而下）：
/// - 顶部：难度标签、计时（可关，P0-PRA-08）、暂停按钮；
/// - 中部：九宫格（`SudokuBoardView`，含提示高亮透传）；
/// - 底部：功能条（`ActionBar` 撤销/重做/擦除/笔记/提示/核对）
///   + 移动端常驻 3×3 数字键盘（桌面端走快捷键，不显示键盘）。
///
/// 关键交互：
/// - **提示两级 UI**：一级=技巧名 + 区域高亮；二级=点明关键格；
///   任何级别**都不显示填数答案**（`HintState` 结构上无 Placement，
///   这里只消费 `narration + visual`，visual 由 HintService 裁剪后透传）；
/// - **手动暂停**：遮挡盘面，单击空白继续，仅保留放弃按钮；
/// - **失焦/锁屏自动暂停**（`AppLifecycleState`）；
/// - **退出自动保存断点**（`PopScope` 拦截 → `saveSnapshot`）；
/// - 新局/续玩由 [FreePlayLaunch] 参数驱动。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_picker.dart';
import 'package:sudoku_tutor/domain/session/check_answer_service.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/game_session_controller.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/settings/settings_controller.dart';
import 'package:sudoku_tutor/domain/stats/stats_collector.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/input/action_bar.dart';
import 'package:sudoku_tutor/ui/input/desktop_shortcuts.dart';
import 'package:sudoku_tutor/ui/input/input_intents.dart';
import 'package:sudoku_tutor/ui/input/numpad_panel.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';
import 'package:sudoku_tutor/ui/widgets/congratulations_animation.dart';
import 'package:sudoku_tutor/ui/widgets/loading_indicator.dart';

import 'pause_overlay.dart';

/// 自由练习页启动参数（路由 extra）。
sealed class FreePlayLaunch {
  /// 构造参数。
  const FreePlayLaunch();
}

/// 开始一局新对局（指定难度）。
class FreePlayLaunchNewGame extends FreePlayLaunch {
  /// 构造参数。
  const FreePlayLaunchNewGame(this.difficulty);

  /// 目标难度。
  final Difficulty difficulty;
}

/// 续玩上次对局（restoreIfAny）。
class FreePlayLaunchResume extends FreePlayLaunch {
  /// 构造参数。
  const FreePlayLaunchResume();
}

/// 用文本导入的题目开局（难度取题面标注，缺省按中等）。
class FreePlayLaunchImported extends FreePlayLaunch {
  /// 构造参数。
  const FreePlayLaunchImported(this.puzzle);

  /// 导入的题目。
  final Puzzle puzzle;
}

/// 自由练习页。
class FreePlayPage extends ConsumerStatefulWidget {
  /// 构造页面。
  const FreePlayPage({super.key});

  @override
  ConsumerState<FreePlayPage> createState() => _FreePlayPageState();
}

class _FreePlayPageState extends ConsumerState<FreePlayPage>
    with WidgetsBindingObserver {
  /// `inactive` 在桌面失焦与移动端系统过渡中都可能短暂出现。短暂抖动不应
  /// 立即遮住棋盘；真正进入 hidden / paused 仍会立即暂停。
  static const Duration _inactivePauseDelay = Duration(milliseconds: 600);

  HintState? _hint;
  bool _hintHighlightActive = false;
  bool _starting = true;
  // 页面销毁后置 true，拦截首帧异步开局回调（防 dispose 后碰 ref/context）。
  bool _disposed = false;
  // 缓存对局控制器引用：dispose() 里不能再用 ref，须用缓存的引用停表。
  GameSessionController? _ctrl;
  StreamSubscription<GameSessionEvent>? _gameSubscription;
  bool _completionCelebrated = false;
  Timer? _inactivePauseTimer;
  AppLifecycleState? _lifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleState = WidgetsBinding.instance.lifecycleState;
    WidgetsFlutterBinding.ensureInitialized();
    // 开局在首帧后异步执行（需要读取仓储）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) {
        return;
      }
      _launch();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    // 页面销毁即停止对局计时（P0-PRA-08 语义：退出页面不再计时）。
    // ⚠️ 必须在 widget dispose 阶段取消 Timer（flutter_test 的
    // `_verifyInvariants` 在 tearDown 之前检查 pending timer，tearDown 里
    // 才停表会来不及；产品上也是页面销毁后不该再有计时器空转）。
    _ctrl?.timer.pause();
    _inactivePauseTimer?.cancel();
    unawaited(_gameSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 失焦/锁屏自动暂停（P0-PRA-08）。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        // 某些系统交互只会造成极短的 inactive；回到前台时取消误暂停。
        _inactivePauseTimer?.cancel();
        _inactivePauseTimer = null;
        return;
      case AppLifecycleState.inactive:
        _scheduleInactivePause();
        return;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _inactivePauseTimer?.cancel();
        _inactivePauseTimer = null;
        _pauseForLifecycle();
        return;
    }
  }

  void _scheduleInactivePause() {
    _inactivePauseTimer?.cancel();
    _inactivePauseTimer = Timer(_inactivePauseDelay, () {
      _inactivePauseTimer = null;
      if (_lifecycleState == AppLifecycleState.inactive) {
        _pauseForLifecycle();
      }
    });
  }

  /// 生命周期暂停只执行“暂停”，绝不切换状态。
  void _pauseForLifecycle() {
    if (!mounted || _disposed) {
      return;
    }
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null || session.paused || session.completed) {
      return;
    }
    ref.read(gameSessionControllerProvider.notifier).pause();
  }

  /// 根据路由参数开局。
  Future<void> _launch() async {
    // 防御：页面已销毁（测试收尾/快速退出）时不再碰 ref/context。
    if (!mounted || _disposed) {
      return;
    }
    final Object? extra = GoRouterState.of(context).extra;
    final SettingsState settings =
        await ref.read(settingsControllerProvider.future);
    if (!mounted || _disposed) {
      return;
    }
    final GameSessionController controller =
        ref.read(gameSessionControllerProvider.notifier);
    _ctrl = controller; // 供 dispose() 停表（dispose 阶段不可用 ref）。
    await _gameSubscription?.cancel();
    if (!mounted || _disposed) {
      return;
    }
    _completionCelebrated = false;
    _gameSubscription = controller.events.listen(_handleGameEvent);
    // 每局重置提示配额与解锁进度。
    ref.read(hintServiceProvider).resetForNewRound();

    bool ok = false;
    switch (extra) {
      case FreePlayLaunchResume():
        ok = await controller.restoreIfAny(settings: settings);
      case FreePlayLaunchNewGame(difficulty: final Difficulty difficulty):
        ok = await _startNew(difficulty, settings);
      case FreePlayLaunchImported(puzzle: final Puzzle puzzle):
        ok = await _startImported(puzzle, settings);
      case null:
        // 直接进入（测试兜底）：尝试续玩，无断点则中等难度新局。
        ok = await controller.restoreIfAny(settings: settings) ||
            await _startNew(Difficulty.medium, settings);
      default:
        ok = await _startNew(Difficulty.medium, settings);
    }
    if (!mounted) {
      return;
    }
    if (!ok) {
      // 开局失败：回难度选择页。
      context.goNamed('difficulty');
      return;
    }
    // 异步开局期间若应用已经进入后台，前面的生命周期通知可能发生在
    // session 创建之前；开局完成后必须再核对一次，避免后台继续计时。
    switch (_lifecycleState) {
      case AppLifecycleState.inactive:
        _scheduleInactivePause();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _pauseForLifecycle();
        break;
      case AppLifecycleState.resumed:
      case null:
        break;
    }
    setState(() => _starting = false);
  }

  /// 选题并开始新局（困难/大师只用预置题库，由 PuzzlePicker 保证）。
  Future<bool> _startNew(Difficulty difficulty, SettingsState settings) async {
    final PuzzlePicker picker = ref.read(puzzlePickerProvider);
    final Puzzle puzzle = await picker.pick(difficulty);
    return _startWith(
      puzzle,
      difficulty: difficulty,
      settings: settings,
    );
  }

  /// 用导入的题目开局（难度缺省按中等语义）。
  Future<bool> _startImported(Puzzle puzzle, SettingsState settings) async {
    final Difficulty difficulty = puzzle.difficulty ?? Difficulty.medium;
    return _startWith(puzzle, difficulty: difficulty, settings: settings);
  }

  /// 统一开局入口。
  Future<bool> _startWith(
    Puzzle puzzle, {
    required Difficulty difficulty,
    required SettingsState settings,
  }) async {
    await ref
        .read(gameSessionControllerProvider.notifier)
        .startNew(difficulty: difficulty, puzzle: puzzle, settings: settings);
    return true;
  }

  // ------------------------------------------------------------ 交互

  /// 自动核验反馈：失败提示全部错格，成功只播放一次恭喜动画。
  void _handleGameEvent(GameSessionEvent event) {
    if (!mounted || _disposed) {
      return;
    }
    if (event case GameAutoCheckFailedEvent(:final wrongCount)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) {
          _showMessage('自动核验发现 $wrongCount 格错误（已标红）');
        }
      });
      return;
    }
    if (event is GameCompletedEvent && !_completionCelebrated) {
      _completionCelebrated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_disposed) {
          unawaited(CongratulationsAnimation.show(context));
        }
      });
    }
  }

  /// 请求提示（两级 UI 与 HintService 一致）。
  Future<void> _requestHint() async {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null) {
      return;
    }
    final SettingsState settings =
        await ref.read(settingsControllerProvider.future);
    final HintService service = ref.read(hintServiceProvider);
    final HintState? hint = await service.requestNext(
      board: session.board,
      solution: session.solution,
      scope: HintScope.freePlay,
      quota: settings.hintQuota,
    );
    if (!mounted) {
      return;
    }
    if (hint == null) {
      _showMessage(service.lastUnavailableReason?.zhMessage ?? '暂无可用提示');
      return;
    }
    // 成功：记录配额消耗，展示提示（narration + visual，无填数答案）。
    ref.read(gameSessionControllerProvider.notifier).markHintUsed();
    setState(() {
      _hint = hint;
      _hintHighlightActive = true;
    });
  }

  /// 用户根据提示操作盘面后，仅收起棋盘高亮；提示文字继续保留供回看。
  void _consumeHintHighlight() {
    if (!_hintHighlightActive || !mounted) {
      return;
    }
    setState(() => _hintHighlightActive = false);
  }

  /// 执行输入，并且只在盘面内容确实发生变化时认为提示已被使用。
  void _runBoardAction(VoidCallback action) {
    final GameSession? before = ref.read(gameSessionControllerProvider);
    action();
    final GameSession? after = ref.read(gameSessionControllerProvider);
    if (before != null &&
        after != null &&
        (!listEquals(before.board.values, after.board.values) ||
            !listEquals(
              before.board.candidateMasks,
              after.board.candidateMasks,
            ))) {
      _consumeHintHighlight();
    }
  }

  /// 核对答案：只标错不纠正（P0-PRA-03），错误计入统计。
  void _checkAnswer() {
    final GameSessionController controller =
        ref.read(gameSessionControllerProvider.notifier);
    final CheckResult result = controller.checkAnswer();
    if (!mounted) {
      return;
    }
    if (result.wrongCount > 0) {
      _showMessage('有 ${result.wrongCount} 格填错（已标红）');
    } else {
      _showMessage('当前已填数全部正确');
    }
  }

  /// 暂停/继续。
  void _togglePause() {
    ref.read(gameSessionControllerProvider.notifier).togglePause();
    setState(() {});
  }

  /// 退出并自动保存断点（P0-PRA-09；返回按钮与系统返回同一语义）。
  Future<void> _exitAndSave() async {
    final GameSessionController controller =
        ref.read(gameSessionControllerProvider.notifier);
    await controller.saveSnapshot();
    // 断点已变化 → 强制难度页重算横幅（hasSessionProvider 有缓存）。
    ref.invalidate(hasSessionProvider);
    if (mounted) {
      context.goNamed('difficulty');
    }
  }

  /// 放弃本局（二次确认 → 清除断点 → 返回）。
  void _quitGame() {
    final BuildContext stateContext = context;
    showDialog<void>(
      context: stateContext,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('放弃本局？'),
        content: const Text('放弃后将清除本局进度，且不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref
                  .read(gameSessionControllerProvider.notifier)
                  .discardSession();
              if (stateContext.mounted) {
                stateContext.goNamed('difficulty');
              }
            },
            child: const Text('放弃'),
          ),
        ],
      ),
    );
  }

  /// 选区移动（桌面方向键）。
  void _moveSelection(MoveDirection direction) {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null) {
      return;
    }
    final int current = session.selectedIndex ?? 40;
    final int row = current ~/ 9;
    final int col = current % 9;
    final int next = switch (direction) {
      MoveDirection.up => _clamp(row - 1) * 9 + col,
      MoveDirection.down => _clamp(row + 1) * 9 + col,
      MoveDirection.left => row * 9 + _clamp(col - 1),
      MoveDirection.right => row * 9 + _clamp(col + 1),
    };
    ref.read(gameSessionControllerProvider.notifier).selectCell(next);
  }

  static int _clamp(int v) => v < 0 ? 0 : (v > 8 ? 8 : v);

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ------------------------------------------------------------ 渲染

  @override
  Widget build(BuildContext context) {
    // 保持统计采集常驻（T-DOM-06）。
    ref.watch(statsCollectorProvider);
    final GameSession? session = ref.watch(gameSessionControllerProvider);
    final SettingsState settings =
        ref.watch(settingsStateProvider).valueOrNull ?? const SettingsState();

    if (_starting || session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('自由练习')),
        body: const LoadingIndicator(),
      );
    }

    final GameSessionController controller =
        ref.read(gameSessionControllerProvider.notifier);
    _ctrl = controller; // 供 dispose() 停表。
    final BoardViewModel viewModel = BoardViewModel.fromSession(
      session,
      hintVisual: _hintHighlightActive ? _hint?.visual : null,
    );
    final bool isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        // 退出自动保存断点（P0-PRA-09）。
        _exitAndSave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back),
            onPressed: _exitAndSave,
          ),
          title: Text('自由练习 · ${session.difficulty.zhName}'),
          actions: <Widget>[
            if (settings.showTimer) _TimerBadge(session: session),
            IconButton(
              tooltip: '暂停',
              icon: Icon(session.paused ? Icons.play_arrow : Icons.pause),
              onPressed: _togglePause,
            ),
          ],
        ),
        body: Stack(
          children: <Widget>[
            // 桌面端快捷键开箱即用（P0-UI-05）：autofocus 使进入页面即获焦点，
            // 数字键/方向键/功能键无需先点击即可生效。
            // ⚠️ Focus 必须在 DesktopShortcuts 内部：按键事件从焦点节点向上
            // 冒泡，Shortcuts/Actions 需位于祖先路径才能拦截（写反则键盘失效）。
            DesktopShortcuts(
              callbacks: _callbacks(controller),
              child: GestureDetector(
                key: const ValueKey<String>('game-background'),
                behavior: HitTestBehavior.opaque,
                onTap: () => controller.selectCell(null),
                child: Focus(
                  autofocus: true,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      // 桌面 → 恒横向（用户要求）：不依赖内容宽高比——
                      // ResponsiveShell 大窗口限宽 1200 后内容宽仍 > 高，
                      // 用 maxWidth>maxHeight 判定会在全屏时误判为竖排。
                      final bool landscape = !isMobile;
                      // 棋盘边长：横向时随可用空间放大（最小 320，上限取
                      // 「左侧可用宽」与「可用高」的较小者），随窗口变大而变大。
                      final double boardSide = landscape
                          ? math.max(
                              320,
                              math.min(
                                constraints.maxHeight - AppSpacing.md * 2,
                                constraints.maxWidth -
                                    kDesktopGamePanelWidth -
                                    AppSpacing.md * 2,
                              ),
                            )
                          : 520;
                      // 棋盘（SudokuBoardView 内部按 min(宽,高) 自定正方形）。
                      final Widget board = ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: boardSide,
                          maxHeight: boardSide,
                        ),
                        child: SudokuBoardView(
                          viewModel: viewModel,
                          onCellTap: controller.selectCell,
                          onCellLongPress: (int index) {
                            controller.selectCell(index);
                            controller.toggleNoteMode();
                          },
                        ),
                      );
                      final Widget numpad = NumpadPanel(
                        callbacks: _callbacks(controller),
                        digitCounts: session.digitCounts(),
                        noteMode: session.noteMode,
                        autoNotesFilled:
                            session.autoCandidates || session.autoNotesFilled,
                        // 横向时功能条已含笔记/擦除 → 隐藏键盘底部功能行，避免重复键。
                        showFunctionRow: !landscape,
                      );
                      final Widget actionBar = ActionBar(
                        callbacks: _callbacks(controller),
                        canUndo: session.undoMoves.isNotEmpty,
                        canRedo: session.redoMoves.isNotEmpty,
                        noteMode: session.noteMode,
                        autoNotesFilled:
                            session.autoCandidates || session.autoNotesFilled,
                      );

                      // 桌面 → 横向布局（用户要求）：
                      // 左：数独棋盘；右：上=技巧讲解区，下=1-9 数字键盘 + 功能条。
                      if (landscape) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            // 左侧：棋盘（撑满可用区）。
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Center(child: board),
                              ),
                            ),
                            // 右侧列：上=技巧讲解 / 下=数字键盘+功能条。
                            SizedBox(
                              width: kDesktopGamePanelWidth,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  AppSpacing.md,
                                  AppSpacing.md,
                                  AppSpacing.md,
                                ),
                                child: Column(
                                  children: <Widget>[
                                    // 右上：技巧讲解（有提示显示讲解，无则占位引导）。
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 280),
                                        switchInCurve: Curves.easeOutCubic,
                                        transitionBuilder: _hintTransition,
                                        child: _hint == null
                                            ? const _HintPlaceholder(
                                                key: ValueKey<String>(
                                                  'hint-placeholder',
                                                ),
                                              )
                                            : SingleChildScrollView(
                                                key: ValueKey<String>(
                                                  'hint-${_hint!.sceneFingerprint}-${_hint!.level.order}',
                                                ),
                                                child: _HintCard(hint: _hint!),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    numpad,
                                    const SizedBox(height: AppSpacing.sm),
                                    actionBar,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      // 移动端 / 窄窗口 → 竖排（棋盘 + 提示卡 + 功能条 + 移动键盘）。
                      return Column(
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Center(child: board),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            transitionBuilder: _hintTransition,
                            child: _hint == null
                                ? const SizedBox.shrink()
                                : _HintCard(
                                    key: ValueKey<String>(
                                      'mobile-hint-${_hint!.sceneFingerprint}-${_hint!.level.order}',
                                    ),
                                    hint: _hint!,
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: actionBar,
                          ),
                          if (isMobile)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                0,
                                AppSpacing.md,
                                AppSpacing.sm,
                              ),
                              child: numpad,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            // 加载指示（>300ms 由 engineLoadingProvider 驱动）。
            const LoadingIndicator(),
            if (session.paused)
              PauseOverlay(
                elapsedMs: session.elapsedMs,
                onResume: _togglePause,
                onQuit: _quitGame,
              ),
          ],
        ),
      ),
    );
  }

  /// 输入回调聚合（与桌面快捷键/移动键盘同一语义）。
  GameInputCallbacks _callbacks(GameSessionController controller) =>
      GameInputCallbacks(
        onDigit: (int digit) {
          _runBoardAction(() => controller.inputDigit(digit));
        },
        onToggleNote: (int digit) {
          _runBoardAction(() => controller.toggleNote(digit));
        },
        onToggleNoteMode: controller.toggleNoteMode,
        onAutoNotes: () => _runBoardAction(controller.autoFillNotes),
        onClearCell: () => _runBoardAction(controller.clearCell),
        onUndo: () => _runBoardAction(controller.undo),
        onRedo: () => _runBoardAction(controller.redo),
        onRequestHint: _requestHint,
        onCheckAnswer: _checkAnswer,
        onPause: _togglePause,
        onMoveSelection: _moveSelection,
        onSelectCell: controller.selectCell,
      );

  static Widget _hintTransition(
    Widget child,
    Animation<double> animation,
  ) =>
      FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
}

/// 顶部计时徽标。
class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.session});

  final GameSession session;

  @override
  Widget build(BuildContext context) {
    final int ms = session.elapsedMs;
    final int totalSeconds = ms ~/ 1000;
    final String label = '${(totalSeconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(totalSeconds % 60).toString().padLeft(2, '0')}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// 提示占位引导（横向布局右上区无提示时显示）。
class _HintPlaceholder extends StatelessWidget {
  const _HintPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.lightbulb_outline,
            size: 40,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '点击「提示」查看技巧讲解',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 提示卡片（只展示讲解文案，无填数答案）。
class _HintCard extends StatelessWidget {
  const _HintCard({required this.hint, super.key});

  final HintState hint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SemanticColorStyle colors =
        GamePalette.hintLevelStyleOf(hint.level.order);
    return Card(
      color: colors.container,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.lightbulb_rounded,
                  color: colors.accent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${hint.level.zhName}提示',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${hint.level.order}/${HintRules.maxLevelOf(hint.scope)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              hint.narration,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
