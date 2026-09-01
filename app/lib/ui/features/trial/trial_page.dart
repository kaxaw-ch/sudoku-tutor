/// 验收试炼页（T-EDU-05 / P0-EDU-06/07，S-05、C-06）。
///
/// - **提示按钮置灰**并带说明「试炼关不可提示」；
/// - 顶部标明「本关需用到：XX 技巧」（来自题池标注 ∪ 关卡标签）；
/// - **系统不校验玩家是否使用目标技巧**，通关 = 完整解出整盘；
/// - 不限次数、不重置整关；**连续失败 3 次**弹出「回看本技巧原理演示」入口；
/// - 通关弹出结算卡（用时/错误次数 → `recordCompletion`）。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/game_session_controller.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/domain/teaching/trial_controller.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/board/board_view_model.dart';
import 'package:sudoku_tutor/ui/board/sudoku_board_view.dart';
import 'package:sudoku_tutor/ui/features/teaching/next_level_button.dart';
import 'package:sudoku_tutor/ui/input/action_bar.dart';
import 'package:sudoku_tutor/ui/input/desktop_shortcuts.dart';
import 'package:sudoku_tutor/ui/input/input_intents.dart';
import 'package:sudoku_tutor/ui/input/numpad_panel.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';
import 'package:sudoku_tutor/ui/widgets/loading_indicator.dart';

import 'result_sheet.dart';

/// 验收试炼页。
class TrialPage extends ConsumerStatefulWidget {
  /// 构造试炼页。
  const TrialPage({super.key});

  @override
  ConsumerState<TrialPage> createState() => _TrialPageState();
}

class _TrialPageState extends ConsumerState<TrialPage> {
  bool _disposed = false;
  GameSessionController? _ctrl;

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
        ref.read(trialControllerProvider.notifier).start(levelId);
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ctrl?.timer.pause();
    super.dispose();
  }

  // ------------------------------------------------------------ 交互

  /// 退出试炼关（放弃本局）→ 返回学习地图。
  void _handleExit() {
    _ctrl?.timer.pause();
    ref
        .read(gameSessionControllerProvider.notifier)
        .discardSession(clearSavedSnapshot: false);
    context.goNamed(RouteNames.home);
  }

  /// 离开当前试炼并进入下一关。
  Future<bool> _beforeNextLevel() async {
    _ctrl?.timer.pause();
    await ref
        .read(gameSessionControllerProvider.notifier)
        .discardSession(clearSavedSnapshot: false);
    return true;
  }

  /// 核对答案（只标错不纠正）。
  void _checkAnswer() {
    ref.read(trialControllerProvider.notifier).handleCheckAnswer();
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
    ref.read(trialControllerProvider.notifier).handleSelectCell(next);
  }

  static int _clamp(int v) => v < 0 ? 0 : (v > 8 ? 8 : v);

  /// 连续失败 3 次 → 回看原理演示入口。
  Future<void> _showReviewOffer(TrialState st) async {
    final String? demoId = st.reviewDemoLevelId;
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          context.l10n.text(
            '连续失败 {count} 次',
            const <String, Object?>{
              'count': kTrialFailuresBeforeReviewOffer,
            },
          ),
        ),
        content: Text(
          context.l10n.text(
            '要不要先回看一遍「{technique}」的原理演示，再回来挑战？',
            <String, Object?>{
              'technique': _targetTechniqueLabel(st),
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('continue'),
            child: Text(context.l10n.text('继续挑战')),
          ),
          if (demoId != null)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('review'),
              child: Text(context.l10n.text('回看原理演示')),
            ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    ref.read(trialControllerProvider.notifier).acknowledgeReviewOffer();
    if (action == 'review' && demoId != null) {
      context.goNamed(RouteNames.demo, pathParameters: <String, String>{
        'levelId': demoId,
      });
    }
  }

  /// 通关 → 结算卡。
  Future<void> _showResultSheet(TrialState st) async {
    final GameSession? session = ref.read(gameSessionControllerProvider);
    if (session == null) {
      return;
    }
    final String? nextId = await _findNextLevelId(st.level.id);
    final LevelKind? nextKind = nextId == null ? null : await _kindOf(nextId);
    if (!mounted) {
      return;
    }
    final String? action = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => TrialResultSheet(
        elapsedMs: session.elapsedMs,
        errorCount: st.errorCount,
        hasNext: nextId != null,
        onBackToMap: () => Navigator.of(ctx).pop('back'),
        onNextLevel: nextId == null
            ? null
            : () => Navigator.of(ctx).pop('next:$nextId:${nextKind?.id}'),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'back') {
      context.goNamed(RouteNames.home);
      return;
    }
    final List<String> parts = action.split(':');
    if (parts.length >= 3 && parts[0] == 'next') {
      _goToLevel(parts[1], LevelKind.tryParse(parts[2]) ?? LevelKind.demo);
    }
  }

  /// 全局顺序的下一关 id（无则 `null`）。
  Future<String?> _findNextLevelId(String levelId) async {
    final LevelIndex index = await ref.read(curriculumIndexProvider.future);
    final List<LevelEntry> entries = index.allLevels;
    final int pos = entries.indexWhere((LevelEntry e) => e.id == levelId);
    if (pos < 0 || pos + 1 >= entries.length) {
      return null;
    }
    return entries[pos + 1].id;
  }

  Future<LevelKind?> _kindOf(String levelId) async {
    final LevelIndex index = await ref.read(curriculumIndexProvider.future);
    return index.byId(levelId)?.kind;
  }

  /// 按关卡类型跳转对应教学页面。
  void _goToLevel(String levelId, LevelKind kind) {
    final String name = switch (kind) {
      LevelKind.demo => RouteNames.demo,
      LevelKind.guidedPractice => RouteNames.practiceLevel,
      LevelKind.trial => RouteNames.trial,
    };
    context.goNamed(name, pathParameters: <String, String>{
      'levelId': levelId,
    });
  }

  // ------------------------------------------------------------ 渲染

  @override
  Widget build(BuildContext context) {
    ref.listen<TrialState?>(
      trialControllerProvider,
      (TrialState? prev, TrialState? next) {
        if (next == null) {
          return;
        }
        if (next.completed && prev?.completed != true) {
          _showResultSheet(next);
        } else if (next.showReviewOffer && prev?.showReviewOffer != true) {
          _showReviewOffer(next);
        }
      },
    );

    final TrialState? trialState = ref.watch(trialControllerProvider);
    final GameSession? session = ref.watch(gameSessionControllerProvider);
    if (trialState == null || session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.text('验收试炼'))),
        body: const LoadingIndicator(),
      );
    }

    final TrialController controller =
        ref.read(trialControllerProvider.notifier);
    final GameSessionController gameCtrl =
        ref.read(gameSessionControllerProvider.notifier);
    _ctrl = gameCtrl; // 供 dispose() 停表。
    final BoardViewModel viewModel = BoardViewModel.fromSession(session);
    final bool isMobile =
        Theme.of(context).platform == TargetPlatform.android ||
            Theme.of(context).platform == TargetPlatform.iOS;

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
            context.l10n.lessonTitle(
              trialState.level.id,
              trialState.level.title,
            ),
          ),
          actions: <Widget>[
            NextLevelButton(
              currentLevelId: trialState.level.id,
              beforeNavigate: _beforeNextLevel,
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Chip(
                  label: Text(
                    context.l10n.text(
                      '本关需用到：{technique}',
                      <String, Object?>{
                        'technique': _targetTechniqueLabel(trialState),
                      },
                    ),
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
                  // 提示置灰说明（ActionBar 的提示按钮 onRequestHint=null 已置灰）。
                  final Widget notice = Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm + 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.lock_outline),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              context.l10n.text(
                                '试炼关不提供提示：请自主识别并运用目标技巧解完整盘。',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  // 桌面 → 恒横向（与自由练习一致）；移动端/窄窗保持竖排。
                  final bool landscape = !isMobile;
                  final Widget board = ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: landscape
                          ? math.max(
                              320,
                              math.min(
                                constraints.maxHeight - AppSpacing.md * 2,
                                constraints.maxWidth -
                                    kDesktopGamePanelWidth -
                                    AppSpacing.md * 2,
                              ),
                            )
                          : 520,
                      maxHeight: landscape
                          ? math.max(
                              320,
                              math.min(
                                constraints.maxHeight - AppSpacing.md * 2,
                                constraints.maxWidth -
                                    kDesktopGamePanelWidth -
                                    AppSpacing.md * 2,
                              ),
                            )
                          : 520,
                    ),
                    child: SudokuBoardView(
                      viewModel: viewModel,
                      onCellTap: controller.handleSelectCell,
                      onCellLongPress: (int index) {
                        controller.handleSelectCell(index);
                        gameCtrl.toggleNoteMode();
                      },
                    ),
                  );
                  final Widget numpad = NumpadPanel(
                    callbacks: _callbacks(controller),
                    digitCounts: session.digitCounts(),
                    noteMode: session.noteMode,
                    autoNotesFilled:
                        session.autoCandidates || session.autoNotesFilled,
                    // 横向时功能条已含笔记/擦除 → 隐藏键盘底部功能行。
                    showFunctionRow: !landscape,
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

                  // 桌面 → 横向布局：左棋盘 / 右上说明 / 右下 1-9 键盘 + 功能条。
                  if (landscape) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Center(child: board),
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
                                // 右上：提示置灰说明（可滚动）。
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: notice,
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

                  // 移动端/窄窗 → 竖排。
                  return Column(
                    children: <Widget>[
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Center(child: board),
                        ),
                      ),
                      notice,
                      actionBar,
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
      ),
    );
  }

  /// 输入回调聚合（提示按钮 onRequestHint=null → 置灰）。
  GameInputCallbacks _callbacks(TrialController controller) =>
      GameInputCallbacks(
        onDigit: controller.handleDigit,
        onToggleNote: controller.handleToggleNote,
        onToggleNoteMode: () =>
            ref.read(gameSessionControllerProvider.notifier).toggleNoteMode(),
        onAutoNotes: () =>
            ref.read(gameSessionControllerProvider.notifier).autoFillNotes(),
        onClearCell: controller.handleClear,
        onUndo: controller.handleUndo,
        onRedo: controller.handleRedo,
        onRequestHint: null, // 试炼关提示置灰。
        onCheckAnswer: _checkAnswer,
        onPause: _handleExit,
        onMoveSelection: _moveSelection,
        onSelectCell: controller.handleSelectCell,
      );

  String _targetTechniqueLabel(TrialState state) => state.targetTechniques
      .map(context.l10n.techniqueName)
      .join(context.l10n.isEnglish ? ', ' : '、');
}
