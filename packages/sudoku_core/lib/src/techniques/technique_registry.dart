/// 技巧注册表：按 rank 排序、按 [RuleSet] 过滤、扩展插槽（P0-ENG-11）。
///
/// 扩展约定（doc 06 §6.1）：新增技巧 = 新建识别器文件 + 在 [TechniqueId] 追加枚举 +
/// 在 `technique_rank.dart` 插入 rank + 在 [TechniqueRegistry.defaults] 追加一行 +
/// 在 `zh_cn_templates.dart` 追加模板 + 补正反例测试。
/// **`LogicalSolver` / `HintScanner` / `DifficultyGrader` / CLI / UI 均无需改动。**
library;

import '../util/core_error.dart';
import 'finned_x_wing.dart';
import 'hidden_single.dart';
import 'hidden_subset.dart';
import 'locked_candidates.dart';
import 'naked_single.dart';
import 'naked_subset.dart';
import 'rule_set.dart';
import 'simple_colouring.dart';
import 'swordfish.dart';
import 'technique.dart';
import 'technique_id.dart';
import 'technique_rank.dart';
import 'ur_type1.dart';
import 'ur_type2.dart';
import 'w_wing.dart';
import 'x_wing.dart';
import 'xy_wing.dart';
import 'xyz_wing.dart';

/// 技巧注册表（构造完成后按 rank 升序冻结）。
class TechniqueRegistry {
  /// 构造一个空注册表。
  TechniqueRegistry();

  /// 由一组识别器构造。
  factory TechniqueRegistry.of(Iterable<Technique> techniques) {
    final TechniqueRegistry registry = TechniqueRegistry();
    for (final Technique technique in techniques) {
      registry.register(technique);
    }
    return registry;
  }

  /// 默认注册表（批次 C 起为 16 项全量）。
  ///
  /// 新增技巧只需在 [_defaultTechniques] 追加一行，**调用方零改动**。
  factory TechniqueRegistry.defaults() => TechniqueRegistry.of(_defaultTechniques());

  /// 默认识别器清单 —— **唯一登记点**（doc 06 §6.1），按 rank 升序书写。
  static List<Technique> _defaultTechniques() => <Technique>[
        const NakedSingleTechnique(), //            rank  10
        const HiddenSingleTechnique(), //           rank  20
        const NakedSubsetTechnique(size: 2), //     rank  30 裸对
        const HiddenSubsetTechnique(size: 2), //    rank  40 隐对
        const LockedCandidatesTechnique(), //       rank  50
        const NakedSubsetTechnique(size: 3), //     rank  60 裸三
        const HiddenSubsetTechnique(size: 3), //    rank  70 隐三
        const XWingTechnique(), //                  rank  80
        const FinnedXWingTechnique(), //            rank  90 （T2）
        const SwordfishTechnique(), //              rank 100
        const XyWingTechnique(), //                 rank 110
        const XyzWingTechnique(), //                rank 120
        const WWingTechnique(), //                  rank 130（T2）
        const UrType1Technique(), //                rank 140
        const UrType2Technique(), //                rank 150
        const SimpleColouringTechnique(), //        rank 160（T2）
      ];

  final Map<TechniqueId, Technique> _byId = <TechniqueId, Technique>{};

  /// 注册一个识别器（同 id 重复注册以后者覆盖）。
  void register(Technique technique) {
    // 触发 rank / 难度表查表，未登记的技巧在此立即暴露（抛 E_TECH_003）。
    TechniqueRank.of(technique.id);
    TechniqueRank.difficultyOf(technique.id);
    _byId[technique.id] = technique;
  }

  /// 批量注册。
  void registerAll(Iterable<Technique> techniques) {
    for (final Technique technique in techniques) {
      register(technique);
    }
  }

  /// 已注册的识别器数量。
  int get length => _byId.length;

  /// 是否为空。
  bool get isEmpty => _byId.isEmpty;

  /// 是否已注册 [id]。
  bool contains(TechniqueId id) => _byId.containsKey(id);

  /// 全部识别器，按 rank 升序。
  List<Technique> get sorted {
    final List<Technique> list = _byId.values.toList()
      ..sort((Technique a, Technique b) => a.rank.compareTo(b.rank));
    return List<Technique>.unmodifiable(list);
  }

  /// 按 [rs] 过滤后的识别器，按 rank 升序（逐级求解直接遍历本列表）。
  List<Technique> enabled(RuleSet rs) => List<Technique>.unmodifiable(
        <Technique>[
          for (final Technique technique in sorted)
            if (rs.allows(technique.id)) technique,
        ],
      );

  /// 按 [id] 取识别器；未注册抛 `E_TECH_003`。
  Technique byId(TechniqueId id) {
    final Technique? technique = _byId[id];
    if (technique == null) {
      throw CoreException(CoreErrorCode.techNotRegistered, '技巧 ${id.id} 未注册');
    }
    return technique;
  }

  /// 按 [id] 取识别器；未注册返回 `null`。
  Technique? tryById(TechniqueId id) => _byId[id];

  /// 尚未注册的技巧标识（按 rank 升序），供 CI 与批次 C 进度自检。
  List<TechniqueId> missingIds() => List<TechniqueId>.unmodifiable(<TechniqueId>[
        for (final TechniqueId id in TechniqueRank.byRankAscending())
          if (!_byId.containsKey(id)) id,
      ]);

  @override
  String toString() => 'TechniqueRegistry(${_byId.length}/${TechniqueId.values.length})';
}
