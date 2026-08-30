/// `EngineFacade` —— 业务层访问引擎的**唯一门面**（P0-ENG-12）。
///
/// 职责：
/// - 把 core 的 `Board`/`RuleSet` 转成纯数据任务（81 串/int），
///   交给 `IsolateEngineService` 在独立 Isolate 执行；
/// - 把结果还原成 core 值对象（`GradingReport`/`Puzzle`/`TechniqueResult`）；
/// - 用 `LoadingGate` 统一包裹：>300ms 上抛 loading；
/// - 超时降级（架构 §7.5）：提示扫描 5s、生成/评级 10s，
///   超时上报 `E_SOLVE_003` 语义（`AppError`）。
///
/// ⚠️ 本层**不含任何算法实现**，算法唯一来源是 `sudoku_core`。
library;

import 'dart:async';

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';

import 'engine_task.dart';
import 'isolate_engine_service.dart';
import 'loading_gate.dart';

/// 引擎门面。
class EngineFacade {
  /// 构造门面。
  EngineFacade({
    required this.service,
    LoadingGate? loadingGate,
  }) : _loadingGate = loadingGate;

  /// 底层 Isolate 调度服务。
  final IsolateEngineService service;

  /// 加载闸门（可为空，测试时直连服务）。
  final LoadingGate? _loadingGate;

  /// 评级超时。
  static const Duration kGradeTimeout = Duration(seconds: 10);

  /// 单次生成超时。
  static const Duration kGenerateTimeout = Duration(seconds: 10);

  /// 提示扫描超时。
  static const Duration kHintTimeout = Duration(seconds: 5);

  /// 难度评级。
  Future<GradingReport> grade(Board board, {RuleSet? ruleSet}) =>
      _guard(() async {
        final EngineResult result = await service
            .runTask((int taskId, int generation) => GradeTask(
                  taskId: taskId,
                  generation: generation,
                  puzzle81: board.toPuzzleString(),
                  givenMask81: _mask81(board),
                  ruleSetIds: _ruleSetIds(ruleSet),
                  uniqueGuaranteed: true,
                ))
            .timeout(kGradeTimeout, onTimeout: _timeout('难度评级超时'));
        return _asGrade(result);
      });

  /// 生成一道唯一解谜题（同 seed 必可复现）。
  Future<Puzzle> generatePuzzle({
    required int seed,
    int targetGivens = 30,
    String symmetryId = 'none',
    bool requireExactTarget = false,
  }) =>
      _guard(() async {
        final EngineResult result = await service
            .runTask((int taskId, int generation) => GenerateTask(
                  taskId: taskId,
                  generation: generation,
                  seed: seed,
                  targetGivens: targetGivens,
                  symmetryId: symmetryId,
                  requireExactTarget: requireExactTarget,
                ))
            .timeout(kGenerateTimeout, onTimeout: _timeout('谜题生成超时'));
        if (result is! GenerateResult) {
          throw _errorOf(result);
        }
        return Puzzle(
          given: Board.fromPuzzleString(
            result.puzzle81,
            markGivens: false,
          ).toValueList(),
          solution: <int>[
            for (final String ch in result.solution81.split('')) int.parse(ch),
          ],
          seed: seed,
        );
      });

  /// 提示扫描：返回当前盘面按规则集可用的**下一步**技巧；无可用返回 `null`。
  Future<TechniqueResult?> scanHint(
    Board board, {
    RuleSet? ruleSet,
    String? solution81,
  }) =>
      _guard(() async {
        final EngineResult result = await service
            .runTask((int taskId, int generation) => HintScanTask(
                  taskId: taskId,
                  generation: generation,
                  puzzle81: board.toPuzzleString(),
                  givenMask81: _mask81(board),
                  solution81: solution81,
                  candidateMasks81: _completeCandidateMasks(board),
                  ruleSetIds: _ruleSetIds(ruleSet),
                  maxSteps: 1,
                ))
            .timeout(kHintTimeout, onTimeout: _timeout('提示扫描超时'));
        if (result is! HintScanResult) {
          throw _errorOf(result);
        }
        final Map<String, Object?>? json = result.techniqueJson;
        return json == null ? null : TechniqueResult.fromJson(json);
      });

  // ------------------------------------------------------------ 内部

  /// 加载闸门包裹（超阈值上抛 loading）。
  Future<T> _guard<T>(Future<T> Function() action) {
    final LoadingGate? gate = _loadingGate;
    return gate == null ? action() : gate.run(action);
  }

  /// given 掩码 81 串（`1` = 给定格）。
  static String _mask81(Board board) =>
      board.givenMask.map((bool g) => g ? '1' : '0').join();

  /// 返回可安全延续的完整候选盘面；只要任一空格尚无候选，就视为用户仅写了
  /// 零散笔记，交由 worker 从数值盘面全量重算，避免零散笔记制造伪技巧。
  static List<int>? _completeCandidateMasks(Board board) {
    bool hasBlank = false;
    for (int i = 0; i < kCellCount; i++) {
      if (board.isFilled(i)) {
        continue;
      }
      hasBlank = true;
      if (board.candidateMasks[i] == 0) {
        return null;
      }
    }
    return hasBlank ? List<int>.of(board.candidateMasks) : null;
  }

  /// 规则集 → 技巧 ID 列表（空规则集默认全量 T2，worker 侧处理）。
  static List<String> _ruleSetIds(RuleSet? ruleSet) => <String>[
        for (final TechniqueId id in (ruleSet ?? RuleSet.t2()).enabled) id.id,
      ];

  /// 超时 → `AppError`（架构 §7.5：超时上报 `E_SOLVE_003` 并降级）。
  static Future<Never> Function() _timeout(String what) => () async {
        throw AppError('E_SOLVE_003', '$what：请稍后重试');
      };

  static GradingReport _asGrade(EngineResult result) {
    if (result is! GradeResult) {
      throw _errorOf(result);
    }
    return _reportFromJson(result.reportJson);
  }

  static AppError _errorOf(EngineResult result) => result is EngineErrorResult
      ? IsolateEngineService.toAppError(result)
      : AppError('E_ENGINE_002', '引擎返回了意外的结果类型');

  /// 由 `GradingReport.toJson()` 重建（worker 侧产物，类型必合法）。
  static GradingReport _reportFromJson(Map<String, Object?> json) {
    final List<TechniqueId> used = <TechniqueId>[];
    final Object? rawUsed = json['usedTechniques'];
    if (rawUsed is List) {
      for (final Object? id in rawUsed) {
        final TechniqueId? technique = TechniqueId.tryParse(id! as String);
        if (technique != null) {
          used.add(technique);
        }
      }
    }
    final Map<TechniqueId, int> usage = <TechniqueId, int>{};
    final Object? rawUsage = json['usageCounts'];
    if (rawUsage is Map) {
      for (final MapEntry<Object?, Object?> e in rawUsage.entries) {
        final TechniqueId? id = TechniqueId.tryParse(e.key! as String);
        if (id != null) {
          usage[id] = e.value! as int;
        }
      }
    }
    final Object? hardest = json['hardestTechnique'];
    return GradingReport(
      difficulty: Difficulty.tryParse(json['difficulty']! as String) ??
          Difficulty.beginner,
      solved: (json['solved'] as bool?) ?? false,
      reason: _reasonOf((json['reason'] as String?) ?? 'no_technique'),
      stepCount: (json['stepCount'] as int?) ?? 0,
      maxRank: (json['maxRank'] as int?) ?? 0,
      hardestTechnique: hardest is String ? TechniqueId.parse(hardest) : null,
      usedTechniques: used,
      usageCounts: usage,
    );
  }

  static StepwiseStopReason _reasonOf(String id) {
    for (final StepwiseStopReason reason in StepwiseStopReason.values) {
      if (reason.id == id) {
        return reason;
      }
    }
    return StepwiseStopReason.noTechnique;
  }
}
