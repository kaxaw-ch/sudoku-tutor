/// **T-QA-03 · 健全性模糊测试（P0-QA-03，⛔ 硬门槛）**
///
/// 验收标准：
/// - 默认 **10,000 道**随机唯一解谜题（`targetGivens` 在 22~36 间轮换，
///   覆盖从低提示数高难度到高提示数低难度）；
/// - 每道题跑 **全部 16 项技巧**（t2 规则集）：主推进链路逐级推进 +
///   覆盖窗口（前 40 局）每步对 16 个识别器做全扫体检；
/// - 核心断言：任何 `Elimination` 的删数**绝不允许等于该格终局解**（E_TECH_001）；
///   任何 `Placement` 的填数**必须等于**终局解；
/// - **零失败**。
///
/// 两条互补路径（缺一不可）：
/// 1. **裸奔逐级推进**（[SolveContext.solution] 传 `null`）：识别器不知道答案，
///   出口 `TechniqueSupport.emit` 不会过滤（`sanity_guard.dart`），任何误删/误填
///   都会原样产出，由**外部**持有的终局解逐条复核 —— 真正抓识别器误报；
/// 2. **端到端全链路**（`StepwiseSolver.solve` 带真实终局解）：验证产品最终路径
///   「识别器 → emit 过滤 → solver 双保险 → 落盘」结论安全、链路不卡死。
///
/// 局数控制（CI 快速模式）：
/// - 环境变量 `SUDOKU_FUZZ_FAST=1` → 快速模式 **1,000** 局；
/// - 否则默认 **10,000** 局（主测试体）。
///   推荐命令：
///   - CI 仅跑模糊测试：`SUDOKU_FUZZ_FAST=1 dart test --tags fuzz`
///   - CI 全量含既有用例：`SUDOKU_FUZZ_FAST=1 dart test`
///   - 本地完整验证：`dart test`（10,000 局）
///   - 也可直接改下方 `kFuzzRounds` / `kFastRounds` 常量。
///
/// 可复现性：全部随机走固定 seed（`kBaseSeed + 题号`），失败信息携带 seed/题号，
/// 一键复现。主测试分 10 片，避免单测超时；分片不改变断言强度。
@Tags(['fuzz'])
library;

import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------- 常量开关

/// 主测试局数（默认 10,000）。
const int kFuzzRounds = 10000;

/// CI 快速模式局数。
const int kFastRounds = 1000;

/// 覆盖窗口：前 N 局做「每步全扫全部 16 识别器」的加强体检
/// （其余局走与真实求解器一致的「逐级推进 + 复核」链路）。
const int kFullScanRounds = 40;

/// 题面提示数轮换范围（含两端，覆盖不同难度）。
const int kTargetGivensMin = 22;
const int kTargetGivensMax = 36;

/// 固定 base seed：第 i 题 seed = `kBaseSeed + i`，全量可复现。
const int kBaseSeed = 20260805;

/// 单题裸奔推进的步数上限（81 格 × 9 候选足够宽裕）。
const int kMaxStepsPerPuzzle = 300;

/// 分片数：10,000 局分 10 片，每片 ~1,000 局，规避单测默认超时。
const int kShards = 10;

// ---------------------------------------------------------------- 运行时状态

/// 实际生效局数：环境变量 `SUDOKU_FUZZ_FAST=1` 时切快速模式。
final int _rounds = Platform.environment['SUDOKU_FUZZ_FAST'] == '1'
    ? kFastRounds
    : kFuzzRounds;

/// 每片局数（向上取整保证总量达标）。
final int _perShard = (_rounds / kShards).ceil();

const PuzzleGenerator _generator = PuzzleGenerator();
final TechniqueRegistry _registry = TechniqueRegistry.defaults();
final RuleSet _ruleSet = RuleSet.t2();

/// 逐级求解停止原因计数（端到端链路健康度统计，非断言）。
final Map<StepwiseStopReason, int> _stopCounts =
    <StepwiseStopReason, int>{};

/// 裸奔推进中累计触发的技巧（统计用）。
final Set<TechniqueId> _exercisedByPropagation = <TechniqueId>{};

/// 端到端链路中累计触发的技巧（统计用）。
final Set<TechniqueId> _exercisedBySolver = <TechniqueId>{};

// ---------------------------------------------------------------- 辅助函数

/// 把一条结论落到盘面，返回实际改动条目数（等价于 StepwiseSolver 的私有落盘逻辑）。
int _applyResult(Board board, TechniqueResult result) {
  int changed = 0;
  for (final Elimination e in result.eliminations) {
    if (board.isBlank(e.cellIndex) &&
        board.candidatesAt(e.cellIndex).contains(e.digit)) {
      board.eliminate(e.cellIndex, e.digit);
      changed++;
    }
  }
  for (final Placement p in result.placements) {
    if (!board.isBlank(p.cellIndex)) {
      continue;
    }
    board.forceSetValue(p.cellIndex, p.digit);
    CandidateCalculator.syncAfterPlace(board, p.cellIndex, p.digit);
    changed++;
  }
  return changed;
}

/// 违规细节描述（seed / 题号 / 技巧 / 步号 / 盘面，便于复现）。
String _describeViolation(
  int seed,
  int step,
  Board board,
  TechniqueResult result,
  SanityViolation violation,
) =>
    '\nseed=$seed（第 ${seed - kBaseSeed} 题）'
    '\n步号=$step'
    '\n技巧=${result.techniqueId.id}(${result.techniqueId.zhName})'
    '\n违规=${violation.zhDescription}'
    '\n结论指纹=${result.fingerprint}'
    '\n复现盘面=${board.toPuzzleString(emptyChar: "0")}';

/// 用**外部持有的终局解**复核一条结论：任何删数不得等于终局解、
/// 任何填数必须等于终局解；且结论必须自带完整 visual / narration 载荷。
void _checkResultAgainstSolution(
  int seed,
  int step,
  Board board,
  List<int> solution,
  TechniqueResult result,
) {
  final List<SanityViolation> violations =
      SanityGuard.collectViolations(solution, result);
  expect(
    violations,
    isEmpty,
    reason: violations.isEmpty
        ? null
        : _describeViolation(seed, step, board, result, violations.first),
  );
  expect(result.visual.isNotEmpty, isTrue,
      reason: 'seed=$seed ${result.techniqueId.id} 结论缺少 visual');
  expect(result.narration.slots.isNotEmpty, isTrue,
      reason: 'seed=$seed ${result.techniqueId.id} 结论缺少 narration');
}

/// 取「下一步」结论：与真实求解器同构 —— 按 rank 升序逐识别器扫描，命中即返。
///
/// - [fullScan] 为 true 时改为**全扫**：16 个识别器全部扫描（`limit: 8`），
///   收集所有非空结论逐条复核，再推进第一条 —— 覆盖窗口模式；
/// - [fullScan] 为 false 时仅取第一条（solver 语义），每条结论同样复核 ——
///   主推进链路模式。
TechniqueResult? _nextResult(
  int seed,
  int step,
  Board board,
  List<int> solution, {
  required bool fullScan,
  required Set<TechniqueId> exercised,
}) {
  final SolveContext ctx = SolveContext(board: board, ruleSet: _ruleSet);
  TechniqueResult? next;
  if (fullScan) {
    for (final Technique technique in _registry.sorted) {
      for (final TechniqueResult result in technique.find(ctx, limit: 8)) {
        if (result.isEmpty) {
          continue;
        }
        exercised.add(result.techniqueId);
        _checkResultAgainstSolution(seed, step, board, solution, result);
        next ??= result;
      }
    }
  } else {
    outer:
    for (final Technique technique in _registry.sorted) {
      for (final TechniqueResult result in technique.find(ctx, limit: 1)) {
        if (result.isEmpty) {
          continue;
        }
        exercised.add(result.techniqueId);
        _checkResultAgainstSolution(seed, step, board, solution, result);
        next = result;
        break outer;
      }
    }
  }
  return next;
}

/// 单题健全性体检。返回裸奔推进中真实触发过的技巧集合。
Set<TechniqueId> _auditPuzzle(int puzzleNo, {required bool fullScan}) {
  final int seed = kBaseSeed + puzzleNo;
  final int targetGivens =
      kTargetGivensMin + puzzleNo % (kTargetGivensMax - kTargetGivensMin + 1);

  final Puzzle puzzle = _generator.generate(
    Rng(seed),
    targetGivens: targetGivens,
    requireExactTarget: true,
  );
  final List<int> solution = puzzle.solution;

  // 题面有效性：唯一解 + 提示数落在预期区间。
  expect(
    puzzle.givenCount,
    inInclusiveRange(kTargetGivensMin, kTargetGivensMax),
    reason: 'seed=$seed 提示数 ${puzzle.givenCount} 超出 $kTargetGivensMin..'
        '$kTargetGivensMax\n题面=${puzzle.givenString}',
  );
  final Board givenBoard = puzzle.toGivenBoard();
  CandidateCalculator.recomputeAll(givenBoard);
  expect(
    _generator.isUnique(givenBoard),
    isTrue,
    reason: 'seed=$seed 生成器产出了非唯一解题面\n题面=${puzzle.givenString}',
  );

  // ---- 路径 A：裸奔逐级推进（识别器不知道答案，emit 不过滤）----
  final Set<TechniqueId> exercised = <TechniqueId>{};
  final Board board = puzzle.toGivenBoard();
  CandidateCalculator.recomputeAll(board);
  final Set<String> appliedFingerprints = <String>{};
  for (int step = 0; step < kMaxStepsPerPuzzle; step++) {
    final TechniqueResult? next =
        _nextResult(seed, step, board, solution,
            fullScan: fullScan, exercised: exercised);
    if (next == null) {
      break; // 当前规则集下再无可用技巧。
    }
    if (!appliedFingerprints.add(next.fingerprint)) {
      break; // 同一结论重复上报，防空转。
    }
    if (_applyResult(board, next) == 0) {
      break; // 无实际改动，防空转。
    }
    // 每步之后，各格候选必须是「全量重算结果」的子集：
    // 技巧删数只会让候选变少，绝不允许凭空多出候选。
    for (final int index in board.blankCells()) {
      final CandidateSet actual = board.candidatesAt(index);
      final CandidateSet geometric =
          CandidateCalculator.candidatesFor(board, index);
      expect(geometric.containsAll(actual), isTrue,
          reason: 'seed=$seed 第 $step 步后 ${Coord.label(index)} '
              '出现了几何上不可能的候选');
    }
    if (board.isFull) {
      break;
    }
  }
  // 总闸：已填格必须全部等于终局解。
  for (int i = 0; i < kCellCount; i++) {
    if (board.valueAt(i) != kEmptyValue) {
      expect(board.valueAt(i), equals(solution[i]),
          reason: 'seed=$seed 裸奔推进在 ${Coord.label(i)} 填错数字 '
              '\n复现盘面=${board.toPuzzleString(emptyChar: "0")}');
    }
  }
  // 总闸：剩余空格候选必须保留正确答案（未被误删）。
  for (final int index in board.blankCells()) {
    expect(
      board.candidatesAt(index).contains(solution[index]),
      isTrue,
      reason: 'seed=$seed ${Coord.label(index)} 的正确答案 '
          '${solution[index]} 被误删'
          '\n复现盘面=${board.toPuzzleString(emptyChar: "0")}',
    );
  }

  // ---- 路径 B：端到端全链路（StepwiseSolver.solve 带真实终局解）----
  final StepwiseSolveOutcome outcome = StepwiseSolver().solve(
    SolveContext(
      board: puzzle.toGivenBoard(),
      ruleSet: _ruleSet,
      uniqueSolutionGuaranteed: true,
      solution: solution,
    ),
  );
  _stopCounts[outcome.reason] = (_stopCounts[outcome.reason] ?? 0) + 1;
  for (final SolveStep step in outcome.steps) {
    _exercisedBySolver.add(step.techniqueId);
    _checkResultAgainstSolution(seed, step.order, outcome.board, solution,
        step.result);
  }
  // 全链路结束盘面：已填格必须等于终局解（空格候选不再强求，
  // 因为带 solution 的求解器在无技巧时合法停于半途）。
  for (int i = 0; i < kCellCount; i++) {
    if (outcome.board.valueAt(i) != kEmptyValue) {
      expect(outcome.board.valueAt(i), equals(solution[i]),
          reason: 'seed=$seed 端到端链路在 ${Coord.label(i)} 填错数字'
              '\n复现盘面=${outcome.board.toPuzzleString(emptyChar: "0")}');
    }
  }

  _exercisedByPropagation.addAll(exercised);
  return exercised;
}

// ---------------------------------------------------------------- 主测试体

void main() {
  group('T-QA-03 健全性模糊测试（rounds=$_rounds, seedBase=$kBaseSeed, '
      'givens=$kTargetGivensMin..$kTargetGivensMax）', () {
    for (int shard = 0; shard < kShards; shard++) {
      final int start = shard * _perShard;
      final int end = (start + _perShard) > _rounds
          ? _rounds
          : start + _perShard;
      if (start >= end) {
        continue;
      }
      test(
        '[$shard/$kShards] 第 ${start + 1}~$end 题逐级推进零误报',
        () {
          for (int i = start; i < end; i++) {
            _auditPuzzle(i, fullScan: i < kFullScanRounds);
          }
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }

    test(
      '覆盖率自检：全扫覆盖窗口内真实触发全部 16 项技巧',
      () {
        final Set<TechniqueId> covered = <TechniqueId>{};
        for (int i = 0; i < kFullScanRounds; i++) {
          covered.addAll(_auditPuzzle(i, fullScan: true));
        }
        final Set<TechniqueId> missed =
            TechniqueId.values.toSet().difference(covered);
        expect(
          missed,
          isEmpty,
          reason: '以下技巧在覆盖窗口（前 $kFullScanRounds 局全扫）中从未被'
              '真实触发，零误报结论对它们不成立：'
              '${missed.map((TechniqueId t) => t.id).join("、")}',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      '统计摘要（非断言，供 CI 日志与人工核查）',
      () {
        final StringBuffer buffer = StringBuffer()
          ..writeln('T-QA-03 统计：局数=$_rounds')
          ..writeln('端到端停止原因: '
              '${_stopCounts.entries.map((e) => "${e.key.id}=${e.value}").join("，")}')
          ..writeln('裸奔推进触发技巧 '
              '${_exercisedByPropagation.length}/${TechniqueId.values.length}: '
              '${_exercisedByPropagation.map((TechniqueId t) => t.id).toList()..sort()}');
        stdout.write(buffer.toString());
      },
    );
  });
}
