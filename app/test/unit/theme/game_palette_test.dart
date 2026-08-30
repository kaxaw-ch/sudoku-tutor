/// 做题页语义配色测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';

double _contrastRatio(Color a, Color b) {
  final double lighter = a.computeLuminance() > b.computeLuminance()
      ? a.computeLuminance()
      : b.computeLuminance();
  final double darker = a.computeLuminance() > b.computeLuminance()
      ? b.computeLuminance()
      : a.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('绿色棋盘：暖白底、深绿当前格、青绿相同数字、浅绿关联区域', () {
    const BoardPalette palette = GamePalette.greenBoard;
    expect(palette.boardBackground, const Color(0xFFFFFDF1));
    expect(palette.selectionFill, const Color(0xFF347B70));
    expect(palette.sameDigitFill, const Color(0xFF9CCFC5));
    expect(palette.peerFill, const Color(0xFFE8F1D8));
    expect(palette.selectionFill, isNot(palette.sameDigitFill));
    expect(palette.sameDigitFill, isNot(palette.peerFill));
    expect(
      _contrastRatio(palette.selectionFill, Colors.white),
      greaterThanOrEqualTo(4.5),
      reason: '深绿色选中格上的白色数字必须清晰可读',
    );
  });

  test('蓝色棋盘：恢复白底、深蓝当前格、浅蓝相同数字', () {
    const BoardPalette palette = GamePalette.blueBoard;
    expect(palette.boardBackground, Colors.white);
    expect(palette.selectionFill, const Color(0xFF1D4ED8));
    expect(palette.sameDigitFill, const Color(0xFFDBEAFE));
    expect(palette.peerFill, const Color(0xFFF1F5F9));
    expect(palette.selectionFill, isNot(palette.sameDigitFill));
    expect(palette.sameDigitFill, isNot(palette.peerFill));
    expect(
      _contrastRatio(palette.selectionFill, Colors.white),
      greaterThanOrEqualTo(4.5),
      reason: '深蓝色选中格上的白色数字必须清晰可读',
    );
  });

  test('两套棋盘格线都分三级且颜色互不相同', () {
    for (final BoardPalette palette in <BoardPalette>[
      GamePalette.blueBoard,
      GamePalette.greenBoard,
    ]) {
      expect(
        <Color>{
          palette.cellGridLine,
          palette.boxGridLine,
          palette.outerGridLine,
        },
        hasLength(3),
      );
    }
  });

  test('主题枚举映射并挂载到 ThemeData', () {
    expect(
      GamePalette.boardOf(BoardThemeStyle.blue),
      same(GamePalette.blueBoard),
    );
    expect(
      GamePalette.boardOf(BoardThemeStyle.green),
      same(GamePalette.greenBoard),
    );
    expect(
      AppTheme.light(boardTheme: BoardThemeStyle.blue)
          .extension<BoardPalette>(),
      same(GamePalette.blueBoard),
    );
  });

  test('三级提示分别使用黄、紫、红三套颜色', () {
    final List<Color> accents = <Color>[
      for (int order = 1; order <= 3; order++)
        GamePalette.hintLevelStyleOf(order).accent,
    ];
    expect(accents.toSet(), hasLength(3));
    for (final Color accent in accents) {
      expect(_contrastRatio(accent, Colors.white), greaterThanOrEqualTo(4.5));
    }
  });
}
