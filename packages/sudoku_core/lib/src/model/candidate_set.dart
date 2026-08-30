/// 9 位位集候选集（int 掩码）与位运算 API。
///
/// 架构文档 §4.1 / 风险 A-08：本实现采用 Dart 3.3+ 的 `extension type`，
/// 零运行时开销。若锁定的 SDK 低于 3.3，可原样替换为
/// `final class CandidateSet { final int mask; ... }`（性能差异可忽略，
/// 且本文件之外的调用点无需改动，因为对外只暴露方法而非表示类型）。
library;

import '../util/bit_ops.dart';
import 'digit.dart';

/// 候选集：低 9 位表示数字 1..9，位运算 O(1)。
extension type const CandidateSet(int mask) {
  /// 空候选集。
  static const CandidateSet none = CandidateSet(0);

  /// 全候选集（1..9）。
  static const CandidateSet all = CandidateSet(BitOps.fullMask);

  /// 由数字集合构造。
  static CandidateSet fromDigits(Iterable<int> digits) {
    int acc = 0;
    for (final int digit in digits) {
      Digit.requireDigit(digit);
      acc |= BitOps.bitOf(digit);
    }
    return CandidateSet(acc);
  }

  /// 由单个数字构造。
  static CandidateSet single(int digit) {
    Digit.requireDigit(digit);
    return CandidateSet(BitOps.bitOf(digit));
  }

  /// 是否包含数字 [digit]。
  bool contains(int digit) => (mask & BitOps.bitOf(digit)) != 0;

  /// 返回加入 [digit] 后的新候选集。
  CandidateSet plus(int digit) => CandidateSet(mask | BitOps.bitOf(digit));

  /// 返回移除 [digit] 后的新候选集。
  CandidateSet minus(int digit) => CandidateSet(mask & ~BitOps.bitOf(digit));

  /// 并集。
  CandidateSet union(CandidateSet other) => CandidateSet(mask | other.mask);

  /// 交集。
  CandidateSet intersect(CandidateSet other) => CandidateSet(mask & other.mask);

  /// 差集（本集减去 [other]）。
  CandidateSet difference(CandidateSet other) => CandidateSet(mask & ~other.mask);

  /// 是否完全包含 [other]。
  bool containsAll(CandidateSet other) => (mask & other.mask) == other.mask;

  /// 是否与 [other] 有交集。
  bool overlaps(CandidateSet other) => (mask & other.mask) != 0;

  /// 候选数个数。
  int count() => BitOps.popcount(mask);

  /// 是否为空集。
  bool get isEmpty => mask == 0;

  /// 是否非空。
  bool get isNotEmpty => mask != 0;

  /// 升序数字列表。
  List<int> digits() => BitOps.digitsOf(mask).toList(growable: false);

  /// 最小候选数；空集返回 0。
  int get lowest => mask == 0 ? 0 : BitOps.lowestBitIndex(mask) + 1;

  /// 最大候选数；空集返回 0。
  int get highest => mask == 0 ? 0 : BitOps.highestBitIndex(mask) + 1;

  /// 便于调试/文案的紧凑描述，如 `{1,5,9}`。
  String describe() => '{${digits().join(',')}}';
}
