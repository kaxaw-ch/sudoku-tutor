/// 单格只读视图（值 / 是否给定 / 候选集）。
library;

import 'package:meta/meta.dart';

import 'candidate_set.dart';
import 'coord.dart';
import 'digit.dart';

/// 一个格子的不可变快照视图。
///
/// 由 `Board.cellAtIndex` / `Board.cellAt` 产出，供 UI 与技巧识别器只读消费。
@immutable
class Cell {
  /// 构造一个格子视图。
  const Cell({
    required this.index,
    required this.value,
    required this.isGiven,
    required this.candidates,
  });

  /// 格索引 0..80。
  final int index;

  /// 当前值，0 表示空。
  final int value;

  /// 是否为原始题面给定格（PRD C-11，全程携带）。
  final bool isGiven;

  /// 当前候选集（已填格为空集）。
  final CandidateSet candidates;

  /// 所在行号（0 起）。
  int get row => Coord.rowOf(index);

  /// 所在列号（0 起）。
  int get col => Coord.colOf(index);

  /// 所在宫号（0 起）。
  int get box => Coord.boxOf(index);

  /// 是否为空格。
  bool get isEmpty => value == kEmptyValue;

  /// 是否已填数。
  bool get isFilled => value != kEmptyValue;

  /// 人类可读标签，形如 `r2c3`。
  String get label => Coord.label(index);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Cell &&
          other.index == index &&
          other.value == value &&
          other.isGiven == isGiven &&
          other.candidates.mask == candidates.mask);

  @override
  int get hashCode => Object.hash(index, value, isGiven, candidates.mask);

  @override
  String toString() =>
      'Cell($label, value=$value, given=$isGiven, candidates=${candidates.describe()})';
}
