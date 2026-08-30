/// 出题管线：生成 → 标注 → 筛选 → 去重 的编排器（doc 06 §3.2 / 时序图 5.3）。
///
/// 铁律与设计（doc 07 T-CLI-02）：
/// - **零算法实现**：生成/唯一解/逐级求解/分级/指纹全部 import `sudoku_core`；
/// - `--concurrency`：按轮把剩余目标切成若干片，每片跑在独立 Isolate
///   （`Isolate.run`），片间 seed 区间不重叠，整体结果**可复现**；
/// - 同 seed 可复现：片内第 k 次尝试 seed = 片基址 + k，基址由
///   `(baseSeed, round, sliceIndex)` 确定派生；`Future.wait` 按声明顺序
///   收结果，合并顺序确定；
/// - 去重：片内先去重，合并时再全局去重（跨片可能同构）。
library;

import 'dart:async';
import 'dart:isolate';

import 'package:sudoku_core/sudoku_core.dart';

import '../config/cli_config.dart';
import '../io/progress_reporter.dart';
import '../model/annotated_puzzle.dart';
import 'dedup.dart';
import 'filter_spec.dart';

/// 一次出题管线的完整结果（供命令层落盘与报表）。
class PipelineRunResult {
  /// 构造结果。
  PipelineRunResult({
    required this.stats,
    required List<AnnotatedPuzzle> puzzles,
    required this.baseSeed,
    required this.profile,
    required this.filter,
    required this.concurrency,
  }) : puzzles = List<AnnotatedPuzzle>.unmodifiable(puzzles);

  /// 统计漏斗。
  final PipelineStats stats;

  /// 最终收录（去重后）。
  final List<AnnotatedPuzzle> puzzles;

  /// 入口种子。
  final int baseSeed;

  /// 使用的 profile。
  final ProfileSpec profile;

  /// 使用的筛选条件。
  final FilterSpec filter;

  /// 并发数。
  final int concurrency;

  /// 是否达到目标数量。
  bool get isComplete => puzzles.length >= stats.targetCount;

  /// 序列化为 JSON map（`--report` 落盘 / 测试断言用）。
  Map<String, Object?> toReportJson() => <String, Object?>{
        'baseSeed': baseSeed,
        'profile': profile.name,
        'ruleSet': profile.ruleSet.toIdList(),
        'filter': filter.toJson(),
        'concurrency': concurrency,
        'stats': stats.toJson(),
        'puzzleCount': puzzles.length,
        'puzzles': <Map<String, Object?>>[
          for (final AnnotatedPuzzle puzzle in puzzles) puzzle.toJson(),
        ],
      };
}

/// 出题管线编排器。
class GenerationPipeline {
  /// 构造管线；[reporter] 可选（用于控制台进度反馈）。
  GenerationPipeline({ProgressReporter? reporter}) : _reporter = reporter;

  final ProgressReporter? _reporter;

  /// 防空转的最大轮数（命中率极低档兜底，防止死循环）。
  static const int kMaxRounds = 200;

  /// 每片尝试预算的 seed 区间宽度（片基址步进，防止片间 seed 重叠）。
  static const int kSliceSeedStride = 100000;

  /// 片内超发系数：给全局去重留余量（命中率低时片内难以填满，超发无副作用）。
  static const double kSliceOverflowFactor = 1.5;

  /// 运行整条管线。
  ///
  /// [targetCount] 目标收录数；[maxAttempts] 全局生成尝试总预算；
  /// [targetGivens] 挖洞目标提示数；[minTargetGivens] 自适应降洞的下限
  /// （命中率不足时管线会自动把提示数下调 2，直到该下限）；
  /// [annotate] 为 `false` 时只生成不求解（`generate` 命令用，
  /// 命中率统计口径为「唯一解成功」）。
  Future<PipelineRunResult> run({
    required int targetCount,
    required int baseSeed,
    required ProfileSpec profile,
    required FilterSpec filter,
    required int maxAttempts,
    required int targetGivens,
    required int concurrency,
    required bool annotate,
    int minTargetGivens = PuzzleGenerator.kMinGivens,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final List<AnnotatedPuzzle> accepted = <AnnotatedPuzzle>[];
    final Dedup globalDedup = Dedup();
    int attempts = 0;
    int uniqueOk = 0;
    int solvable = 0;
    int matched = 0;
    final Map<TechniqueId, int> usageCounts = <TechniqueId, int>{};
    final Map<Difficulty, int> difficultyCounts = <Difficulty, int>{};

    int round = 0;
    int remainingBudget = maxAttempts;
    int effectiveGivens = targetGivens;
    bool anyNew = false;

    while (accepted.length < targetCount &&
        remainingBudget > 0 &&
        round < kMaxRounds) {
      round++;
      final int remaining = targetCount - accepted.length;
      final int slices =
          concurrency <= 1 ? 1 : (concurrency < remaining ? concurrency : remaining);
      final int perSliceBudget =
          (remainingBudget / slices).ceil().clamp(1, remainingBudget);

      _reporter?.progress(
        '第 $round 轮：并发 $slices，预算 $perSliceBudget/片，'
        '已收录 ${accepted.length}/$targetCount，提示数 $effectiveGivens',
      );

      final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
      for (int i = 0; i < slices; i++) {
        requests.add(
          _buildSliceRequest(
            sliceIndex: i,
            round: round,
            baseSeed: baseSeed,
            profile: profile,
            filter: filter,
            sliceTarget: (_sliceQuota(remaining, slices) * kSliceOverflowFactor)
                .ceil(),
            maxAttempts: perSliceBudget,
            targetGivens: effectiveGivens,
            annotate: annotate,
          ),
        );
      }

      final List<Map<String, Object?>> rawResults;
      if (slices == 1) {
        // 单片走同步路径，避免无谓的 Isolate 开销。
        rawResults = <Map<String, Object?>>[runGenerationSlice(requests.single)];
      } else {
        rawResults = await Future.wait(<Future<Map<String, Object?>>>[
          for (final Map<String, Object?> request in requests)
            Isolate.run<Map<String, Object?>>(
                () => runGenerationSlice(request)),
        ]);
      }

      outer:
      for (final Map<String, Object?> raw in rawResults) {
        final _SliceResult slice = _SliceResult.fromJson(raw);
        attempts += slice.attempts;
        uniqueOk += slice.uniqueOk;
        solvable += slice.solvable;
        matched += slice.matched;
        for (final AnnotatedPuzzle puzzle in slice.puzzles) {
          if (globalDedup.add(puzzle.fingerprint)) {
            accepted.add(puzzle);
            for (final MapEntry<TechniqueId, int> e in puzzle.usageCounts.entries) {
              usageCounts[e.key] = (usageCounts[e.key] ?? 0) + e.value;
            }
            final Difficulty difficulty =
                puzzle.difficulty ?? Difficulty.master;
            difficultyCounts[difficulty] =
                (difficultyCounts[difficulty] ?? 0) + 1;
            anyNew = true;
            if (accepted.length >= targetCount) {
              break outer; // 达到目标即停，超发部分丢弃，保证 count 精确。
            }
          }
        }
      }

      final int usedBudget = perSliceBudget * slices;
      remainingBudget =
          (remainingBudget - usedBudget).clamp(0, remainingBudget);

      if (!anyNew) {
        // 一轮零新增 → 命中率不足：优先自适应下调提示数以逼近目标档（风险 A-06）。
        if (effectiveGivens > minTargetGivens) {
          effectiveGivens = (effectiveGivens - 2).clamp(minTargetGivens, 81);
          _reporter?.progress(
            '本轮零新增，提示数 $effectiveGivens 仍不足，'
            '自动下调挖洞目标到 $effectiveGivens 继续',
          );
          anyNew = false;
          continue; // 不终止，用更低提示数再试一轮。
        }
        _reporter?.warn('连续一轮无新增收录，提前终止（命中率不足或同构率高）');
        break;
      }
      anyNew = false;
    }

    final PipelineStats stats = PipelineStats(
      targetCount: targetCount,
      attempts: attempts,
      uniqueOk: uniqueOk,
      solvable: solvable,
      matched: matched,
      accepted: accepted.length,
      elapsedMs: stopwatch.elapsedMilliseconds,
      usageCounts: usageCounts,
      difficultyCounts: difficultyCounts,
    );

    if (accepted.length < targetCount) {
      _reporter?.warn(
        '尝试预算 $maxAttempts 次后仅收录 ${accepted.length}/$targetCount 道'
        '（命中率不足，建议增大 --max-attempts 或放宽筛选条件）',
      );
    }

    return PipelineRunResult(
      stats: stats,
      puzzles: accepted,
      baseSeed: baseSeed,
      profile: profile,
      filter: filter,
      concurrency: concurrency,
    );
  }

  /// 本轮该片应承担的配额（向上取整，公平分配剩余目标）。
  static int _sliceQuota(int remaining, int slices) =>
      (remaining / slices).ceil();

  /// 构造一片的请求（纯数据，可跨 Isolate 发送）。
  Map<String, Object?> _buildSliceRequest({
    required int sliceIndex,
    required int round,
    required int baseSeed,
    required ProfileSpec profile,
    required FilterSpec filter,
    required int sliceTarget,
    required int maxAttempts,
    required int targetGivens,
    required bool annotate,
  }) =>
      <String, Object?>{
        // seed 基址 = baseSeed + round×步进 + sliceIndex×步进，片间不重叠。
        'sliceSeed':
            baseSeed + round * kSliceSeedStride + sliceIndex * kSliceSeedStride,
        'sliceIndex': sliceIndex,
        'target': sliceTarget,
        'maxAttempts': maxAttempts,
        'targetGivens': targetGivens,
        'symmetry': profile.symmetry.id,
        'ruleSetMode': profile.ruleSetMode.id,
        'customIds': List<String>.of(profile.customIds),
        'filter': filter.toJson(),
        'annotate': annotate,
      };
}

/// 一片的产出（纯数据，可跨 Isolate 发送）。
class _SliceResult {
  /// 构造片结果。
  _SliceResult({
    required this.attempts,
    required this.uniqueOk,
    required this.solvable,
    required this.matched,
    required List<AnnotatedPuzzle> puzzles,
  }) : puzzles = List<AnnotatedPuzzle>.unmodifiable(puzzles);

  final int attempts;
  final int uniqueOk;
  final int solvable;
  final int matched;
  final List<AnnotatedPuzzle> puzzles;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'attempts': attempts,
        'uniqueOk': uniqueOk,
        'solvable': solvable,
        'matched': matched,
        'puzzles': <Map<String, Object?>>[
          for (final AnnotatedPuzzle puzzle in puzzles) puzzle.toJson(),
        ],
      };

  /// 由 JSON map 反序列化。
  static _SliceResult fromJson(Map<String, Object?> json) => _SliceResult(
        attempts: json['attempts']! as int,
        uniqueOk: json['uniqueOk']! as int,
        solvable: json['solvable']! as int,
        matched: json['matched']! as int,
        puzzles: <AnnotatedPuzzle>[
          for (final Object? item
              in (json['puzzles'] as List<Object?>?) ?? const <Object?>[])
            AnnotatedPuzzle.fromJson(item! as Map<String, Object?>),
        ],
      );
}

/// 对一道已生成题逐级求解标注；超出规则集不可解时返回 `null`。
///
/// 纯编排：唯一解校验、逐级求解、难度分级全部来自 `sudoku_core`。
AnnotatedPuzzle? annotateOne({
  required Puzzle puzzle,
  required int seed,
  required RuleSet ruleSet,
}) {
  final Board board = puzzle.toGivenBoard();
  CandidateCalculator.recomputeAll(board);
  if (!const UniquenessChecker().isUnique(board)) {
    return null;
  }
  final StepwiseSolveOutcome outcome = StepwiseSolver().solve(
    SolveContext(
      board: board,
      ruleSet: ruleSet,
      uniqueSolutionGuaranteed: true,
      solution: puzzle.solution,
    ),
  );
  if (!outcome.solved) {
    return null;
  }
  final GradingReport report = DifficultyGrader.fromOutcome(outcome);
  return assembleAnnotated(
    puzzle: puzzle,
    seed: seed,
    outcome: outcome,
    report: report,
  );
}

/// Isolate 片入口（顶层函数，闭包可发送约束下由 `Isolate.run` 调用）。
///
/// 请求与响应均为 JSON map；本函数内部构造全套 core 算法组件，
/// **无任何共享可变状态**，天然线程安全。
Map<String, Object?> runGenerationSlice(Map<String, Object?> request) {
  final int sliceSeed = request['sliceSeed']! as int;
  final int target = request['target']! as int;
  final int maxAttempts = request['maxAttempts']! as int;
  final int targetGivens = request['targetGivens']! as int;
  final String symmetryId = request['symmetry']! as String;
  final String ruleSetModeId = request['ruleSetMode']! as String;
  final List<String> customIds = <String>[
    for (final Object? v in (request['customIds'] as List<Object?>?) ??
        const <Object?>[])
      v! as String,
  ];
  final bool annotate = request['annotate']! as bool;
  final FilterSpec filter =
      FilterSpec.fromJson(request['filter']! as Map<String, Object?>);

  final SymmetryMode symmetry = SymmetryMode.values.firstWhere(
    (SymmetryMode mode) => mode.id == symmetryId,
    orElse: () => SymmetryMode.none,
  );
  final RuleSet ruleSet = switch (ruleSetModeId) {
    't1' => RuleSet.t1(),
    't2' => RuleSet.t2(),
    _ => RuleSet.fromIdList(customIds),
  };

  const PuzzleGenerator generator = PuzzleGenerator();
  const UniquenessChecker checker = UniquenessChecker();
  final StepwiseSolver solver = StepwiseSolver();
  final Dedup sliceDedup = Dedup();

  final List<AnnotatedPuzzle> puzzles = <AnnotatedPuzzle>[];
  int attempts = 0;
  int uniqueOk = 0;
  int solvable = 0;
  int matched = 0;

  for (int k = 0; k < maxAttempts && puzzles.length < target; k++) {
    final int seed = sliceSeed + k;
    attempts++;
    final Puzzle puzzle = generator.generate(
      Rng(seed),
      targetGivens: targetGivens,
      symmetry: symmetry,
    );

    AnnotatedPuzzle? annotated;
    if (annotate) {
      final Board board = puzzle.toGivenBoard();
      CandidateCalculator.recomputeAll(board);
      if (!checker.isUnique(board)) {
        continue; // 双保险：生成器已保证唯一解，此处再验一次。
      }
      uniqueOk++;
      final StepwiseSolveOutcome outcome = solver.solve(
        SolveContext(
          board: board,
          ruleSet: ruleSet,
          uniqueSolutionGuaranteed: true,
          solution: puzzle.solution,
        ),
      );
      if (!outcome.solved) {
        continue; // 超出规则集 → 丢弃（架构师口径：不可解不作大师题发布）。
      }
      solvable++;
      final GradingReport report = DifficultyGrader.fromOutcome(outcome);
      annotated = assembleAnnotated(
        puzzle: puzzle,
        seed: seed,
        outcome: outcome,
        report: report,
      );
    } else {
      if (!checker.isUnique(puzzle.toGivenBoard())) {
        continue;
      }
      uniqueOk++;
      annotated = fromPuzzleOnly(puzzle: puzzle, seed: seed);
    }
    if (!filter.matches(annotated)) {
      continue;
    }
    matched++;
    if (sliceDedup.add(annotated.fingerprint)) {
      puzzles.add(annotated);
    }
  }

  return _SliceResult(
    attempts: attempts,
    uniqueOk: uniqueOk,
    solvable: solvable,
    matched: matched,
    puzzles: puzzles,
  ).toJson();
}
