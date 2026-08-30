/// 可复现随机源。
///
/// 架构文档 §7.1 铁律：算法层禁止使用全局随机，所有随机必须走 [Rng]，
/// 以保证 CLI 出题「同 seed 结果可复现」（doc 07 T-CORE-03 验收项）。
library;

import 'dart:math' as math;

/// 种子驱动的随机源。
class Rng {
  /// 以 [seed] 构造一个确定性随机源。
  Rng(this.seed) : _random = math.Random(seed);

  /// 构造种子来自当前时间的随机源。
  ///
  /// ⚠️ 仅供交互式场景（如 App 内即时出题）使用；
  /// CLI 批处理与单测必须显式传入固定 seed。
  factory Rng.fromClock() => Rng(DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF);

  /// 随机种子（用于结果复现与报表记录）。
  final int seed;

  final math.Random _random;

  /// 返回 `[0, max)` 区间内的随机整数。
  int nextInt(int max) => _random.nextInt(max);

  /// 返回 `[0.0, 1.0)` 区间内的随机浮点数。
  double nextDouble() => _random.nextDouble();

  /// 返回随机布尔值。
  bool nextBool() => _random.nextBool();

  /// 原地 Fisher–Yates 洗牌。
  void shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final int j = _random.nextInt(i + 1);
      final T tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// 返回 [source] 的洗牌副本（不修改原列表）。
  List<T> shuffled<T>(Iterable<T> source) {
    final List<T> copy = source.toList();
    shuffle(copy);
    return copy;
  }

  /// 从 [list] 中随机取一个元素；列表为空时抛 [StateError]。
  T pick<T>(List<T> list) {
    if (list.isEmpty) {
      throw StateError('无法从空列表中取样');
    }
    return list[_random.nextInt(list.length)];
  }

  /// 派生一个子随机源（用于并发分片时保持可复现）。
  Rng derive(int salt) => Rng((seed ^ (salt * 0x9E3779B1)) & 0x7FFFFFFF);
}
