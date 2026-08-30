/// 启用规则集：CLI 出题 profile、教学「已学范围」提示共用（P0-CLI-02）。
library;

import 'package:meta/meta.dart';

import 'technique_id.dart';
import 'technique_rank.dart';

/// 一组被启用的技巧标识（不可变值对象）。
@immutable
class RuleSet {
  /// 由显式集合构造（内部做不可变拷贝）。
  RuleSet(Set<TechniqueId> enabled)
      : enabled = Set<TechniqueId>.unmodifiable(<TechniqueId>{...enabled});

  /// T1 档：13 项（全部技巧减去 T2 新增的 3 项）。
  factory RuleSet.t1() => RuleSet(TechniqueRank.ofTier(TechniqueTier.t1));

  /// T2 档（**本期 scope**）：16 项全量。
  factory RuleSet.t2() => RuleSet(TechniqueId.values.toSet());

  /// rank 不超过 [maxRank] 的技巧集合（教学「已学范围」提示用）。
  factory RuleSet.upTo(int maxRank) => RuleSet(TechniqueRank.upTo(maxRank));

  /// 仅启用指定技巧（CLI `--only` / 标注集专项评测用）。
  factory RuleSet.only(Set<TechniqueId> ids) => RuleSet(ids);

  /// 空集（禁用全部技巧，用于试炼关「提示置灰」场景的显式表达）。
  factory RuleSet.none() => RuleSet(const <TechniqueId>{});

  /// 已启用的技巧标识（不可变）。
  final Set<TechniqueId> enabled;

  /// 启用数量。
  int get length => enabled.length;

  /// 是否为空集。
  bool get isEmpty => enabled.isEmpty;

  /// 是否非空。
  bool get isNotEmpty => enabled.isNotEmpty;

  /// [id] 是否被启用。
  bool allows(TechniqueId id) => enabled.contains(id);

  /// 返回追加 [ids] 后的新规则集。
  RuleSet plus(Iterable<TechniqueId> ids) => RuleSet(<TechniqueId>{...enabled, ...ids});

  /// 返回移除 [ids] 后的新规则集。
  RuleSet minus(Iterable<TechniqueId> ids) =>
      RuleSet(<TechniqueId>{...enabled}..removeAll(ids));

  /// 按 rank 升序导出。
  List<TechniqueId> sortedByRank() {
    final List<TechniqueId> list = enabled.toList()
      ..sort((TechniqueId a, TechniqueId b) =>
          TechniqueRank.of(a).compareTo(TechniqueRank.of(b)));
    return List<TechniqueId>.unmodifiable(list);
  }

  /// 导出为稳定标识列表（YAML profile / JSON 序列化用，按 rank 升序）。
  List<String> toIdList() =>
      <String>[for (final TechniqueId id in sortedByRank()) id.id];

  /// 由稳定标识列表构造；未知标识抛 `E_TECH_003`。
  static RuleSet fromIdList(Iterable<String> ids) =>
      RuleSet(<TechniqueId>{for (final String id in ids) TechniqueId.parse(id)});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleSet &&
          other.enabled.length == enabled.length &&
          other.enabled.containsAll(enabled));

  @override
  int get hashCode => Object.hashAllUnordered(enabled);

  @override
  String toString() => 'RuleSet(${toIdList().join(',')})';
}
