/// 引导实操页（T-EDU-03 / P0-EDU-04，S-04）+ 误操作即时纠正（T-EDU-04）。
///
/// - 棋盘可自由填数/标记（复用 T-UI-03 输入层：键盘 + 快捷键 + 功能条）；
/// - 提示逐级解锁（一级→二级→三级，次数不限、不扣分），面板保留历史可回看；
/// - 每次输入经 [PracticeController] 挂接 [MistakeDetector]，
///   命中即弹「这一步有问题」纠正弹窗（同一错误 2 分钟内不重复弹）；
/// - 盘面变化自动保存；退出重进恢复当前盘面，但不恢复撤销/重做过程；
/// - 整盘解出 → 自动写档（hintUsed=提示次数、errorCount=误操作次数）。
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/hint/hint_providers.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_detector.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_message_repository.dart';
import 'package:sudoku_tutor/domain/teaching/practice_controller.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/game_session_controller.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/teaching/next_level_button.dart';
import 'package:sudoku_tutor/ui/input/action_bar.dart';
import 'package:sudoku_tutor/ui/input/desktop_shortcuts.dart';
import 'package:sudoku_tutor/ui/input/input_intents.dart';
import 'package:sudoku_tutor/ui/input/numpad_panel.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';
import 'package:sudoku_tutor/ui/widgets/congratulations_animation.dart';
import 'package:sudoku_tutor/ui/widgets/loading_indicator.dart';

import 'hint_panel.dart';
import 'mistake_dialog.dart';

/// 实操页"紧凑模式"阈值（px）：可用高度低于该值 →
/// 整页滚动 + 棋盘固定高度（横屏/小窗/测试小屏），
/// 避免棋盘被数字键盘+提示面板挤成 0 高度导致渲染崩溃。
const double kPracticePageCrampedHeight = 620;

/// 引导实操页。
class PracticeLevelPage extends ConsumerStatefulWidget {
  /// 构造实操页。
  const PracticeLevelPage({required this.levelId, super.key});

  /// 当前路由指定的关卡 id。
  final String levelId;

  @override
  ConsumerState<PracticeLevelPage> createState() => _PracticeLevelPageState();
}

class _PracticeLevelPageState extends ConsumerState<PracticeLevelPage>
    with WidgetsBindingObserver {
  HintState? _displayedHint;
  bool _hintHighlightActive = false;
  String? _handledMistakeFp;
  bool _disposed = false;
  GameSessionController? _ctrl;
  PracticeController? _practiceCtrl;
  bool _completionCelebrated = false;
  String? _requestedLevelId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleStart(widget.levelId);
  }

  @override
  void didUpdateWidget(covariant PracticeLevelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levelId == widget.levelId) {
      return;
    }
    _displayedHint = null;
    _hintHighlightActive = false;
    _handledMistakeFp = null;
    _completionCelebrated = false;
    _scheduleStart(widget.levelId);
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
      ref.read(practiceControllerProvider.notifier).start(levelId);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ctrl?.timer.pause();
    final PracticeController? practiceCtrl = _practiceCtrl;
    if (practiceCtrl != null) {
      unawaited(practiceCtrl.saveNow());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      final PracticeController? practiceCtrl = _practiceCtrl;
      if (practiceCtrl != null) {
        unawaited(practiceCtrl.saveNow());
      }
    }
  }

  // ------------------------------------------------------------ 交互

  /// 请求下一级提示。
  Future<void> _requestHint() async {
    final HintState? hint =
        await ref.read(practiceControllerProvider.notifier).requestHint();
    if (!mounted) {
      return;
    }
    if (hint == null) {
      final HintService service = ref.read(hintServiceProvider);
      _showMessage(context.l10n.hintUnavailable(service.lastUnavailableReason));
      return;
    }
    setState(() {
      _displayedHint = hint;
      _hintHighlightActive = true;
    });
  }

  /// 用户执行盘面操作后关闭提示高亮，但保留提示卡片与历史。
  void _consumeHintHighlight() {
    if (!_hintHighlightActive || !mounted) {
      return;
    }
    setState(() => _hintHighlightActive = false);
  }

  /// 执行输入，并且只在盘面内容实际变化后收起提示高亮。
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

  /// 误操作弹窗（由 `lastMistake` 驱动，2 分钟去重已在检测器完成）。
  Future<void> _showMistakeDialog(MistakeEvent event) async {
    final MistakeMessageRepository repo =
        ref.read(mistakeMessageRepositoryProvider);
    await repo.load();
    if (!mounted) {
      return;
    }
    final MistakeMessage message = context.l10n.mistakeMessage(
      event,
      repo.messageFor(event),
    );
    await MistakeDialog.show(context, message);
    if (mounted) {
      ref.read(practiceControllerProvider.notifier).acknowledgeMistake();
    }
  }

  /// 核对答案（只标错不纠正）。
  void _checkAnswer() {
    ref.read(practiceControllerProvider.notifier).handleCheckAnswer();
  }

  /// 保存当前教学盘面后返回学习地图。
  Future<void> _handleExit() async {
    final PracticeController controller =
        ref.read(practiceControllerProvider.notifier);
    _ctrl?.timer.pause();
    try {
      await controller.saveNow();
      await ref
          .read(gameSessionControllerProvider.notifier)
          .discardSession(clearSavedSnapshot: false);
    } on Object {
      if (mounted) {
        _showMessage(context.l10n.text('教学进度保存失败，请重试'));
      }
      return;
    }
    if (mounted) {
      context.goNamed(RouteNames.home);
    }
  }

  /// 下一关跳转前强制保存当前盘面并释放本关运行时。
  Future<bool> _beforeNextLevel() async {
    final PracticeController controller =
        ref.read(practiceControllerProvider.notifier);
    _ctrl?.timer.pause();
    try {
      await controller.saveNow();
      await ref
          .read(gameSessionControllerProvider.notifier)
          .discardSession(clearSavedSnapshot: false);
      return true;
    } on Object {
      if (mounted) {
        _showMessage(context.l10n.text('教学进度保存失败，请重试'));
      }
      return false;
    }
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
    ref.read(practiceControllerProvider.notifier).handleSelectCell(next);
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
    // 监听误操作事件（弹窗）。
    ref.listen<PracticeState?>(
      practiceControllerProvider,
      (PracticeState? prev, PracticeState? next) {
        final MistakeEvent? event = next?.lastMistake;
        if (event != null && event.fingerprint != _handledMistakeFp) {
          _handledMistakeFp = event.fingerprint;
          _showMistakeDialog(event);
        }
        if (next?.completed == true &&
            prev?.completed != true &&
            !_completionCelebrated) {
          _completionCelebrated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _disposed) {
              return;
            }
            unawaited(
              CongratulationsAnimation.show(
                context,
                title: context.l10n.text('恭喜通关！'),
                message: context.l10n.text('自动核验通过，本关盘面全部正确。'),
              ),
            );
          });
        }
      },
    );

    final PracticeState? practiceState = ref.watch(practiceControllerProvider);
    final GameSession? session = ref.watch(gameSessionControllerProvider);
    if (practiceState == null || session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.text('引导实操'))),
        body: const LoadingIndicator(),
      );
    }

    final PracticeController controller =
        ref.read(practiceControllerProvider.notifier);
    final GameSessionController gameCtrl =
        ref.read(gameSessionControllerProvider.notifier);
    _ctrl = gameCtrl; // 供 dispose() 停表。
    _practiceCtrl = controller;
    final BoardViewModel viewModel = BoardViewModel.fromSession(
      session,
      hintVisual: _hintHighlightActive ? _displayedHint?.visual : null,
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
        unawaited(_handleExit());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.l10n.text('返回'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => unawaited(_handleExit()),
          ),
          title: Text(
            context.l10n.lessonTitle(
              practiceState.level.id,
              practiceState.level.title,
            ),
          ),
          actions: <Widget>[
            NextLevelButton(
              currentLevelId: practiceState.level.id,
              beforeNavigate: _beforeNextLevel,
            ),
            if (practiceState.resumed)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Tooltip(
                  message: context.l10n.text('已恢复上次保存的盘面'),
                  child: const Icon(Icons.cloud_done_outlined),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Chip(
                  label: Text(
                    practiceState.level.techniqueTags
                        .map(context.l10n.techniqueName)
                        .join(context.l10n.isEnglish ? ', ' : '、'),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        body: DesktopShortcuts(
          callbacks: _callbacks(controller),
          child: GestureDetector(
            key: const ValueKey<String>('game-background'),
            behavior: HitTestBehavior.opaque,
            onTap: () => gameCtrl.selectCell(null),
            child: Focus(
              autofocus: true,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final Widget hintPanel = HintPanel(
                    unlockedHints: practiceState.unlockedHints,
                    displayedHint: _displayedHint,
                    onSelect: (HintState hint) => setState(() {
                      _displayedHint = hint;
                      _hintHighlightActive = true;
                    }),
                  );
                  final Widget actionBar = Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: ActionBar(
                      callbacks: _callbacks(controller),
                      canUndo: session.undoMoves.isNotEmpty,
                      canRedo: session.redoMoves.isNotEmpty,
                      noteMode: session.noteMode,
                      autoNotesFilled:
                          session.autoCandidates || session.autoNotesFilled,
                    ),
                  );
                  // 桌面 → 恒横向（与自由练习一致）；移动端/窄窗保持竖排。
                  final bool landscape = !isMobile;
                  final Widget numpad = NumpadPanel(
                    callbacks: _callbacks(controller),
                    digitCounts: session.digitCounts(),
                    noteMode: session.noteMode,
                    autoNotesFilled:
                        session.autoCandidates || session.autoNotesFilled,
                    // 横向时功能条已含笔记/擦除 → 隐藏键盘底部功能行。
                    showFunctionRow: !landscape,
                  );
                  final Widget board = SudokuBoardView(
                    viewModel: viewModel,
                    onCellTap: controller.handleSelectCell,
                    onCellLongPress: (int index) {
                      controller.handleSelectCell(index);
                      controller.handleToggleNoteMode();
                    },
                  );

                  // 桌面 → 横向布局：左棋盘 / 右上提示面板 / 右下 1-9 键盘 + 功能条。
                  if (landscape) {
                    final double boardSide = math.max(
                      320,
                      math.min(
                        constraints.maxHeight - AppSpacing.md * 2,
                        constraints.maxWidth -
                            kDesktopGamePanelWidth -
                            AppSpacing.md * 2,
                      ),
                    );
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: boardSide,
                                  maxHeight: boardSide,
                                ),
                                child: board,
                              ),
                            ),
                          ),
                        ),
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
                                // 右上：三级提示面板（可滚动）。
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: hintPanel,
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

                  // 高度足够 → 棋盘 Expanded 自适应（大屏撑满）。
                  if (constraints.maxHeight >= kPracticePageCrampedHeight) {
                    return Column(
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
                                child: board,
                              ),
                            ),
                          ),
                        ),
                        hintPanel,
                        actionBar,
                        if (isMobile) numpad,
                      ],
                    );
                  }
                  // 高度不足（横屏/小窗/测试小屏）→ 整页滚动，棋盘固定合理大小。
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 520,
                                maxHeight: 320,
                              ),
                              child: board,
                            ),
                          ),
                        ),
                        hintPanel,
                        actionBar,
                        if (isMobile) numpad,
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 输入回调聚合（与桌面快捷键/移动键盘同一语义，全部经实操控制器）。
  GameInputCallbacks _callbacks(PracticeController controller) =>
      GameInputCallbacks(
        onDigit: (int digit) {
          _runBoardAction(() => controller.handleDigit(digit));
        },
        onToggleNote: (int digit) {
          _runBoardAction(() => controller.handleToggleNote(digit));
        },
        onToggleNoteMode: controller.handleToggleNoteMode,
        onAutoNotes: () => _runBoardAction(controller.handleAutoNotes),
        onClearCell: () => _runBoardAction(controller.handleClear),
        onUndo: () => _runBoardAction(controller.handleUndo),
        onRedo: () => _runBoardAction(controller.handleRedo),
        onRequestHint: _requestHint,
        onCheckAnswer: _checkAnswer,
        onPause: () => unawaited(_handleExit()),
        onMoveSelection: _moveSelection,
        onSelectCell: controller.handleSelectCell,
      );
}
