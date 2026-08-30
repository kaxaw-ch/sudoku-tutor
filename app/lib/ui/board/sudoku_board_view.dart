/// 棋盘容器 `SudokuBoardView`（P0-UI-02，T-UI-07 叠加教学图层）。
///
/// 职责：**只做渲染与手势转发**——
/// - 把 [BoardViewModel] 交给 [BoardPainter] 哑渲染；
/// - 点击/长按格子的坐标换算（[BoardGeometry.indexAt]）后回调
///   [onCellTap] / [onCellLongPress]，业务处理归 UI 页面层；
/// - 错误抖动动画（[ErrorShakeController] 信号驱动）；
/// - **教学图层**（T-UI-07）：当 `viewModel.teachingOverlay` 非空时，
///   在其上叠加 [TeachingOverlayPainter]，并按教学动效控制器驱动
///   高亮渐变 / 连线生长 / 候选划除 / 虚线流动。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';

import 'animations/candidate_strike.dart';
import 'animations/error_shake.dart';
import 'animations/highlight_fade.dart';
import 'animations/link_grow.dart';
import 'board_geometry.dart';
import 'board_painter.dart';
import 'board_view_model.dart';
import 'teaching_overlay_painter.dart';

/// 棋盘视图。
///
/// 最小可渲染边长（px）：低于该值视为"无空间"（极小窗口/布局被压缩），
/// 渲染为空占位，避免几何负值导致绘制崩溃。
const double kMinBoardSide = 48;

/// 棋盘视图。
class SudokuBoardView extends StatefulWidget {
  /// 构造棋盘视图。
  const SudokuBoardView({
    required this.viewModel,
    this.onCellTap,
    this.onCellLongPress,
    this.shakeController,
    super.key,
  });

  /// 渲染数据（纯数据，Painter 消费）。
  final BoardViewModel viewModel;

  /// 点击格子回调（携带格索引 0..80）。
  final ValueChanged<int>? onCellTap;

  /// 长按格子回调（辅助：长按标记候选）。
  final ValueChanged<int>? onCellLongPress;

  /// 错误抖动控制器（`null` = 不抖动）。
  final ErrorShakeController? shakeController;

  @override
  State<SudokuBoardView> createState() => _SudokuBoardViewState();
}

class _SudokuBoardViewState extends State<SudokuBoardView>
    with TickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  /// 选中格轻量脉冲，帮助用户确认键盘/鼠标焦点移动到了哪一格。
  late final AnimationController _selectionPulse;

  /// 教学图层：高亮渐变控制器（T-UI-07）。
  late final HighlightFadeController _highlightFade;

  /// 教学图层：连线生长控制器（T-UI-07）。
  late final LinkGrowController _linkGrow;

  /// 教学图层：候选划除控制器（T-UI-07）。
  late final CandidateStrikeController _candidateStrike;

  /// 教学图层：虚线流动控制器（周期循环，T-UI-07）。
  late final AnimationController _dashFlow;

  int _lastSignal = 0;

  /// 合并后的动画监听（缓存，避免每次 build 新建 Listenable.merge 泄漏监听）。
  late final Listenable _animations;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation = _shakeController.drive(
      Tween<double>(begin: 0, end: 1).chain(CurveTween(curve: Curves.easeOut)),
    );
    _lastSignal = widget.shakeController?.value ?? 0;
    widget.shakeController?.addListener(_onShakeSignal);
    _selectionPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );

    // 教学动效控制器（vsync 用本 State）。
    _highlightFade = HighlightFadeController(vsync: this);
    _linkGrow = LinkGrowController(vsync: this);
    _candidateStrike = CandidateStrikeController(vsync: this);
    _dashFlow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animations = Listenable.merge(<Listenable>[
      _shakeAnimation,
      _selectionPulse,
      _highlightFade.listenable,
      _linkGrow.listenable,
      _candidateStrike.listenable,
      _dashFlow,
    ]);
    // 首次挂载即携带教学图层 → 直接播放进入动画。
    if (widget.viewModel.teachingOverlay != null) {
      _triggerOverlayAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant SudokuBoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shakeController != widget.shakeController) {
      oldWidget.shakeController?.removeListener(_onShakeSignal);
      widget.shakeController?.addListener(_onShakeSignal);
      _lastSignal = widget.shakeController?.value ?? 0;
    }
    if (oldWidget.viewModel.selectedIndex != widget.viewModel.selectedIndex) {
      if (widget.viewModel.selectedIndex == null) {
        _selectionPulse.value = 1;
      } else {
        _selectionPulse.forward(from: 0);
      }
    }
    // 教学图层数据变化 → 重播动画（渐变进入 / 连线生长 / 划除）。
    final VisualHint? oldOverlay = oldWidget.viewModel.teachingOverlay;
    final VisualHint? newOverlay = widget.viewModel.teachingOverlay;
    if (oldOverlay != newOverlay) {
      if (newOverlay != null) {
        _triggerOverlayAnimation();
      } else {
        // 图层消失：停止流动虚线，复位动画。
        _dashFlow.stop();
        _dashFlow.value = 0;
        _highlightFade.complete();
        _linkGrow.complete();
        _candidateStrike.complete();
      }
    }
  }

  /// 触发教学图层进入动画（高亮渐入 + 连线生长 + 划除 + 虚线流动）。
  void _triggerOverlayAnimation() {
    _highlightFade.fadeIn();
    _linkGrow.forward();
    _candidateStrike.forward();
    final VisualHint overlay = widget.viewModel.teachingOverlay!;
    final bool anyAnimatedRegion = overlay.regions.any(
      (RegionMark r) => r.animated,
    );
    if (anyAnimatedRegion) {
      _dashFlow.repeat();
    } else {
      _dashFlow.stop();
      _dashFlow.value = 0;
    }
  }

  @override
  void dispose() {
    widget.shakeController?.removeListener(_onShakeSignal);
    _shakeController.dispose();
    _selectionPulse.dispose();
    _highlightFade.dispose();
    _linkGrow.dispose();
    _candidateStrike.dispose();
    _dashFlow.dispose();
    super.dispose();
  }

  /// 抖动信号变化 → 播放动画。
  void _onShakeSignal() {
    final int signal = widget.shakeController?.value ?? 0;
    if (signal != _lastSignal) {
      _lastSignal = signal;
      _shakeController.forward(from: 0);
    }
  }

  /// 当前教学图层动画进度（纯数值，painter 消费）。
  TeachingOverlayProgress get _overlayProgress => TeachingOverlayProgress(
        highlightOpacity: _highlightFade.opacity,
        linkGrow: _linkGrow.progress,
        strike: _candidateStrike.progress,
        dashOffset: _dashFlow.value * 12,
      );

  @override
  Widget build(BuildContext context) {
    final BoardPalette palette =
        Theme.of(context).extension<BoardPalette>() ?? GamePalette.greenBoard;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double side =
            math.min(constraints.maxWidth, constraints.maxHeight);
        // 防御：棋盘可用区过小（布局被压缩/极小窗口）时不绘制，
        // 避免 BoardGeometry 产生负几何、字号为负等渲染崩溃。
        if (side < kMinBoardSide) {
          return const SizedBox.shrink();
        }
        final BoardGeometry geometry = BoardGeometry(
          size: Size(side, side),
          padding: 12,
        );
        final VisualHint? overlay = widget.viewModel.teachingOverlay;
        return AnimatedBuilder(
          animation: _animations,
          builder: (BuildContext context, Widget? child) {
            // 抖动位移：衰减正弦，~3 个周期。
            final double t = _shakeController.value;
            final double offset = math.sin(t * math.pi * 6) * 7 * (1 - t);
            final double rawPulse = math.sin(_selectionPulse.value * math.pi);
            final double selectionPulse = rawPulse.abs() < 0.001 ? 0 : rawPulse;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) {
                final int? index = geometry.indexAt(details.localPosition);
                if (index != null) {
                  widget.onCellTap?.call(index);
                }
              },
              onLongPressStart: (LongPressStartDetails details) {
                final int? index = geometry.indexAt(details.localPosition);
                if (index != null) {
                  widget.onCellLongPress?.call(index);
                }
              },
              child: CustomPaint(
                size: Size(side, side),
                painter: BoardPainter(
                  geometry: geometry,
                  viewModel: widget.viewModel,
                  palette: palette,
                  shakeOffset: offset,
                  selectionPulse: selectionPulse,
                ),
                // 教学图层叠加上层（数据全来自 viewModel，哑渲染）。
                foregroundPainter: overlay == null
                    ? null
                    : TeachingOverlayPainter(
                        geometry: geometry,
                        visual: overlay,
                        progress: _overlayProgress,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
