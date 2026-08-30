/// [Move] 的应用与逆应用（撤销依赖，P0-ENG-05）。
///
/// 精确回滚策略：
/// 应用前把**所有可能被改动的格**（本格 + 受影响的 20 个 peer）的候选掩码
/// 与本格原值快照进 [MoveRecord]；逆应用时逐格写回。
/// 这样无论候选是自动计算还是手动笔记，撤销都能做到**逐字段相等**
/// （doc 07 T-CORE-04 验收项）。
library;

import 'package:meta/meta.dart';

import '../model/board.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../model/peers.dart';
import '../util/core_error.dart';
import 'candidate_calculator.dart';
import 'move.dart';

/// 一次已应用操作的完整回滚记录。
@immutable
class MoveRecord {
  /// 构造回滚记录（一般由 [MoveApplier.apply] 产出）。
  MoveRecord({
    required this.move,
    required this.previousValue,
    required Map<int, int> previousCandidateMasks,
  }) : previousCandidateMasks =
            Map<int, int>.unmodifiable(previousCandidateMasks);

  /// 被应用的操作。
  final Move move;

  /// 目标格在应用前的填数值。
  final int previousValue;

  /// 应用前各相关格的候选掩码快照（格索引 → 掩码）。
  final Map<int, int> previousCandidateMasks;

  /// 本次操作实际触及的格索引（升序）。
  List<int> touchedCells() {
    final List<int> cells = previousCandidateMasks.keys.toList()..sort();
    return List<int>.unmodifiable(cells);
  }

  @override
  String toString() =>
      'MoveRecord(${move.label}, prev=$previousValue, touched=${previousCandidateMasks.length})';
}

/// [Move] 的应用器（静态工具，原地修改盘面）。
abstract final class MoveApplier {
  /// 判断 [move] 在当前盘面上是否可应用。
  ///
  /// 规则：
  /// - 题面给定格不可被任何操作改动（PRD C-11）；
  /// - 已填格不接受候选标记类操作（候选只对空格有意义）；
  /// - 幂等操作（填入相同数字、清除空格、重复标记/删除候选）视为**不可应用**，
  ///   避免往撤销栈里塞无效步骤。
  static bool canApply(Board board, Move move) {
    final int index = move.cellIndex;
    if (move.type == MoveType.autoFillCandidates) {
      return !CandidateCalculator.isConsistent(board);
    }
    if (board.isGiven(index)) {
      return false;
    }
    switch (move.type) {
      case MoveType.place:
        return board.values[index] != move.digit;
      case MoveType.clear:
        return board.values[index] != kEmptyValue;
      case MoveType.addCandidate:
        return board.values[index] == kEmptyValue &&
            !board.candidatesAt(index).contains(move.digit);
      case MoveType.removeCandidate:
        return board.values[index] == kEmptyValue &&
            board.candidatesAt(index).contains(move.digit);
      case MoveType.autoFillCandidates:
        return !CandidateCalculator.isConsistent(board);
    }
  }

  /// 应用 [move] 并返回回滚记录。
  ///
  /// 对题面给定格操作抛 `E_BOARD_004`。
  /// ⚠️ 调用方应先用 [canApply] 过滤幂等操作；本方法对幂等操作也会
  /// 正常返回记录（内容为空改动），以便调用链保持简单。
  static MoveRecord apply(Board board, Move move) {
    final int index = move.cellIndex;
    Coord.requireIndex(index);
    if (move.type != MoveType.autoFillCandidates && board.isGiven(index)) {
      throw CoreException(
        CoreErrorCode.boardGivenImmutable,
        '给定格 ${Coord.label(index)}',
      );
    }

    final int previousValue = board.values[index];
    final Map<int, int> snapshot = _snapshotMasks(board, index, move.type);

    switch (move.type) {
      case MoveType.place:
        _applyPlace(board, index, move.digit, previousValue);
      case MoveType.clear:
        board.forceSetValue(index, kEmptyValue);
        CandidateCalculator.syncAfterClear(board, index);
      case MoveType.addCandidate:
        board.addCandidate(index, move.digit);
      case MoveType.removeCandidate:
        board.eliminate(index, move.digit);
      case MoveType.autoFillCandidates:
        CandidateCalculator.recomputeAll(board);
    }

    return MoveRecord(
      move: move,
      previousValue: previousValue,
      previousCandidateMasks: snapshot,
    );
  }

  /// 逆应用（撤销）：把盘面恢复到 [record] 记录的应用前状态。
  static void revert(Board board, MoveRecord record) {
    final int index = record.move.cellIndex;
    if (record.move.type != MoveType.autoFillCandidates) {
      board.forceSetValue(index, record.previousValue);
    }
    record.previousCandidateMasks.forEach((int cell, int mask) {
      board.candidateMasks[cell] = mask;
    });
  }

  /// 重做：等价于再次 [apply] 同一个 [Move]，并返回新的回滚记录。
  static MoveRecord reapply(Board board, Move move) => apply(board, move);

  /// 填数：若该格原本已有别的数字，先做一次「清除同步」再落子，
  /// 保证候选与 `recomputeAll` 逐格一致。
  static void _applyPlace(
      Board board, int index, int digit, int previousValue) {
    Digit.requireDigit(digit);
    if (previousValue != kEmptyValue) {
      board.forceSetValue(index, kEmptyValue);
      CandidateCalculator.syncAfterClear(board, index);
    }
    board.forceSetValue(index, digit);
    CandidateCalculator.syncAfterPlace(board, index, digit);
  }

  /// 快照可能被改动的格的候选掩码。
  static Map<int, int> _snapshotMasks(Board board, int index, MoveType type) {
    if (type == MoveType.autoFillCandidates) {
      return <int, int>{
        for (int cell = 0; cell < kCellCount; cell++)
          cell: board.candidateMasks[cell],
      };
    }
    final Map<int, int> snapshot = <int, int>{
      index: board.candidateMasks[index],
    };
    if (type.changesValue) {
      for (final int peer in Peers.peersOf(index)) {
        snapshot[peer] = board.candidateMasks[peer];
      }
    }
    return snapshot;
  }
}
