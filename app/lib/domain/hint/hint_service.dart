/// 提示服务 —— 分级、逐级解锁、配额（P0-PRA-04 / P0-EDU-04，T-DOM-05）。
///
/// 设计（验收逐条对应）：
/// - **分级**：自由练习两级 / 教学三级（[HintRules.maxLevelOf]）；
/// - **逐级解锁不可跳级**：服务内部按场景维护已解锁最高级，
///   `requestNext()` 自动取「已解锁 + 1」，请求只能逐级推进；
/// - **任何级别都不告知某格填几**：对 `EngineFacade.scanHint` 返回的
///   [TechniqueResult] 按级别**裁剪**——
///   - 一级：技巧名 + 模式格高亮（剔除 eliminations / target / strike）；
///   - 二级：点明关键格（仍无删数与填数语义）；
///   - 三级：只保留删数结论 [Elimination]（候选删除，仍非填数），
///     纯填数技巧（如唯一余数）无删数可给时返回 `null`（无可用结论）；
///   - [HintState] 类型层面不含 [Placement]（专项测试断言）；
/// - **配额** `关闭/3/5/不限`：默认不限；每次**成功**请求消耗一次配额，
///   配额耗尽后 `requestNext` 返回 `null`（UI 提示「配额已用尽」）。
library;

import 'package:sudoku_tutor/core/core.dart';

import '../storage/models/settings_models.dart';
import 'hint_level.dart';
import 'hint_state.dart';

/// 提示扫描函数签名（默认注入 `EngineFacade.scanHint`，测试可注入假实现）。
typedef HintScanFn = Future<TechniqueResult?> Function(
  Board board, {
  RuleSet? ruleSet,
  String? solution81,
});

/// 最近一次提示请求不可用的原因，供 UI 给出可操作反馈。
enum HintUnavailableReason {
  quotaOff,
  quotaExhausted,
  noTechnique,
  maxLevelReached,
  noSafeDetail,
}

/// 面向玩家的不可用原因说明。
extension HintUnavailableReasonText on HintUnavailableReason {
  /// 简体中文说明。
  String get zhMessage => switch (this) {
        HintUnavailableReason.quotaOff => '提示已在设置中关闭',
        HintUnavailableReason.quotaExhausted => '本局提示次数已用尽',
        HintUnavailableReason.noTechnique => '当前盘面暂未找到可用技巧，请先检查是否有填错',
        HintUnavailableReason.maxLevelReached => '当前这一步的提示已全部展开；继续解题后可提示下一步',
        HintUnavailableReason.noSafeDetail => '为避免直接泄露答案，本步提示已到最详细级别',
      };
}

/// 提示服务。
class HintService {
  /// 构造提示服务；[scan] 为底层引擎扫描（Provider 装配时传
  /// `engineFacade.scanHint`），测试注入确定性结果。
  HintService({required HintScanFn scan}) : _scan = scan;

  final HintScanFn _scan;

  /// 各场景已解锁的最高级别（0 = 未解锁）。
  final Map<HintScope, int> _unlockedMax = <HintScope, int>{};

  /// 各场景当前推理步骤的指纹。
  final Map<HintScope, String> _sceneFingerprints = <HintScope, String>{};

  /// 当前对局已消耗的提示次数（配额计数）。
  int _usedCount = 0;

  /// 最近一次失败的具体原因；成功请求后为 `null`。
  HintUnavailableReason? lastUnavailableReason;

  /// 已消耗的提示次数。
  int get usedCount => _usedCount;

  /// 剩余可用次数（[HintQuota.unlimited] 返回一个大数）。
  int remainingOf(HintQuota quota) =>
      quota.isUnlimited ? HintQuota.unlimited.count : quota.count - _usedCount;

  /// 某场景已解锁的最高级别（0 = 尚未解锁）。
  int unlockedLevelOf(HintScope scope) => _unlockedMax[scope] ?? 0;

  /// 请求一次提示（下一级）。
  ///
  /// - 配额不允许 → 返回 `null`；
  /// - 已达本场景最高级别 → 返回 `null`（已解锁满）；
  /// - 引擎扫描无可用技巧 → 返回 `null`；
  /// - 三级且技巧无删数结论（纯填数技巧）→ 返回 `null`（不降级直出答案）。
  ///
  /// 成功时消耗一次配额并推进解锁级别。
  Future<HintState?> requestNext({
    required Board board,
    required List<int>? solution,
    required HintScope scope,
    required HintQuota quota,
  }) async {
    lastUnavailableReason = null;
    if (!_quotaAllows(quota)) {
      lastUnavailableReason = quota == HintQuota.off
          ? HintUnavailableReason.quotaOff
          : HintUnavailableReason.quotaExhausted;
      return null;
    }

    final TechniqueResult? result = await _scan(
      board,
      ruleSet: RuleSet.t2(),
      solution81: solution?.join(),
    );
    if (result == null || result.isEmpty) {
      lastUnavailableReason = HintUnavailableReason.noTechnique;
      return null;
    }

    // 盘面推进后会产生新的结论指纹。新推理步骤必须从一级重新开始，
    // 不能沿用上一推理步骤已经解锁的二/三级提示。
    if (_sceneFingerprints[scope] != result.fingerprint) {
      _sceneFingerprints[scope] = result.fingerprint;
      _unlockedMax[scope] = 0;
    }

    final int nextOrder = unlockedLevelOf(scope) + 1;
    final HintLevel? level = HintRules.ofOrder(nextOrder);
    if (level == null || nextOrder > HintRules.maxLevelOf(scope)) {
      lastUnavailableReason = HintUnavailableReason.maxLevelReached;
      return null;
    }

    final HintState? hint = _clip(level, scope, result);
    if (hint == null) {
      lastUnavailableReason = HintUnavailableReason.noSafeDetail;
      return null;
    }
    _usedCount++;
    _unlockedMax[scope] = nextOrder;
    return hint;
  }

  /// 新对局/新关重置配额与解锁进度。
  void resetForNewRound() {
    _usedCount = 0;
    _unlockedMax.clear();
    _sceneFingerprints.clear();
    lastUnavailableReason = null;
  }

  /// 重置某场景的解锁进度（如重新进入本关）。
  void resetUnlockedForScope(HintScope scope) {
    _unlockedMax.remove(scope);
    _sceneFingerprints.remove(scope);
    lastUnavailableReason = null;
  }

  // ------------------------------------------------------------ 内部

  /// 配额是否允许本次请求。
  bool _quotaAllows(HintQuota quota) => switch (quota) {
        HintQuota.off => false,
        HintQuota.three => _usedCount < HintQuota.three.count,
        HintQuota.five => _usedCount < HintQuota.five.count,
        HintQuota.unlimited => true,
      };

  /// 按级别裁剪引擎结果；无可用内容返回 `null`。
  HintState? _clip(HintLevel level, HintScope scope, TechniqueResult result) {
    final TechniqueId techniqueId = result.techniqueId;
    final List<int> involved = result.involvedCells();
    switch (level) {
      case HintLevel.level1:
        return HintState(
          level: level,
          scope: scope,
          techniqueId: techniqueId,
          narration: '此处可运用「${techniqueId.zhName}」，相关区域已高亮。',
          highlightedCells: involved,
          eliminations: const <Elimination>[],
          visual: _clipVisual(level, result.visual),
          sceneFingerprint: result.fingerprint,
        );
      case HintLevel.level2:
        return HintState(
          level: level,
          scope: scope,
          techniqueId: techniqueId,
          narration: '「${techniqueId.zhName}」的关键格已标出：${_cellsLabel(involved)}。',
          highlightedCells: involved,
          eliminations: const <Elimination>[],
          visual: _clipVisual(level, result.visual),
          sceneFingerprint: result.fingerprint,
        );
      case HintLevel.level3:
        final List<Elimination> eliminations = result.eliminations;
        if (eliminations.isEmpty) {
          // 纯填数技巧（如唯一余数）无删数结论可给 → 不直出答案。
          return null;
        }
        return HintState(
          level: level,
          scope: scope,
          techniqueId: techniqueId,
          narration: '可删去：${NarrationFormat.elimList(<MapEntry<int, int>>[
                for (final Elimination e in eliminations)
                  MapEntry<int, int>(e.cellIndex, e.digit),
              ])}。',
          highlightedCells: involved,
          eliminations: eliminations,
          visual: _clipVisual(level, result.visual),
          sceneFingerprint: result.fingerprint,
        );
    }
  }

  /// 可视化裁剪：
  /// - 各级都**不泄露「填几」语义**：`target`（结论目标格）统一降级为
  ///   `pattern`（模式高亮）保留——相关格仍然高亮，但形状从「角标结论格」
  ///   变为普通模式高亮，不透露该格就是答案格；
  /// - 一级/二级剔除 `elimination`（删数格/划除），不透露删数结论；
  /// - 三级保留删数语义（划除），但同样无 `target` 角色（专项测试断言）。
  VisualHint _clipVisual(HintLevel level, VisualHint visual) {
    final bool includeElimination = level == HintLevel.level3;
    return VisualHint(
      cells: <CellMark>[
        for (final CellMark mark in visual.cells)
          if (includeElimination || mark.role != MarkRole.elimination)
            CellMark(
              index: mark.index,
              role: mark.role == MarkRole.target ? MarkRole.pattern : mark.role,
              shape: mark.role == MarkRole.target
                  ? ShapeCode.defaultShapeOf(MarkRole.pattern)
                  : mark.shape,
              focusDigits: mark.focusDigits,
            ),
      ],
      regions: visual.regions,
      links: visual.links,
      candidateMarks: <CandidateMark>[
        for (final CandidateMark mark in visual.candidateMarks)
          if (mark.kind == CandidateMarkKind.emphasize ||
              (includeElimination && mark.kind == CandidateMarkKind.strike))
            mark,
      ],
    );
  }

  /// 涉及格的中文坐标标签。
  static String _cellsLabel(List<int> cells) =>
      cells.map(Coord.zhLabel).join('、');
}
