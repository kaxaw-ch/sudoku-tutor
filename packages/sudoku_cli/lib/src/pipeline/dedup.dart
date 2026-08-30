/// 基于规范化指纹的同构去重（doc 06 §3.2 `lib/src/pipeline/dedup.dart`）。
///
/// 指纹口径直接复用 `sudoku_core` 的 `Fingerprint.ofValues`
/// （数字重标 + 转置对称），CLI 不重复实现任何指纹算法。
library;

import 'package:sudoku_core/sudoku_core.dart';

import '../model/annotated_puzzle.dart';

/// 指纹去重器（线程内使用；并发分片由 pipeline 合并时统一去过重）。
class Dedup {
  /// 构造去重器。
  Dedup();

  final Set<String> _seen = <String>{};

  /// 已收录的唯一指纹数。
  int get length => _seen.length;

  /// 尝试收录 [fingerprint]；若此前未见过则记录并返回 `true`，否则返回 `false`。
  bool add(String fingerprint) => _seen.add(fingerprint);

  /// 批量收录，返回**实际新增**的指纹数。
  int addAll(Iterable<String> fingerprints) {
    int added = 0;
    for (final String fingerprint in fingerprints) {
      if (_seen.add(fingerprint)) {
        added++;
      }
    }
    return added;
  }

  /// 是否已收录。
  bool contains(String fingerprint) => _seen.contains(fingerprint);

  /// 计算一份题面的规范化指纹（转发 `sudoku_core`，保持单一事实源）。
  static String fingerprintOf(List<int> givenValues) =>
      Fingerprint.ofValues(givenValues);

  /// 静态便捷方法：对一组题目按首次出现顺序去重（返回新列表，不改入参）。
  ///
  /// 返回记录 `(去重后列表, 被剔除数)` 便于报表统计。
  static (List<AnnotatedPuzzle>, int) unique(
    Iterable<AnnotatedPuzzle> puzzles,
  ) {
    final Dedup dedup = Dedup();
    final List<AnnotatedPuzzle> kept = <AnnotatedPuzzle>[];
    int dropped = 0;
    for (final AnnotatedPuzzle puzzle in puzzles) {
      if (dedup.add(puzzle.fingerprint)) {
        kept.add(puzzle);
      } else {
        dropped++;
      }
    }
    return (kept, dropped);
  }
}
