/// T-CORE-07 逐级求解器（Stepwise / Logical Solver）。
///
/// 职责（doc 06 §6.3 / doc 07 T-CORE-07）：
/// 1. 按 [RuleSet] 过滤识别器，**按 rank 升序**逐项尝试，命中即返回**一步**；
/// 2. 一步 = 技巧 + 删数/填数 + 可视化数据 + 讲解参数（[TechniqueResult] 已自带）；
/// 3. [solve] 反复取步并落盘，记录完整的**解题步骤序列**，供难度分级、
///    演示回放与 CLI 标注报告复用。
///
/// 铁律：
/// - 识别器不得修改盘面，落盘统一由本文件的 [StepwiseSolver._applyStep] 执行；
/// - [SolveContext.board] 只读，[solve] 一律在 `board.snapshot()` 副本上推进；
/// - 结论安全性已在识别器出口（`TechniqueSupport.emit` → `SanityGuard`）
///   拦过一道，本文件在落盘前**再拦一道**（双保险，doc 08 风险 1）；
/// - 出现「同一指纹重复上报」或「一步不产生任何盘面变化」即判定卡死，
///   立即停止，绝不空转。
library;

import '../grading/difficulty.dart';
import '../model/board.dart';
import '../model/coord.dart';
import '../techniques/rule_set.dart';
import '../techniques/solve_context.dart';
import '../techniques/technique.dart';
import '../techniques/technique_id.dart';
import '../techniques/technique_rank.dart';
import '../techniques/technique_registry.dart';
import '../techniques/technique_result.dart';
import '../util/core_error.dart';
import 'candidate_calculator.dart';
import 'sanity_guard.dart';

/// 逐级求解停止原因。
enum StepwiseStopReason {
  /// 盘面已填满（求解成功）。
  solved('solved', '已解出'),

  /// 当前规则集下再无技巧可用（纯逻辑不可解）。
  noTechnique('no_technique', '规则集内无可用技巧'),

  /// 达到步数上限。
  maxStepsReached('max_steps', '达到步数上限'),

  /// 步骤重复或无实际改动（防空转）。
  stalled('stalled', '推进停滞');

  const StepwiseStopReason(this.id, this.zhName);

  /// 稳定标识（序列化用）。
  final String id;

  /// 简体中文说明。
  final String zhName;
}

/// 一条已应用的解题步骤。
class SolveStep {
  /// 构造一条步骤。
  const SolveStep({
    required this.order,
    required this.result,
    required this.boardBefore,
  });

  /// 步序（从 1 开始）。
  final int order;

  /// 本步的技巧结论（含可视化与讲解参数）。
  final TechniqueResult result;

  /// 应用本步**之前**的盘面 81 字符串（演示回放用）。
  final String boardBefore;

  /// 本步使用的技巧标识。
  TechniqueId get techniqueId => result.techniqueId;

  /// 本步技巧的 rank。
  int get rank => TechniqueRank.of(result.techniqueId);

  /// 本步技巧的难度档。
  Difficulty get difficulty => TechniqueRank.difficultyOf(result.techniqueId);

  /// 本步是否为填数步。
  bool get isPlacement => result.placements.isNotEmpty;

  /// 人类可读摘要，如 `#3 hidden_single r2c5 填 7`。
  String get label {
    final StringBuffer buffer = StringBuffer('#$order ${techniqueId.id} ');
    if (result.placements.isNotEmpty) {
      buffer.write(<String>[
        for (final Placement p in result.placements) p.label,
      ].join('、'));
    } else {
      buffer.write(<String>[
        for (final Elimination e in result.eliminations) e.label,
      ].join('、'));
    }
    return buffer.toString();
  }

  @override
  String toString() => 'SolveStep($label)';
}

/// 一次逐级求解的完整产出。
class StepwiseSolveOutcome {
  /// 构造求解产出。
  StepwiseSolveOutcome({
    required this.board,
    required this.reason,
    required List<SolveStep> steps,
  }) : steps = List<SolveStep>.unmodifiable(steps);

  /// 求解结束时的盘面（[StepwiseSolver.solve] 的工作副本）。
  final Board board;

  /// 停止原因。
  final StepwiseStopReason reason;

  /// 完整步骤序列（按应用顺序）。
  final List<SolveStep> steps;

  /// 是否解出。
  bool get solved => reason == StepwiseStopReason.solved;

  /// 步数。
  int get stepCount => steps.length;

  /// 用到的技巧（按 rank 升序去重）。
  List<TechniqueId> usedTechniques() {
    final Set<TechniqueId> used = <TechniqueId>{
      for (final SolveStep step in steps) step.techniqueId,
    };
    final List<TechniqueId> list = used.toList()
      ..sort((TechniqueId a, TechniqueId b) =>
          TechniqueRank.of(a).compareTo(TechniqueRank.of(b)));
    return List<TechniqueId>.unmodifiable(list);
  }

  /// 各技巧的使用次数（按 rank 升序）。
  Map<TechniqueId, int> usageCounts() {
    final Map<TechniqueId, int> counts = <TechniqueId, int>{};
    for (final SolveStep step in steps) {
      counts[step.techniqueId] = (counts[step.techniqueId] ?? 0) + 1;
    }
    final List<TechniqueId> keys = counts.keys.toList()
      ..sort((TechniqueId a, TechniqueId b) =>
          TechniqueRank.of(a).compareTo(TechniqueRank.of(b)));
    return Map<TechniqueId, int>.unmodifiable(<TechniqueId, int>{
      for (final TechniqueId key in keys) key: counts[key]!,
    });
  }

  /// 用到的最难技巧（无步骤时返回 `null`）。
  TechniqueId? hardestTechnique() {
    TechniqueId? hardest;
    int best = -1;
    for (final SolveStep step in steps) {
      final int rank = step.rank;
      if (rank > best) {
        best = rank;
        hardest = step.techniqueId;
      }
    }
    return hardest;
  }

  /// 用到的最大 rank（无步骤时返回 0）。
  int maxRank() {
    int best = 0;
    for (final SolveStep step in steps) {
      if (step.rank > best) {
        best = step.rank;
      }
    }
    return best;
  }

  @override
  String toString() =>
      'StepwiseSolveOutcome(${reason.id},steps=${steps.length},solved=$solved)';
}

/// 逐级求解器。
///
/// 无全局可变状态：注册表在构造时注入并冻结，[nextStep] / [solve] 均为纯函数式调用。
class StepwiseSolver {
  /// 构造求解器；[registry] 省略时使用 [TechniqueRegistry.defaults]。
  StepwiseSolver({TechniqueRegistry? registry})
      : registry = registry ?? TechniqueRegistry.defaults();

  /// 使用的技巧注册表。
  final TechniqueRegistry registry;

  /// 默认步数上限（81 格 × 最多 9 次候选删除，足够宽裕且能防死循环）。
  static const int defaultMaxSteps = 1000;

  /// 取**下一步**：按 rank 升序尝试已启用技巧，命中即返回；无解返回 `null`。
  ///
  /// 该方法**不修改**任何盘面，可直接用于「提示」场景。
  TechniqueResult? nextStep(SolveContext ctx) {
    for (final Technique technique in registry.enabled(ctx.ruleSet)) {
      final Iterable<TechniqueResult> found = technique.find(ctx, limit: 1);
      for (final TechniqueResult result in found) {
        if (result.isEmpty) {
          continue;
        }
        // 双保险：识别器出口已过一次 SanityGuard，此处再拦一次。
        if (!SanityGuard.isResultSafe(ctx.solution, result)) {
          continue;
        }
        return result;
      }
    }
    return null;
  }

  /// 取下一步并附带 rank / 难度等元信息；无解返回 `null`。
  SolveStep? nextSolveStep(SolveContext ctx, {int order = 1}) {
    final TechniqueResult? result = nextStep(ctx);
    if (result == null) {
      return null;
    }
    return SolveStep(
      order: order,
      result: result,
      boardBefore: ctx.board.toPuzzleString(),
    );
  }

  /// 逐级求解到底，返回完整步骤序列。
  ///
  /// - 工作在 `ctx.board.snapshot()` 副本上，**不会**改动入参盘面；
  /// - [recomputeCandidates] 为 `true`（默认）时先对副本做一次候选全量重算，
  ///   保证起点候选口径统一；玩家手工笔记场景可传 `false`。
  StepwiseSolveOutcome solve(
    SolveContext ctx, {
    int maxSteps = defaultMaxSteps,
    bool recomputeCandidates = true,
  }) {
    final Board working = ctx.board.snapshot();
    if (recomputeCandidates) {
      CandidateCalculator.recomputeAll(working);
    }
    SolveContext current = ctx.withBoard(working);

    final List<SolveStep> steps = <SolveStep>[];
    final Set<String> seenFingerprints = <String>{};

    while (true) {
      if (working.isFull) {
        return StepwiseSolveOutcome(
          board: working,
          reason: StepwiseStopReason.solved,
          steps: steps,
        );
      }
      if (steps.length >= maxSteps) {
        return StepwiseSolveOutcome(
          board: working,
          reason: StepwiseStopReason.maxStepsReached,
          steps: steps,
        );
      }

      final TechniqueResult? result = nextStep(current);
      if (result == null) {
        return StepwiseSolveOutcome(
          board: working,
          reason: StepwiseStopReason.noTechnique,
          steps: steps,
        );
      }
      if (!seenFingerprints.add(result.fingerprint)) {
        // 同一结论被重复上报 → 说明落盘没生效，立即停止防空转。
        return StepwiseSolveOutcome(
          board: working,
          reason: StepwiseStopReason.stalled,
          steps: steps,
        );
      }

      final String before = working.toPuzzleString();
      final int changed = _applyStep(working, result);
      if (changed == 0) {
        return StepwiseSolveOutcome(
          board: working,
          reason: StepwiseStopReason.stalled,
          steps: steps,
        );
      }
      steps.add(
        SolveStep(
          order: steps.length + 1,
          result: result,
          boardBefore: before,
        ),
      );
      current = current.withBoard(working);
    }
  }

  /// [solve] 的抛错版：未解出时抛 `E_SOLVE_003`。
  StepwiseSolveOutcome solveOrThrow(
    SolveContext ctx, {
    int maxSteps = defaultMaxSteps,
    bool recomputeCandidates = true,
  }) {
    final StepwiseSolveOutcome outcome = solve(
      ctx,
      maxSteps: maxSteps,
      recomputeCandidates: recomputeCandidates,
    );
    if (!outcome.solved) {
      throw CoreException(
        CoreErrorCode.solveNotLogical,
        '${outcome.reason.zhName}（已推进 ${outcome.stepCount} 步，'
        '剩余 ${outcome.board.blankCount()} 格）',
      );
    }
    return outcome;
  }

  /// 把一步结论落到 [board]，返回**实际发生改动**的条目数。
  ///
  /// 落盘顺序：先删数、后填数（填数会连带同步 peer 候选，顺序颠倒会漏删）。
  static int _applyStep(Board board, TechniqueResult result) {
    int changed = 0;
    for (final Elimination e in result.eliminations) {
      if (board.isBlank(e.cellIndex) && board.candidatesAt(e.cellIndex).contains(e.digit)) {
        board.eliminate(e.cellIndex, e.digit);
        changed++;
      }
    }
    for (final Placement p in result.placements) {
      if (!board.isBlank(p.cellIndex)) {
        continue;
      }
      if (board.isGiven(p.cellIndex)) {
        // 理论上不可能（给定格必然已填），显式兜底避免静默污染题面。
        throw CoreException(
          CoreErrorCode.boardGivenImmutable,
          '求解器试图改写给定格 ${Coord.label(p.cellIndex)}',
        );
      }
      board.forceSetValue(p.cellIndex, p.digit);
      CandidateCalculator.syncAfterPlace(board, p.cellIndex, p.digit);
      changed++;
    }
    return changed;
  }

  /// 便捷入口：由盘面直接求解（自建 [SolveContext]）。
  StepwiseSolveOutcome solveBoard(
    Board board, {
    RuleSet? ruleSet,
    List<int>? solution,
    bool uniqueSolutionGuaranteed = true,
    int maxSteps = defaultMaxSteps,
  }) =>
      solve(
        SolveContext(
          board: board,
          ruleSet: ruleSet ?? RuleSet.t2(),
          uniqueSolutionGuaranteed: uniqueSolutionGuaranteed,
          solution: solution,
        ),
        maxSteps: maxSteps,
      );

  @override
  String toString() => 'StepwiseSolver(registry=${registry.length})';
}
