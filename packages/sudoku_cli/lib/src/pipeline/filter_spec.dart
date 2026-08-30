/// 出题管线筛选条件表达（doc 06 §3.2 `lib/src/pipeline/filter_spec.dart`）。
///
/// 支持条件（与 doc 06 时序图 5.3 对齐）：
/// - 目标技巧**必须出现**（[requiredTechniques] 全部命中，或 [anyRequiredTechniques] 至少一个）；
/// - 技巧**禁止出现**（[bannedTechniques] 任一命中即剔除）；
/// - 难度**区间 / 精确档**（[minDifficulty] / [maxDifficulty] / [exactDifficulty]）。
///
/// 纯数据对象：可序列化，供 `--concurrency` 分片跨 Isolate 传递。
library;

import 'package:sudoku_core/sudoku_core.dart';

import '../model/annotated_puzzle.dart';

/// 题库筛选条件（不可变）。
class FilterSpec {
  /// 构造筛选条件；各集合做不可变拷贝。
  FilterSpec({
    Set<TechniqueId> requiredTechniques = const <TechniqueId>{},
    Set<TechniqueId> anyRequiredTechniques = const <TechniqueId>{},
    Set<TechniqueId> bannedTechniques = const <TechniqueId>{},
    this.minDifficulty,
    this.maxDifficulty,
    this.exactDifficulty,
  })  : requiredTechniques =
            Set<TechniqueId>.unmodifiable(requiredTechniques),
        anyRequiredTechniques =
            Set<TechniqueId>.unmodifiable(anyRequiredTechniques),
        bannedTechniques = Set<TechniqueId>.unmodifiable(bannedTechniques);

  /// 必须**全部**出现的技巧（交集语义）。
  final Set<TechniqueId> requiredTechniques;

  /// 必须**至少出现一个**的技巧（并集语义）。
  final Set<TechniqueId> anyRequiredTechniques;

  /// 禁止出现的技巧（任一命中即剔除）。
  final Set<TechniqueId> bannedTechniques;

  /// 难度下限（含）。
  final Difficulty? minDifficulty;

  /// 难度上限（含）。
  final Difficulty? maxDifficulty;

  /// 精确难度档（与区间同时存在时以精确档为准）。
  final Difficulty? exactDifficulty;

  /// 是否不施加任何条件（恒真）。
  bool get isEmpty =>
      requiredTechniques.isEmpty &&
      anyRequiredTechniques.isEmpty &&
      bannedTechniques.isEmpty &&
      exactDifficulty == null &&
      minDifficulty == null &&
      maxDifficulty == null;

  /// 判定 [puzzle] 是否通过本筛选。
  bool matches(AnnotatedPuzzle puzzle) {
    if (puzzle.techniques.isEmpty && !_hasTechniqueConditions()) {
      // 题面未标注时只看难度条件；标注过但用到的技巧集合为空则直接不匹配技巧条件。
      return _matchesDifficulty(puzzle);
    }
    for (final TechniqueId id in requiredTechniques) {
      if (!puzzle.techniques.contains(id)) {
        return false;
      }
    }
    if (anyRequiredTechniques.isNotEmpty) {
      bool hit = false;
      for (final TechniqueId id in anyRequiredTechniques) {
        if (puzzle.techniques.contains(id)) {
          hit = true;
          break;
        }
      }
      if (!hit) {
        return false;
      }
    }
    for (final TechniqueId id in bannedTechniques) {
      if (puzzle.techniques.contains(id)) {
        return false;
      }
    }
    return _matchesDifficulty(puzzle);
  }

  bool _hasTechniqueConditions() =>
      requiredTechniques.isNotEmpty ||
      anyRequiredTechniques.isNotEmpty ||
      bannedTechniques.isNotEmpty;

  bool _matchesDifficulty(AnnotatedPuzzle puzzle) {
    final Difficulty? difficulty = puzzle.difficulty;
    if (difficulty == null) {
      // 未标注难度的题，仅在没有任何难度条件时视为通过。
      return exactDifficulty == null && minDifficulty == null && maxDifficulty == null;
    }
    if (exactDifficulty != null) {
      return difficulty == exactDifficulty;
    }
    if (minDifficulty != null && difficulty.index < minDifficulty!.index) {
      return false;
    }
    if (maxDifficulty != null && difficulty.index > maxDifficulty!.index) {
      return false;
    }
    return true;
  }

  /// 序列化为 JSON map（跨 Isolate / 报表用）。
  Map<String, Object?> toJson() => <String, Object?>{
        'requiredTechniques': <String>[
          for (final TechniqueId id in requiredTechniques) id.id,
        ],
        'anyRequiredTechniques': <String>[
          for (final TechniqueId id in anyRequiredTechniques) id.id,
        ],
        'bannedTechniques': <String>[
          for (final TechniqueId id in bannedTechniques) id.id,
        ],
        'minDifficulty': minDifficulty?.id,
        'maxDifficulty': maxDifficulty?.id,
        'exactDifficulty': exactDifficulty?.id,
      };

  /// 由 JSON map 反序列化（与 [toJson] 往返一致）。
  static FilterSpec fromJson(Map<String, Object?> json) => FilterSpec(
        requiredTechniques: _parseIds(json['requiredTechniques']),
        anyRequiredTechniques: _parseIds(json['anyRequiredTechniques']),
        bannedTechniques: _parseIds(json['bannedTechniques']),
        minDifficulty: Difficulty.tryParse(json['minDifficulty'] as String? ?? ''),
        maxDifficulty: Difficulty.tryParse(json['maxDifficulty'] as String? ?? ''),
        exactDifficulty:
            Difficulty.tryParse(json['exactDifficulty'] as String? ?? ''),
      );

  static Set<TechniqueId> _parseIds(Object? raw) => <TechniqueId>{
        for (final Object? item in (raw as List<Object?>?) ?? const <Object?>[])
          TechniqueId.parse(item! as String),
      };

  @override
  String toString() => 'FilterSpec(req=${requiredTechniques.length},'
      'any=${anyRequiredTechniques.length},ban=${bannedTechniques.length},'
      'exact=${exactDifficulty?.id ?? "-"})';
}
