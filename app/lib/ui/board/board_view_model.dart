/// 棋盘渲染数据装配 `BoardViewModel` —— Painter 的唯一输入（P0-UI-02）。
///
/// 纯数据 + 派生计算：**UI 只消费不计算**（架构 §4）。
/// - 选中格 + 同行/列/宫弱高亮；
/// - 相同数字高亮**两级**（已填强高亮实底 / 候选弱高亮加粗着色，P0-PRA-07）；
/// - 错误标红格集合（只描边不填底的渲染口径在 Painter）；
/// - 提示/教学高亮（`VisualHint` 的 MarkRole 标记）原样透传给 Painter，
///   由 `TeachingPalette.styleOf` 决定颜色与形状，UI 零推断。
///
/// ⚠️ 分层：本类只 import core 的**纯渲染数据白名单**（VisualHint 等），
/// 盘面数据经 domain 的 [GameSession] 转译，不直接触碰 core `Board`。
library;

import 'package:flutter/foundation.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/session_rules.dart';

/// 棋盘渲染视图模型（不可变）。
@immutable
class BoardViewModel {
  /// 构造视图模型（由 [fromSession] 装配，页面不直接构造）。
  const BoardViewModel({
    required this.values,
    required this.givenMask,
    required this.candidateMasks,
    required this.noteMode,
    required this.selectedIndex,
    required this.selectedValue,
    required this.peerHighlight,
    required this.sameDigitHighlights,
    required this.markErrors,
    required this.errorCells,
    required this.hintCells,
    required this.hintRegions,
    required this.hintLinks,
    required this.hintCandidateMarks,
    this.teachingOverlay,
  });

  /// 81 格当前值（0 = 空）。
  final List<int> values;

  /// 81 格题面给定掩码。
  final List<bool> givenMask;

  /// 81 格候选掩码（显示用：自动候选模式 = 数学候选，笔记模式 = 玩家笔记）。
  final List<int> candidateMasks;

  /// 是否手动笔记模式（决定候选数渲染样式）。
  final bool noteMode;

  /// 选中格（`null` = 未选中）。
  final int? selectedIndex;

  /// 选中格的值（`null` = 未选中或空格）。
  final int? selectedValue;

  /// 与选中格同行/列/宫的格（弱高亮）。
  final Set<int> peerHighlight;

  /// 相同数字高亮（格索引 → 级别）。
  final Map<int, SameDigitHighlight> sameDigitHighlights;

  /// 错误标红开关。
  final bool markErrors;

  /// 错误标红格集合。
  final Set<int> errorCells;

  /// 提示/教学高亮格（MarkRole 双通道）。
  final List<CellMark> hintCells;

  /// 提示/教学区域描边。
  final List<RegionMark> hintRegions;

  /// 提示/教学连线。
  final List<LinkMark> hintLinks;

  /// 提示/教学候选标记。
  final List<CandidateMark> hintCandidateMarks;

  /// 教学图层完整可视化数据（演示/实操关逐步渲染用；`null` = 无教学图层）。
  ///
  /// 与 [hintCells] 等四件套的关系：hint* 用于「提示服务」的轻量高亮，
  /// [teachingOverlay] 携带**完整 VisualHint**（含连线/区域/候选划除），
  /// 由 `TeachingOverlayPainter` 消费，UI 仍为零推断哑渲染。
  final VisualHint? teachingOverlay;

  /// 由对局状态装配（[hintVisual] 为提示服务裁剪后的可视化数据）。
  factory BoardViewModel.fromSession(
    GameSession session, {
    VisualHint? hintVisual,
    VisualHint? teachingOverlay,
  }) {
    final List<int> values = List<int>.of(session.board.values);
    final List<int> candidateMasks = List<int>.of(session.board.candidateMasks);
    final int? selected = session.selectedIndex;
    final int? selectedValue = selected == null ? null : values[selected];

    // 选中格同行/列/宫弱高亮。
    final Set<int> peer = <int>{};
    if (selected != null) {
      final int row = selected ~/ 9;
      final int col = selected % 9;
      for (int c = 0; c < 9; c++) {
        peer.add(row * 9 + c);
        peer.add(c * 9 + col);
      }
      final int boxRow = (row ~/ 3) * 3;
      final int boxCol = (col ~/ 3) * 3;
      for (int r = boxRow; r < boxRow + 3; r++) {
        for (int c = boxCol; c < boxCol + 3; c++) {
          peer.add(r * 9 + c);
        }
      }
      peer.remove(selected);
    }

    // 相同数字高亮两级（P0-PRA-07）。
    final Map<int, SameDigitHighlight> same = <int, SameDigitHighlight>{};
    if (session.highlightSameDigit && selectedValue != null) {
      for (int i = 0; i < 81; i++) {
        final SameDigitHighlight level = SessionRules.sameDigitLevel(
          values: values,
          candidateMasks: candidateMasks,
          index: i,
          digit: selectedValue,
        );
        if (level != SameDigitHighlight.none) {
          same[i] = level;
        }
      }
    }

    return BoardViewModel(
      values: values,
      givenMask: List<bool>.of(session.board.givenMask),
      candidateMasks: candidateMasks,
      noteMode: session.noteMode,
      selectedIndex: selected,
      selectedValue: selectedValue,
      peerHighlight: peer,
      sameDigitHighlights: same,
      markErrors: session.markErrors,
      errorCells: session.errorCells,
      hintCells: hintVisual?.cells ?? const <CellMark>[],
      hintRegions: hintVisual?.regions ?? const <RegionMark>[],
      hintLinks: hintVisual?.links ?? const <LinkMark>[],
      hintCandidateMarks: hintVisual?.candidateMarks ?? const <CandidateMark>[],
      teachingOverlay: teachingOverlay,
    );
  }
}
