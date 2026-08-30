/// 解题脚本回放器（T-CORE-09：T-QA-05 回放校验的地基）。
///
/// 职责：把关卡 JSON 中预置的解题脚本 [SolutionScript]，从初始盘面开始
/// **逐级回放**：每步都调引擎（[StepwiseSolver.nextStep]）计算"当前盘面下引擎
/// 实际会报的技巧/删数/填数"，与脚本声明的该步比对——
/// - 技巧识别结果（技巧 ID）是否一致；
/// - 删数集合是否一致；
/// - 填数集合是否一致；
/// - 脚本结论能否在盘面上真实应用（候选存在 / 格未填 / 不与终局解冲突）；
/// - 脚本终态是否解满且与终局解一致。
///
/// 任何一步不一致即产生一条 [ReplayMismatch]（含步骤号 + 期望 vs 实际），
/// **绝不静默放过**；这正对 doc 07 T-QA-05「任意一步不一致即失败」。
///
/// 校验策略（严格/宽松）：
/// - [strictTechnique] 默认 `true`：技巧 ID 必须一致、删数/填数**集合相等**；
/// - 传 `false` 时：不校验技巧 ID，删数/填数只要求**脚本声明 ⊆ 引擎实际结论**
///   （容忍引擎同一步报出更多结论，如合并步骤）。
///
/// 应用侧铁律：回放**应用脚本声明**的结论（先删后填），使脚本自身的缺陷
/// （哪怕删数/填数键值被人工改错）必然在后续推进与终态检查中暴露。
library;

import 'package:meta/meta.dart';

import '../engine/candidate_calculator.dart';
import '../engine/stepwise_solver.dart';
import '../engine/validator.dart';
import '../model/board.dart';
import '../model/board_codec.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../puzzle/level_model.dart';
import '../puzzle/solution_script.dart';
import '../techniques/rule_set.dart';
import '../techniques/solve_context.dart';
import '../techniques/technique_result.dart';
import '../util/core_error.dart';

/// 一条回放不一致（步骤号 + 期望 vs 实际）。
@immutable
class ReplayMismatch {
  /// 构造不一致记录。
  const ReplayMismatch({
    required this.order,
    required this.kind,
    required this.expected,
    required this.actual,
    required this.message,
  });

  /// 出现不一致的步骤号（脚本 `order`；终态检查为脚本步数 + 1）。
  final int order;

  /// 不一致类别。
  final ReplayMismatchKind kind;

  /// 期望（脚本声明）。
  final String expected;

  /// 实际（引擎结果/盘面状态）。
  final String actual;

  /// 可读描述（简体中文）。
  final String message;

  @override
  String toString() =>
      '[第 $order 步 ${kind.id}] $message（期望：$expected；实际：$actual）';
}

/// 不一致类别。
enum ReplayMismatchKind {
  /// 技巧识别不一致（技巧 ID 或引擎无可用技巧）。
  technique('technique', '技巧识别'),

  /// 删数集合不一致。
  elimination('elimination', '删数'),

  /// 填数集合不一致。
  placement('placement', '填数'),

  /// 删数无法在盘面上应用。
  applyElimination('apply_elimination', '删数应用'),

  /// 填数无法应用（格已填 / 改写给定格 / 与终局解冲突）。
  applyPlacement('apply_placement', '填数应用'),

  /// 终态检查失败（未解满 / 与终局解不一致）。
  finalState('final_state', '终态');

  const ReplayMismatchKind(this.id, this.zhName);

  /// 稳定标识。
  final String id;

  /// 简体中文名。
  final String zhName;
}

/// 一次回放的完整产出。
@immutable
class ScriptReplayOutcome {
  /// 构造回放产出。
  ScriptReplayOutcome({
    required this.verifiedSteps,
    required List<ReplayMismatch> mismatches,
  }) : mismatches = List<ReplayMismatch>.unmodifiable(mismatches);

  /// 已逐级校验并应用的步数。
  final int verifiedSteps;

  /// 不一致清单（为空即全过）。
  final List<ReplayMismatch> mismatches;

  /// 是否全部通过。
  bool get passed => mismatches.isEmpty;

  /// 不一致数。
  int get mismatchCount => mismatches.length;

  @override
  String toString() => 'ScriptReplayOutcome(verified=$verifiedSteps, '
      'mismatches=$mismatchCount${passed ? "，通过" : "，未通过"})';
}

/// 脚本回放器（无全局可变状态，纯函数式调用）。
@immutable
class ScriptReplayer {
  /// 构造回放器；[registry] 省略时使用引擎默认注册表（16 项技巧）。
  ScriptReplayer({StepwiseSolver? solver})
      : _solver = solver ?? StepwiseSolver();

  final StepwiseSolver _solver;

  /// 回放一关（[LessonLevel] 必须携带题面/终局解与脚本）。
  ///
  /// 使用 `RuleSet.t2()`（全部 16 项技巧）作为默认规则集，与 CLI 标注管线对齐。
  ScriptReplayOutcome replayLevel(
    LessonLevel level, {
    RuleSet? ruleSet,
    bool strictTechnique = true,
  }) {
    if (level.script == null) {
      throw CoreException(
        CoreErrorCode.importFormat,
        '关卡 ${level.id} 无解题脚本，无法回放',
      );
    }
    return replay(
      puzzle81: level.puzzle81,
      solution81: level.solution81,
      script: level.script!,
      ruleSet: ruleSet,
      strictTechnique: strictTechnique,
    );
  }

  /// 逐级回放解题脚本。
  ///
  /// - [puzzle81] 题面 81 字符串，[solution81] 终局解 81 字符串；
  /// - [ruleSet] 省略时用 `RuleSet.t2()`；
  /// - [strictTechnique] 见文件头说明。
  ScriptReplayOutcome replay({
    required String puzzle81,
    required String solution81,
    required SolutionScript script,
    RuleSet? ruleSet,
    bool strictTechnique = true,
  }) {
    final RuleSet rules = ruleSet ?? RuleSet.t2();
    final List<int> solution = _decodeSolution(solution81);
    final Board state = _buildBoard(puzzle81);
    // 统一候选口径：与引擎 StepwiseSolver.solve 的 recomputeCandidates=true 一致。
    CandidateCalculator.recomputeAll(state);

    final List<ReplayMismatch> mismatches = <ReplayMismatch>[];
    int verified = 0;

    for (final ScriptStep step in script.steps) {
      final int order = step.order;
      SolveContext ctx = SolveContext(
        board: state,
        ruleSet: rules,
        uniqueSolutionGuaranteed: true,
        solution: solution,
      );

      // ---- 0) 技巧是否在规则集内 ----
      if (!rules.allows(step.techniqueId)) {
        mismatches.add(
          ReplayMismatch(
            order: order,
            kind: ReplayMismatchKind.technique,
            expected: step.techniqueId.id,
            actual: '(不在规则集内)',
            message: '技巧 ${step.techniqueId.id} 不在当前规则集内',
          ),
        );
      }

      // ---- 1) 技巧识别一致性：调引擎求"当前盘面下下一步实际结果" ----
      final TechniqueResult? engineNext = _solver.nextStep(ctx);
      if (engineNext == null) {
        mismatches.add(
          ReplayMismatch(
            order: order,
            kind: ReplayMismatchKind.technique,
            expected: step.techniqueId.id,
            actual: '(无可用技巧)',
            message: '引擎在当前盘面无可用技巧，但脚本声称本步使用 ${step.techniqueId.id}',
          ),
        );
      } else {
        _verifyTechnique(step, engineNext, order, strictTechnique, mismatches);
      }

      // ---- 2) 应用脚本声明（先删后填），推进盘面 ----
      // ⚠️ 与引擎 `StepwiseSolver._applyStep` 的增量口径一致：eliminate + syncAfterPlace，
      // **不做全量 recomputeAll**（会抹掉 eliminate 的持久效果，导致后续步骤候选错位）。
      _applyStep(step, state, solution, order, mismatches);

      verified++;
    }

    // ---- 3) 终态检查 ----
    if (!state.isFull) {
      mismatches.add(
        ReplayMismatch(
          order: script.steps.length + 1,
          kind: ReplayMismatchKind.finalState,
          expected: '(满盘 81 格)',
          actual: '(剩 ${state.blankCount()} 格)',
          message: '脚本未解满盘面',
        ),
      );
    } else if (state.toPuzzleString() != solution81) {
      mismatches.add(
        ReplayMismatch(
          order: script.steps.length + 1,
          kind: ReplayMismatchKind.finalState,
          expected: solution81,
          actual: state.toPuzzleString(),
          message: '脚本终态与终局解不一致',
        ),
      );
    }

    return ScriptReplayOutcome(verifiedSteps: verified, mismatches: mismatches);
  }

  // ------------------------------------------------------------ 校验

  void _verifyTechnique(
    ScriptStep step,
    TechniqueResult engineNext,
    int order,
    bool strictTechnique,
    List<ReplayMismatch> mismatches,
  ) {
    // 技巧 ID。
    if (strictTechnique && engineNext.techniqueId != step.techniqueId) {
      mismatches.add(
        ReplayMismatch(
          order: order,
          kind: ReplayMismatchKind.technique,
          expected: step.techniqueId.id,
          actual: engineNext.techniqueId.id,
          message: '技巧识别不一致',
        ),
      );
    }

    // 删数集合。
    final List<Elimination> expectedElims = step.eliminations;
    final List<Elimination> actualElims = engineNext.eliminations;
    if (!_conclusionsMatch(expectedElims, actualElims, strictTechnique)) {
      final List<Elimination> missing = <Elimination>[
        for (final Elimination e in expectedElims)
          if (!_containsElim(actualElims, e)) e,
      ];
      final List<Elimination> extra = <Elimination>[
        for (final Elimination e in actualElims)
          if (!_containsElim(expectedElims, e)) e,
      ];
      mismatches.add(
        ReplayMismatch(
          order: order,
          kind: ReplayMismatchKind.elimination,
          expected: _formatElims(expectedElims),
          actual: _formatElims(actualElims),
          message: '删数不一致'
              '${missing.isEmpty ? "" : "：脚本多声明 ${_formatElims(missing)}"}'
              '${extra.isEmpty ? "" : "；引擎多出 ${_formatElims(extra)}"}',
        ),
      );
    }

    // 填数集合。
    final List<Placement> expectedPlaces = step.placements;
    final List<Placement> actualPlaces = engineNext.placements;
    if (!_conclusionsMatch(expectedPlaces, actualPlaces, strictTechnique)) {
      final List<Placement> missing = <Placement>[
        for (final Placement p in expectedPlaces)
          if (!_containsPlace(actualPlaces, p)) p,
      ];
      final List<Placement> extra = <Placement>[
        for (final Placement p in actualPlaces)
          if (!_containsPlace(expectedPlaces, p)) p,
      ];
      mismatches.add(
        ReplayMismatch(
          order: order,
          kind: ReplayMismatchKind.placement,
          expected: _formatPlaces(expectedPlaces),
          actual: _formatPlaces(actualPlaces),
          message: '填数不一致'
              '${missing.isEmpty ? "" : "：脚本多声明 ${_formatPlaces(missing)}"}'
              '${extra.isEmpty ? "" : "；引擎多出 ${_formatPlaces(extra)}"}',
        ),
      );
    }
  }

  /// 结论比较：严格 = 集合相等；宽松 = 期望 ⊆ 实际。
  static bool _conclusionsMatch(
    List<Object> expected,
    List<Object> actual,
    bool strictTechnique,
  ) {
    if (strictTechnique) {
      if (expected.length != actual.length) {
        return false;
      }
      for (final Object e in expected) {
        if (!actual.contains(e)) {
          return false;
        }
      }
      return true;
    }
    for (final Object e in expected) {
      if (!actual.contains(e)) {
        return false;
      }
    }
    return true;
  }

  static bool _containsElim(List<Elimination> list, Elimination target) =>
      list.any((Elimination e) => e.cellIndex == target.cellIndex && e.digit == target.digit);

  static bool _containsPlace(List<Placement> list, Placement target) =>
      list.any((Placement p) => p.cellIndex == target.cellIndex && p.digit == target.digit);

  static String _formatElims(List<Elimination> list) => list.isEmpty
      ? '(无)'
      : <String>[for (final Elimination e in list) e.label].join('、');

  static String _formatPlaces(List<Placement> list) => list.isEmpty
      ? '(无)'
      : <String>[for (final Placement p in list) p.label].join('、');

  // ------------------------------------------------------------ 应用

  void _applyStep(
    ScriptStep step,
    Board state,
    List<int> solution,
    int order,
    List<ReplayMismatch> mismatches,
  ) {
    for (final Elimination e in step.eliminations) {
      if (state.isBlank(e.cellIndex) && state.candidatesAt(e.cellIndex).contains(e.digit)) {
        state.eliminate(e.cellIndex, e.digit);
      } else {
        mismatches.add(
          ReplayMismatch(
            order: order,
            kind: ReplayMismatchKind.applyElimination,
            expected: e.label,
            actual: '(候选不存在或格已填)',
            message: '删数无法应用：${e.label}',
          ),
        );
      }
    }
    for (final Placement p in step.placements) {
      if (!state.isBlank(p.cellIndex)) {
        mismatches.add(
          ReplayMismatch(
            order: order,
            kind: ReplayMismatchKind.applyPlacement,
            expected: p.label,
            actual: '(格已填)',
            message: '填数无法应用：${p.label}（该格已填）',
          ),
        );
        continue;
      }
      if (state.isGiven(p.cellIndex)) {
        mismatches.add(
          ReplayMismatch(
            order: order,
            kind: ReplayMismatchKind.applyPlacement,
            expected: p.label,
            actual: '(给定格)',
            message: '试图改写给定格：${p.label}',
          ),
        );
        continue;
      }
      if (solution[p.cellIndex] != p.digit) {
        mismatches.add(
          ReplayMismatch(
            order: order,
            kind: ReplayMismatchKind.applyPlacement,
            expected: p.label,
            actual: '${Coord.label(p.cellIndex)} 填 ${solution[p.cellIndex]}',
            message: '填数与终局解不符：${p.label}',
          ),
        );
      }
      state.forceSetValue(p.cellIndex, p.digit);
      CandidateCalculator.syncAfterPlace(state, p.cellIndex, p.digit);
    }
  }

  // ------------------------------------------------------------ 构造

  static Board _buildBoard(String puzzle81) {
    final List<int> given = BoardCodec.decodeValues(puzzle81);
    return Board.fromValues(given, givenMask: <bool>[
      for (final int v in given) v != kEmptyValue,
    ]);
  }

  static List<int> _decodeSolution(String solution81) {
    final List<int> solution = BoardCodec.decodeValues(solution81);
    if (!Validator.isValidSolution(solution)) {
      throw CoreException(
        CoreErrorCode.solveNoSolution,
        '终局解非法（含冲突）',
      );
    }
    return solution;
  }
}
