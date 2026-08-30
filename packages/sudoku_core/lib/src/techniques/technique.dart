/// 所有技巧识别器的唯一契约（doc 06 §6.1）。
library;

import '../grading/difficulty.dart';
import 'solve_context.dart';
import 'technique_id.dart';
import 'technique_rank.dart';
import 'technique_result.dart';

/// 技巧识别器接口。
///
/// 实现约定（**不得偏离**）：
/// 1. `find` 为**只读扫描**，不得修改 `ctx.board`；
/// 2. `limit == 1` 用于逐级求解（命中即返），`limit > 1` 用于题库标注；
/// 3. 任何非空 [TechniqueResult] 必须携带完整 `visual` 与 `narration`；
/// 4. 无命中时返回空 [Iterable]（而不是含 `isEmpty` 结果的列表）。
abstract interface class Technique {
  /// 技巧标识。
  TechniqueId get id;

  /// 逐级求解顺序（越小越先尝试），见 doc 06 §6.2 rank 表。
  int get rank;

  /// 难度档，用于难度分级。
  Difficulty get difficulty;

  /// 在 [ctx] 上扫描本技巧，最多返回 [limit] 条结论。
  Iterable<TechniqueResult> find(SolveContext ctx, {int limit = 1});
}

/// 识别器公共基类：从 [TechniqueRank] 表自动派生 `rank` 与 `difficulty`。
///
/// 子类只需实现 [id] 与 [find]，避免 rank/难度在两处重复声明而漂移。
abstract base class TechniqueBase implements Technique {
  /// 默认构造。
  const TechniqueBase();

  @override
  int get rank => TechniqueRank.of(id);

  @override
  Difficulty get difficulty => TechniqueRank.difficultyOf(id);

  /// 便捷判定：本技巧在 [ctx] 下是否被启用。
  bool isEnabledIn(SolveContext ctx) => ctx.allows(id);

  @override
  String toString() => '${runtimeType.toString()}(${id.id},rank=$rank)';
}
