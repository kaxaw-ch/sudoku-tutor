/// 盘面规范化指纹（同构去重用）。
///
/// 用途：CLI 出题管线的去重（doc 07 T-CLI-02）。
///
/// ⚠️ 口径说明：完整数独同构群（数字重标 9! × 行列带置换 6^4 × 转置 2 ≈ 1.2e12）
/// 逐题穷举不可行。本实现采用**可解释、低成本的规范化**：
///   1. 数字重标：按题面行优先首次出现顺序把数字重标为 1,2,3…；
///   2. 转置对称：取「原盘」与「转置盘」重标后的字典序较小者。
/// 该口径可稳定识别「数字重标 + 转置」这两类最常见的重复，
/// 不保证识别行列带置换类同构（如需，可在批次 D 依据实测重复率再加强）。
library;

import '../model/board.dart';
import '../model/coord.dart';
import '../model/digit.dart';

/// 盘面指纹工具。
abstract final class Fingerprint {
  /// 计算盘面（题面）的规范化指纹字符串，长度 81。
  static String of(Board board) => ofValues(board.toValueList());

  /// 计算数值列表的规范化指纹字符串，长度 81。
  static String ofValues(List<int> values) {
    if (values.length != kCellCount) {
      throw ArgumentError.value(values.length, 'values.length', '期望 $kCellCount');
    }
    final String direct = _relabel(values);
    final List<int> transposed = <int>[
      for (int i = 0; i < kCellCount; i++)
        values[Coord.indexOf(Coord.colOf(i), Coord.rowOf(i))],
    ];
    final String flipped = _relabel(transposed);
    return direct.compareTo(flipped) <= 0 ? direct : flipped;
  }

  /// 两个盘面在本口径下是否同构重复。
  static bool sameShape(Board a, Board b) => of(a) == of(b);

  /// 按行优先首次出现顺序重标数字，空格保持 `.`。
  static String _relabel(List<int> values) {
    final List<int> mapping = List<int>.filled(kMaxDigit + 1, 0);
    int next = 1;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < kCellCount; i++) {
      final int value = values[i];
      if (value == kEmptyValue) {
        buffer.write(kEmptyChar);
        continue;
      }
      if (mapping[value] == 0) {
        mapping[value] = next;
        next++;
      }
      buffer.write('${mapping[value]}');
    }
    return buffer.toString();
  }
}
