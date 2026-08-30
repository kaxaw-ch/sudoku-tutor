/// 误操作即时纠正检测器（T-EDU-04 / P0-EDU-05）。
///
/// 三类触发（全覆盖）：
/// - (a) [MistakeType.wrongFill]：填入与终局解不符的数字；
/// - (b) [MistakeType.deletedTrueCandidate]：删除终局解中为真的候选
///      （手动笔记模式下删除候选、或清空候选且该格真值候选在其中）；
/// - (c) [MistakeType.prematureFill]：目标技巧触发态下用非目标手段抢先填数。
///
/// (c) 的实现判定（规则注释，任务给定口径）：
///   「该格在脚本中的预期技巧步之前被非脚本方式填入」——
///   对一次填对的 place move，在关卡脚本中找**最早包含该格相同填数的
///   目标技巧步骤** `stepK`（`stepK.techniqueId ∈ targetTechniques`）；
///   若 `stepK` 之前（`steps[0..K-1]`）的**所有 placement 尚未在当前盘面
///   就位**，则判定玩家在技巧可触发前抢先填数，触发 (c)。
///   注：只针对关卡 techniqueTags（目标技巧）步骤判定，非目标技巧铺垫步
///   允许玩家自由填数，避免过度打扰。
///
/// 去重（P0-EDU-05）：**同一关同一错误 2 分钟内不重复弹**——
/// 以「类型 + 格 + 数字」为指纹，两次同类错误间隔 < 2 分钟则返回 `null`。
/// 进入新关调用 [resetForLevel] 清空时间戳。
library;

import 'package:sudoku_tutor/core/core.dart';

/// 误操作类型。
enum MistakeType {
  /// (a) 填入与终局解不符。
  wrongFill('wrongFill', '填错数字'),

  /// (b) 删除终局解中为真的候选。
  deletedTrueCandidate('deletedTrueCandidate', '误删候选'),

  /// (c) 目标技巧触发态下抢先填数。
  prematureFill('prematureFill', '抢先填数');

  const MistakeType(this.id, this.zhName);

  /// 稳定标识（文案 JSON 分类键）。
  final String id;

  /// 简体中文名。
  final String zhName;
}

/// 一次检测的上下文（盘面为**操作应用前**的当前状态）。
class MistakeContext {
  /// 构造检测上下文。
  const MistakeContext({
    required this.board,
    required this.solution,
    required this.noteMode,
    required this.script,
    required this.targetTechniques,
    this.enablePrematureFill = true,
  });

  /// 当前盘面（move 尚未应用）。
  final Board board;

  /// 终局解（`null` = 无终局解，无法判定）。
  final List<int>? solution;

  /// 是否手动笔记模式（(b) 只在笔记模式下判定 clear 候选）。
  final bool noteMode;

  /// 关卡解题脚本（(c) 判定锚点）。
  final SolutionScript? script;

  /// 关卡目标技巧标签（(c) 只对目标技巧步骤判定）。
  final Set<TechniqueId> targetTechniques;

  /// 是否启用 (c) 抢先填数判定（试炼关关闭：C-06 不校验技巧）。
  final bool enablePrematureFill;
}

/// 一次误操作事件（UI 弹窗消费）。
class MistakeEvent {
  /// 构造误操作事件。
  const MistakeEvent({
    required this.type,
    required this.cellIndex,
    required this.digit,
    required this.fingerprint,
    this.techniqueId,
  });

  /// 触发类型。
  final MistakeType type;

  /// 相关格索引。
  final int cellIndex;

  /// 相关数字（填错/删候选的目标数字）。
  final int digit;

  /// 相关技巧（(c) 为被抢答的目标技巧；(a)/(b) 为 `null`）。
  final TechniqueId? techniqueId;

  /// 去重指纹（`type:cell:digit`，含技巧时附加技巧 id）。
  final String fingerprint;
}

/// 误操作检测器（带 2 分钟去重）。
class MistakeDetector {
  /// 构造检测器；[now] 可注入时钟（测试确定性去重判定）。
  MistakeDetector({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// 2 分钟去重窗口（P0-EDU-05）。
  static const Duration kDedupeWindow = Duration(minutes: 2);

  final DateTime Function() _now;

  /// 上次弹窗时间戳（指纹 → epoch 毫秒）。
  final Map<String, int> _lastShownAt = <String, int>{};

  /// 检测一次输入操作；无错误 / 2 分钟内重复 → 返回 `null`。
  MistakeEvent? detect(Move move, MistakeContext ctx) {
    final List<int>? solution = ctx.solution;
    if (solution == null || solution.length != kCellCount) {
      return null;
    }
    switch (move.type) {
      case MoveType.place:
        return _detectPlace(move, ctx, solution);
      case MoveType.removeCandidate:
        // (b) 删除终局解中为真的候选。
        if (solution[move.cellIndex] == move.digit) {
          return _emit(
              MistakeType.deletedTrueCandidate, move.cellIndex, move.digit);
        }
        return null;
      case MoveType.addCandidate:
        return null; // 添加候选不是错误。
      case MoveType.clear:
        return _detectClear(move, ctx, solution);
      case MoveType.autoFillCandidates:
        return null; // 自动填写候选属于辅助操作，不判为误操作。
    }
  }

  /// 新关开始时重置去重时间戳。
  void resetForLevel() => _lastShownAt.clear();

  // ------------------------------------------------------------ 检测

  MistakeEvent? _detectPlace(
      Move move, MistakeContext ctx, List<int> solution) {
    final int cell = move.cellIndex;
    final int digit = move.digit;
    if (solution[cell] != digit) {
      // (a) 填错。
      return _emit(MistakeType.wrongFill, cell, digit);
    }
    // 填对 → 检查 (c) 抢先填数。
    if (ctx.enablePrematureFill) {
      final MistakeEvent? premature = _checkPremature(move, ctx);
      if (premature != null) {
        return premature;
      }
    }
    return null;
  }

  MistakeEvent? _detectClear(
      Move move, MistakeContext ctx, List<int> solution) {
    final int cell = move.cellIndex;
    if (ctx.board.isFilled(cell)) {
      // 清除已填数属于纠错/修正，不算误操作。
      return null;
    }
    // (b) 手动笔记模式下清空候选，若真值候选被一并删掉 → 误删。
    if (ctx.noteMode && ctx.board.candidatesAt(cell).contains(solution[cell])) {
      return _emit(MistakeType.deletedTrueCandidate, cell, solution[cell]);
    }
    return null;
  }

  /// (c) 抢先填数判定（规则见文件头注释）。
  ///
  /// ⚠️ 用户实测修复：仅「脚本前序未就位」就报会误伤——玩家可能用
  /// **其它推理路径**（如该格当前可由唯一余数推出）先填对，此时有推理
  /// 支撑，不应判「抢先」。因此前序未就位时，先检查当前盘面能否凭
  /// 推理推出该格（[MistakeDetector._hasReasoningSupport]）：
  /// 能推出 → 不打扰；推不出（纯猜测/试错）→ 触发 (c)。
  MistakeEvent? _checkPremature(Move move, MistakeContext ctx) {
    final SolutionScript? script = ctx.script;
    if (script == null || script.steps.isEmpty) {
      return null;
    }
    for (int k = 0; k < script.steps.length; k++) {
      final ScriptStep step = script.steps[k];
      // 只对「目标技巧」步骤判定（C-06 语义：只约束本关要学的技巧）。
      if (!ctx.targetTechniques.contains(step.techniqueId)) {
        continue;
      }
      final bool hasPlacement = step.placements.any(
        (Placement p) => p.cellIndex == move.cellIndex && p.digit == move.digit,
      );
      if (!hasPlacement) {
        continue;
      }
      // 该格本应由 stepK 得出：检查前 K 步 placements 是否已在盘面上就位。
      bool allPrior = true;
      for (int j = 0; j < k; j++) {
        for (final Placement p in script.steps[j].placements) {
          if (ctx.board.valueAt(p.cellIndex) != p.digit) {
            allPrior = false;
            break;
          }
        }
        if (!allPrior) {
          break;
        }
      }
      if (allPrior) {
        // 前序结论已满足 → 正常推进（不触发）。
        return null;
      }
      // 前序未满足：若当前盘面能凭推理推出该格 → 有推理支撑，不打扰。
      if (_hasReasoningSupport(ctx, move.cellIndex, move.digit)) {
        return null;
      }
      return _emit(
        MistakeType.prematureFill,
        move.cellIndex,
        move.digit,
        techniqueId: step.techniqueId,
      );
    }
    return null;
  }

  /// 当前盘面能否凭内置技巧（含基础）推理推出 (cell, digit)。
  ///
  /// 用 StepwiseSolver 从当前盘面逐步求解（t2 规则集），检查该格
  /// 是否出现在任意一步的 placement 中。全解 55 步盘面约 1-2ms，
  /// 实操关每次输入调用一次可接受。
  bool _hasReasoningSupport(MistakeContext ctx, int cell, int digit) {
    try {
      final SolveContext sctx = SolveContext(
        board: ctx.board,
        ruleSet: RuleSet.t2(),
        solution: ctx.solution,
      );
      final StepwiseSolveOutcome outcome =
          StepwiseSolver().solve(sctx, maxSteps: 80);
      for (final SolveStep step in outcome.steps) {
        for (final Placement p in step.result.placements) {
          if (p.cellIndex == cell && p.digit == digit) {
            return true;
          }
        }
      }
    } on Object {
      // 求解异常视为无支撑（保守触发提示，不静默吞掉教学约束）。
    }
    return false;
  }

  // ------------------------------------------------------------ 去重

  /// 组装事件并做 2 分钟去重；重复时返回 `null`。
  MistakeEvent? _emit(
    MistakeType type,
    int cellIndex,
    int digit, {
    TechniqueId? techniqueId,
  }) {
    final String fp = type == MistakeType.prematureFill && techniqueId != null
        ? '${type.id}:$cellIndex:$digit:${techniqueId.id}'
        : '${type.id}:$cellIndex:$digit';
    final int nowMs = _now().millisecondsSinceEpoch;
    final int? last = _lastShownAt[fp];
    if (last != null && nowMs - last < kDedupeWindow.inMilliseconds) {
      return null; // 同一关同一错误 2 分钟内不重复弹。
    }
    _lastShownAt[fp] = nowMs;
    return MistakeEvent(
      type: type,
      cellIndex: cellIndex,
      digit: digit,
      techniqueId: techniqueId,
      fingerprint: fp,
    );
  }
}
