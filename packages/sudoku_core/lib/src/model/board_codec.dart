/// 81 字符串、行列文本、JSON 与 [Board] 的互转。
library;

import '../util/core_error.dart';
import 'board.dart';
import 'candidate_set.dart';
import 'coord.dart';
import 'digit.dart';

/// 盘面编解码静态工具。
///
/// 约定：本包**不做任何文件 IO**（架构文档 §2.2），只收字符串、吐字符串。
abstract final class BoardCodec {
  /// 由 81 字符串解码盘面。
  static Board decode81(String s81, {bool markGivens = true}) =>
      Board.fromPuzzleString(s81, markGivens: markGivens);

  /// 编码盘面为 81 字符串。
  static String encode81(Board board, {String emptyChar = kEmptyChar}) =>
      board.toPuzzleString(emptyChar: emptyChar);

  /// 由 81 字符串解码为纯数值列表（不构造 [Board]）。
  static List<int> decodeValues(String s81) {
    final String cleaned = s81.replaceAll(RegExp(r'[\s|\-+]'), '');
    if (cleaned.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        '有效字符数 ${cleaned.length}，期望 $kCellCount',
      );
    }
    return <int>[for (int i = 0; i < kCellCount; i++) Digit.parseChar(cleaned[i])];
  }

  /// 编码数值列表为 81 字符串。
  static String encodeValues(List<int> values, {String emptyChar = kEmptyChar}) {
    if (values.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        'values 长度 ${values.length}，期望 $kCellCount',
      );
    }
    final StringBuffer buffer = StringBuffer();
    for (final int value in values) {
      buffer.write(value == kEmptyValue ? emptyChar : '$value');
    }
    return buffer.toString();
  }

  /// 渲染为 9 行可读文本（调试与 CLI 报表用）。
  static String toGrid(Board board, {String emptyChar = kEmptyChar}) {
    final StringBuffer buffer = StringBuffer();
    for (int row = 0; row < kBoardSize; row++) {
      if (row > 0 && row % kBoxSize == 0) {
        buffer.writeln('------+-------+------');
      }
      for (int col = 0; col < kBoardSize; col++) {
        if (col > 0 && col % kBoxSize == 0) {
          buffer.write('| ');
        }
        final int value = board.valueAtRc(row, col);
        buffer.write(value == kEmptyValue ? emptyChar : '$value');
        buffer.write(col == kBoardSize - 1 ? '' : ' ');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  /// 编码为 JSON Map（含候选，便于断点存档与 Isolate 传输）。
  static Map<String, Object?> toJson(Board board) => <String, Object?>{
        'values': board.toPuzzleString(),
        'givens': board.toGivenMaskString(),
        'candidates': List<int>.of(board.candidateMasks),
      };

  /// 由 JSON Map 解码盘面。
  static Board fromJson(Map<String, Object?> json) {
    final Object? rawValues = json['values'];
    if (rawValues is! String) {
      throw const CoreException(CoreErrorCode.boardStringChar, 'JSON 缺少 values 字段');
    }
    final Object? rawGivens = json['givens'];
    List<bool>? givens;
    if (rawGivens is String) {
      if (rawGivens.length != kCellCount) {
        throw CoreException(
          CoreErrorCode.boardStringLength,
          'givens 长度 ${rawGivens.length}，期望 $kCellCount',
        );
      }
      givens = <bool>[for (int i = 0; i < kCellCount; i++) rawGivens[i] == '1'];
    }
    final Board board = Board.fromValues(
      decodeValues(rawValues),
      givenMask: givens,
    );
    final Object? rawCandidates = json['candidates'];
    if (rawCandidates is List) {
      if (rawCandidates.length != kCellCount) {
        throw CoreException(
          CoreErrorCode.boardStringLength,
          'candidates 长度 ${rawCandidates.length}，期望 $kCellCount',
        );
      }
      for (int i = 0; i < kCellCount; i++) {
        final Object? mask = rawCandidates[i];
        if (mask is! int) {
          throw CoreException(CoreErrorCode.boardStringChar, 'candidates[$i] 非整数');
        }
        board.setCandidates(i, CandidateSet(mask));
      }
    }
    return board;
  }
}
