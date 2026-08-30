/// T-CORE-08 难度分级器（Difficulty Grader）。
///
/// 算法（doc 06 §6.4 / PRD §6.1）：
/// 1. 用 [StepwiseSolver] 对题目做一次完整的逐级求解，得到步骤序列；
/// 2. 取序列中 **rank 最高**的技巧，按 `TechniqueRank.difficulties` 映射到五档
///    （入门 / 简单 / 中等 / 困难 / 大师）；
/// 3. 一步未用（题目已完成）→ 入门；当前规则集内不可解 → 标记 `solved=false`
///    并给出 [Difficulty.master]（表示「超出本规则集能力」），
///    调用方（生成器）应据此**丢弃该题**而不是当作大师题发布。
///
/// 铁律：分级**只依赖 rank 表**这一个事实源，不引入第二套权重，
/// 新增技巧只要在 `technique_rank.dart` 插一行，分级自动生效（调用方零改动）。
library;

import '../engine/stepwise_solver.dart';
import '../model/board.dart';
import '../techniques/rule_set.dart';
import '../techniques/solve_context.dart';
import '../techniques/technique_id.dart';
import '../techniques/technique_rank.dart';
import '../techniques/technique_registry.dart';
import 'difficulty.dart';

/// 一次难度分级的完整报告。
class GradingReport {
  /// 构造分级报告。
  GradingReport({
    required this.difficulty,
    required this.solved,
    required this.reason,
    required this.stepCount,
    required this.maxRank,
    required this.hardestTechnique,
    required List<TechniqueId> usedTechniques,
    required Map<TechniqueId, int> usageCounts,
  })  : usedTechniques = List<TechniqueId>.unmodifiable(usedTechniques),
        usageCounts = Map<TechniqueId, int>.unmodifiable(usageCounts);

  /// 评定档位。
  final Difficulty difficulty;

  /// 是否在当前规则集内纯逻辑解出。
  final bool solved;

  /// 求解停止原因。
  final StepwiseStopReason reason;

  /// 逻辑步数。
  final int stepCount;

  /// 用到的最大 rank（未用任何技巧时为 0）。
  final int maxRank;

  /// 用到的最难技巧（未用任何技巧时为 `null`）。
  final TechniqueId? hardestTechnique;

  /// 用到的技巧（rank 升序去重）。
  final List<TechniqueId> usedTechniques;

  /// 各技巧使用次数（rank 升序）。
  final Map<TechniqueId, int> usageCounts;

  /// 是否可作为正式题目发布（必须在规则集内解出）。
  bool get isPublishable => solved;

  /// 序列化为 JSON map（CLI 标注报告 / 题库元数据用）。
  Map<String, Object?> toJson() => <String, Object?>{
        'difficulty': difficulty.id,
        'solved': solved,
        'reason': reason.id,
        'stepCount': stepCount,
        'maxRank': maxRank,
        'hardestTechnique': hardestTechnique?.id,
        'usedTechniques': <String>[
          for (final TechniqueId id in usedTechniques) id.id,
        ],
        'usageCounts': <String, int>{
          for (final MapEntry<TechniqueId, int> e in usageCounts.entries)
            e.key.id: e.value,
        },
      };

  @override
  String toString() => 'GradingReport(${difficulty.id},solved=$solved,'
      'steps=$stepCount,hardest=${hardestTechnique?.id ?? '-'})';
}

/// 难度分级器。
class DifficultyGrader {
  /// 构造分级器；[solver] / [registry] 省略时使用默认注册表。
  DifficultyGrader({StepwiseSolver? solver, TechniqueRegistry? registry})
      : solver = solver ?? StepwiseSolver(registry: registry);

  /// 内部使用的逐级求解器。
  final StepwiseSolver solver;

  /// 对 [ctx] 描述的题目分级。
  GradingReport gradeContext(
    SolveContext ctx, {
    int maxSteps = StepwiseSolver.defaultMaxSteps,
  }) {
    final StepwiseSolveOutcome outcome = solver.solve(ctx, maxSteps: maxSteps);
    return fromOutcome(outcome);
  }

  /// 对 [board] 分级（自建 [SolveContext]）。
  GradingReport grade(
    Board board, {
    RuleSet? ruleSet,
    List<int>? solution,
    bool uniqueSolutionGuaranteed = true,
    int maxSteps = StepwiseSolver.defaultMaxSteps,
  }) =>
      gradeContext(
        SolveContext(
          board: board,
          ruleSet: ruleSet ?? RuleSet.t2(),
          uniqueSolutionGuaranteed: uniqueSolutionGuaranteed,
          solution: solution,
        ),
        maxSteps: maxSteps,
      );

  /// 由已有的求解产出直接生成报告（避免重复求解）。
  static GradingReport fromOutcome(StepwiseSolveOutcome outcome) {
    final TechniqueId? hardest = outcome.hardestTechnique();
    return GradingReport(
      difficulty: difficultyOf(outcome),
      solved: outcome.solved,
      reason: outcome.reason,
      stepCount: outcome.stepCount,
      maxRank: outcome.maxRank(),
      hardestTechnique: hardest,
      usedTechniques: outcome.usedTechniques(),
      usageCounts: outcome.usageCounts(),
    );
  }

  /// 由求解产出映射档位。
  ///
  /// - 已解出且用过技巧 → 最难技巧对应的档；
  /// - 已解出但零步（题目本来就满）→ [Difficulty.beginner]；
  /// - 未解出 → [Difficulty.master]（超出规则集，配合 `solved=false` 使用）。
  static Difficulty difficultyOf(StepwiseSolveOutcome outcome) {
    final TechniqueId? hardest = outcome.hardestTechnique();
    if (hardest == null) {
      return outcome.solved ? Difficulty.beginner : Difficulty.master;
    }
    final Difficulty byTechnique = TechniqueRank.difficultyOf(hardest);
    return outcome.solved ? byTechnique : Difficulty.master;
  }

  /// 五档各自的**代表性最高技巧**（教学章节排序、出题 profile 用）。
  ///
  /// 直接由 rank 表派生，不额外维护第二张表。
  static Map<Difficulty, List<TechniqueId>> techniquesByDifficulty() {
    final Map<Difficulty, List<TechniqueId>> grouped =
        <Difficulty, List<TechniqueId>>{
      for (final Difficulty difficulty in Difficulty.values)
        difficulty: <TechniqueId>[],
    };
    for (final TechniqueId id in TechniqueRank.byRankAscending()) {
      grouped[TechniqueRank.difficultyOf(id)]!.add(id);
    }
    return Map<Difficulty, List<TechniqueId>>.unmodifiable(
      <Difficulty, List<TechniqueId>>{
        for (final MapEntry<Difficulty, List<TechniqueId>> e in grouped.entries)
          e.key: List<TechniqueId>.unmodifiable(e.value),
      },
    );
  }

  @override
  String toString() => 'DifficultyGrader(${solver.registry.length} techniques)';
}
