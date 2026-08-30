/// 技巧等级序（逐级求解顺序 & 难度分级依据），逐行对应 doc 06 §6.2 rank 表。
///
/// **单一事实源**：rank / 难度档 / 实现档三张映射只在本文件定义，
/// `LogicalSolver`、`DifficultyGrader`、`RuleSet`、CLI profile 一律取用此处，
/// 新增技巧只需在此插入一行。
library;

import '../grading/difficulty.dart';
import '../util/core_error.dart';
import 'technique_id.dart';

/// 本期 scope 分期档（与「难度档」是两个不同维度，见 doc 03 §0.4）。
enum TechniqueTier {
  /// T1：基础 + 常规进阶。
  t1('T1'),

  /// T2：本期默认推荐档新增的 3 项。
  t2('T2'),

  /// T3：本期不实现，仅保留扩展插槽。
  t3('T3');

  const TechniqueTier(this.label);

  /// 展示与配置用标签。
  final String label;
}

/// rank 表与派生查询（全部为静态纯函数）。
abstract final class TechniqueRank {
  /// rank 值：越小越简单，`LogicalSolver` 按升序遍历，命中即返。
  static const Map<TechniqueId, int> ranks = <TechniqueId, int>{
    TechniqueId.nakedSingle: 10,
    TechniqueId.hiddenSingle: 20,
    TechniqueId.nakedPair: 30,
    TechniqueId.hiddenPair: 40,
    TechniqueId.lockedCandidates: 50,
    TechniqueId.nakedTriple: 60,
    TechniqueId.hiddenTriple: 70,
    TechniqueId.xWing: 80,
    TechniqueId.finnedXWing: 90,
    TechniqueId.swordfish: 100,
    TechniqueId.xyWing: 110,
    TechniqueId.xyzWing: 120,
    TechniqueId.wWing: 130,
    TechniqueId.urType1: 140,
    TechniqueId.urType2: 150,
    TechniqueId.simpleColouring: 160,
  };

  /// 难度档映射（doc 06 §6.2「难度档」列，与 PRD §6.1 一一对应）。
  static const Map<TechniqueId, Difficulty> difficulties = <TechniqueId, Difficulty>{
    TechniqueId.nakedSingle: Difficulty.beginner,
    TechniqueId.hiddenSingle: Difficulty.beginner,
    TechniqueId.nakedPair: Difficulty.easy,
    TechniqueId.hiddenPair: Difficulty.easy,
    TechniqueId.lockedCandidates: Difficulty.easy,
    TechniqueId.nakedTriple: Difficulty.medium,
    TechniqueId.hiddenTriple: Difficulty.medium,
    TechniqueId.xWing: Difficulty.medium,
    TechniqueId.finnedXWing: Difficulty.hard,
    TechniqueId.swordfish: Difficulty.hard,
    TechniqueId.xyWing: Difficulty.hard,
    TechniqueId.xyzWing: Difficulty.hard,
    TechniqueId.wWing: Difficulty.hard,
    TechniqueId.urType1: Difficulty.master,
    TechniqueId.urType2: Difficulty.master,
    TechniqueId.simpleColouring: Difficulty.master,
  };

  /// 实现档映射（doc 06 §6.2「档位」列）。
  static const Map<TechniqueId, TechniqueTier> tiers = <TechniqueId, TechniqueTier>{
    TechniqueId.nakedSingle: TechniqueTier.t1,
    TechniqueId.hiddenSingle: TechniqueTier.t1,
    TechniqueId.nakedPair: TechniqueTier.t1,
    TechniqueId.hiddenPair: TechniqueTier.t1,
    TechniqueId.lockedCandidates: TechniqueTier.t1,
    TechniqueId.nakedTriple: TechniqueTier.t1,
    TechniqueId.hiddenTriple: TechniqueTier.t1,
    TechniqueId.xWing: TechniqueTier.t1,
    TechniqueId.finnedXWing: TechniqueTier.t2,
    TechniqueId.swordfish: TechniqueTier.t1,
    TechniqueId.xyWing: TechniqueTier.t1,
    TechniqueId.xyzWing: TechniqueTier.t1,
    TechniqueId.wWing: TechniqueTier.t2,
    TechniqueId.urType1: TechniqueTier.t1,
    TechniqueId.urType2: TechniqueTier.t1,
    TechniqueId.simpleColouring: TechniqueTier.t2,
  };

  /// 取 [id] 的 rank；未登记抛 `E_TECH_003`。
  static int of(TechniqueId id) {
    final int? rank = ranks[id];
    if (rank == null) {
      throw CoreException(CoreErrorCode.techNotRegistered, 'rank 表缺少 ${id.id}');
    }
    return rank;
  }

  /// 取 [id] 的难度档；未登记抛 `E_TECH_003`。
  static Difficulty difficultyOf(TechniqueId id) {
    final Difficulty? difficulty = difficulties[id];
    if (difficulty == null) {
      throw CoreException(CoreErrorCode.techNotRegistered, '难度表缺少 ${id.id}');
    }
    return difficulty;
  }

  /// 取 [id] 的实现档；未登记抛 `E_TECH_003`。
  static TechniqueTier tierOf(TechniqueId id) {
    final TechniqueTier? tier = tiers[id];
    if (tier == null) {
      throw CoreException(CoreErrorCode.techNotRegistered, '档位表缺少 ${id.id}');
    }
    return tier;
  }

  /// 按 rank 升序的全部技巧标识。
  static List<TechniqueId> byRankAscending() {
    final List<TechniqueId> list = TechniqueId.values.toList()
      ..sort((TechniqueId a, TechniqueId b) => of(a).compareTo(of(b)));
    return List<TechniqueId>.unmodifiable(list);
  }

  /// rank 不超过 [maxRank] 的技巧集合。
  static Set<TechniqueId> upTo(int maxRank) => <TechniqueId>{
        for (final TechniqueId id in TechniqueId.values)
          if (of(id) <= maxRank) id,
      };

  /// 指定实现档的技巧集合（[TechniqueTier.t2] 表示"仅 T2 新增的 3 项"）。
  static Set<TechniqueId> ofTier(TechniqueTier tier) => <TechniqueId>{
        for (final TechniqueId id in TechniqueId.values)
          if (tierOf(id) == tier) id,
      };
}
