/// 做题交互的语义调色板。
///
/// 棋盘采用暖白 + 鼠尾草绿 + 青绿色的低饱和层级；提示仍保留颜色、文字和
/// 教学形状等多通道信息，不能只靠颜色传达含义。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

/// 一组可用于按钮、卡片和标签的前景/容器/描边颜色。
@immutable
class SemanticColorStyle {
  /// 构造语义色样式。
  const SemanticColorStyle({
    required this.accent,
    required this.container,
    required this.border,
  });

  /// 强调色；用于图标、文字或激活态背景。
  final Color accent;

  /// 浅色容器背景。
  final Color container;

  /// 容器描边。
  final Color border;
}

/// 棋盘各视觉状态的完整配色，也是挂载到 [ThemeData] 的主题扩展。
@immutable
class BoardPalette extends ThemeExtension<BoardPalette> {
  /// 构造棋盘配色。
  const BoardPalette({
    required this.boardBackground,
    required this.selection,
    required this.selectionFill,
    required this.selectionPulseFill,
    required this.peerFill,
    required this.sameDigit,
    required this.sameDigitFill,
    required this.givenDigit,
    required this.playerDigit,
    required this.candidate,
    required this.cellGridLine,
    required this.boxGridLine,
    required this.outerGridLine,
    required this.candidateGridLine,
  });

  /// 棋盘底色。
  final Color boardBackground;

  /// 当前选中格描边。
  final Color selection;

  /// 当前选中格背景。
  final Color selectionFill;

  /// 当前格脉冲动画背景。
  final Color selectionPulseFill;

  /// 同行、同列、同宫的弱关联背景。
  final Color peerFill;

  /// 与选中格相同数字的文字颜色。
  final Color sameDigit;

  /// 与选中格相同数字的背景。
  final Color sameDigitFill;

  /// 给定数字颜色。
  final Color givenDigit;

  /// 玩家填写数字颜色。
  final Color playerDigit;

  /// 普通候选数字颜色。
  final Color candidate;

  /// 普通单元格细网格。
  final Color cellGridLine;

  /// 九宫格分隔线。
  final Color boxGridLine;

  /// 棋盘外框。
  final Color outerGridLine;

  /// 候选数 3×3 微网格。
  final Color candidateGridLine;

  @override
  BoardPalette copyWith({
    Color? boardBackground,
    Color? selection,
    Color? selectionFill,
    Color? selectionPulseFill,
    Color? peerFill,
    Color? sameDigit,
    Color? sameDigitFill,
    Color? givenDigit,
    Color? playerDigit,
    Color? candidate,
    Color? cellGridLine,
    Color? boxGridLine,
    Color? outerGridLine,
    Color? candidateGridLine,
  }) =>
      BoardPalette(
        boardBackground: boardBackground ?? this.boardBackground,
        selection: selection ?? this.selection,
        selectionFill: selectionFill ?? this.selectionFill,
        selectionPulseFill: selectionPulseFill ?? this.selectionPulseFill,
        peerFill: peerFill ?? this.peerFill,
        sameDigit: sameDigit ?? this.sameDigit,
        sameDigitFill: sameDigitFill ?? this.sameDigitFill,
        givenDigit: givenDigit ?? this.givenDigit,
        playerDigit: playerDigit ?? this.playerDigit,
        candidate: candidate ?? this.candidate,
        cellGridLine: cellGridLine ?? this.cellGridLine,
        boxGridLine: boxGridLine ?? this.boxGridLine,
        outerGridLine: outerGridLine ?? this.outerGridLine,
        candidateGridLine: candidateGridLine ?? this.candidateGridLine,
      );

  @override
  BoardPalette lerp(covariant BoardPalette? other, double t) {
    if (other == null) {
      return this;
    }
    return BoardPalette(
      boardBackground: Color.lerp(boardBackground, other.boardBackground, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      selectionFill: Color.lerp(selectionFill, other.selectionFill, t)!,
      selectionPulseFill:
          Color.lerp(selectionPulseFill, other.selectionPulseFill, t)!,
      peerFill: Color.lerp(peerFill, other.peerFill, t)!,
      sameDigit: Color.lerp(sameDigit, other.sameDigit, t)!,
      sameDigitFill: Color.lerp(sameDigitFill, other.sameDigitFill, t)!,
      givenDigit: Color.lerp(givenDigit, other.givenDigit, t)!,
      playerDigit: Color.lerp(playerDigit, other.playerDigit, t)!,
      candidate: Color.lerp(candidate, other.candidate, t)!,
      cellGridLine: Color.lerp(cellGridLine, other.cellGridLine, t)!,
      boxGridLine: Color.lerp(boxGridLine, other.boxGridLine, t)!,
      outerGridLine: Color.lerp(outerGridLine, other.outerGridLine, t)!,
      candidateGridLine:
          Color.lerp(candidateGridLine, other.candidateGridLine, t)!,
    );
  }
}

/// 做题页语义颜色的唯一事实源。
abstract final class GamePalette {
  // ------------------------------------------------------------ 棋盘状态

  /// 经典蓝色棋盘（恢复绿色改版前的蓝色视觉层级）。
  static const BoardPalette blueBoard = BoardPalette(
    boardBackground: Color(0xFFFFFFFF),
    selection: Color(0xFF172554),
    selectionFill: Color(0xFF1D4ED8),
    selectionPulseFill: Color(0xFF2563EB),
    peerFill: Color(0xFFF1F5F9),
    sameDigit: Color(0xFF1E40AF),
    sameDigitFill: Color(0xFFDBEAFE),
    givenDigit: Color(0xFF202124),
    playerDigit: Color(0xFF3F51B5),
    candidate: Color(0xFF475569),
    cellGridLine: Color(0xFFB7BDC6),
    boxGridLine: Color(0xFF3C4043),
    outerGridLine: Color(0xFF202124),
    candidateGridLine: Color(0xFFE8EAED),
  );

  /// 清新绿色棋盘（暖白 + 鼠尾草绿 + 青绿色）。
  static const BoardPalette greenBoard = BoardPalette(
    boardBackground: Color(0xFFFFFDF1),
    selection: Color(0xFF234E47),
    selectionFill: Color(0xFF347B70),
    selectionPulseFill: Color(0xFF438F83),
    peerFill: Color(0xFFE8F1D8),
    sameDigit: Color(0xFF245A52),
    sameDigitFill: Color(0xFF9CCFC5),
    givenDigit: Color(0xFF35423D),
    playerDigit: Color(0xFF2D675D),
    candidate: Color(0xFF53645D),
    cellGridLine: Color(0xFFC8CEC3),
    boxGridLine: Color(0xFF48584F),
    outerGridLine: Color(0xFF34463E),
    candidateGridLine: Color(0xFFE3E7DC),
  );

  /// 将存档中的棋盘主题映射为完整配色。
  static BoardPalette boardOf(BoardThemeStyle style) => switch (style) {
        BoardThemeStyle.blue => blueBoard,
        BoardThemeStyle.green => greenBoard,
      };

  /// 错误填写或待删除候选：红。
  static const Color error = Color(0xFFDC2626);

  /// 三级提示依次使用黄、紫、红，帮助区分“方向/定位/结论”。
  static SemanticColorStyle hintLevelStyleOf(int order) => switch (order) {
        1 => const SemanticColorStyle(
            accent: Color(0xFFA16207),
            container: Color(0xFFFEF3C7),
            border: Color(0xFFFDE68A),
          ),
        2 => const SemanticColorStyle(
            accent: Color(0xFF7E22CE),
            container: Color(0xFFF3E8FF),
            border: Color(0xFFE9D5FF),
          ),
        _ => const SemanticColorStyle(
            accent: Color(0xFFBE123C),
            container: Color(0xFFFFE4E6),
            border: Color(0xFFFECDD3),
          ),
      };
}
