/// 9 位候选位集的通用位运算工具。
///
/// 约定（架构文档 §7.1）：数字 `d ∈ 1..9` 对应位 `1 << (d - 1)`，
/// 因此完整候选集掩码为 `0x1FF`。
library;

/// 位运算工具集合（全部为静态纯函数）。
abstract final class BitOps {
  /// 9 位全集掩码（数字 1..9 全部存在）。
  static const int fullMask = 0x1FF;

  /// 统计掩码中置位的个数（popcount）。
  ///
  /// 针对 9 位小掩码做了展开优化，复杂度 O(置位数)。
  static int popcount(int mask) {
    int m = mask;
    int count = 0;
    while (m != 0) {
      m &= m - 1;
      count++;
    }
    return count;
  }

  /// 返回掩码中最低置位的下标（0 起）；掩码为 0 时返回 -1。
  static int lowestBitIndex(int mask) {
    if (mask == 0) {
      return -1;
    }
    int m = mask;
    int index = 0;
    while ((m & 1) == 0) {
      m >>= 1;
      index++;
    }
    return index;
  }

  /// 返回掩码中最高置位的下标（0 起）；掩码为 0 时返回 -1。
  static int highestBitIndex(int mask) {
    if (mask == 0) {
      return -1;
    }
    int m = mask;
    int index = -1;
    while (m != 0) {
      m >>= 1;
      index++;
    }
    return index;
  }

  /// 按升序遍历掩码代表的数字（1..9）。
  static Iterable<int> digitsOf(int mask) sync* {
    int m = mask;
    while (m != 0) {
      final int bit = m & -m;
      m ^= bit;
      yield lowestBitIndex(bit) + 1;
    }
  }

  /// 数字 `digit` 对应的位掩码。
  static int bitOf(int digit) => 1 << (digit - 1);

  /// 掩码是否包含数字 `digit`。
  static bool has(int mask, int digit) => (mask & bitOf(digit)) != 0;

  /// 枚举 `source` 中所有大小为 `k` 的组合（保持原顺序，字典序输出）。
  ///
  /// 供子集类技巧（裸对/裸三、隐对/隐三、Fish(N)）复用。
  static List<List<T>> combinations<T>(List<T> source, int k) {
    final List<List<T>> output = <List<T>>[];
    if (k <= 0 || k > source.length) {
      return output;
    }
    final List<int> picked = List<int>.filled(k, 0);

    void walk(int start, int depth) {
      if (depth == k) {
        output.add(<T>[for (final int i in picked) source[i]]);
        return;
      }
      for (int i = start; i <= source.length - (k - depth); i++) {
        picked[depth] = i;
        walk(i + 1, depth + 1);
      }
    }

    walk(0, 0);
    return output;
  }
}
