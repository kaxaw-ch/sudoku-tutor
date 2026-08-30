/// 技巧识别结果：删数/填数 + 可视化数据 + 讲解参数 + 去重指纹。
library;

import 'package:meta/meta.dart';

import '../model/coord.dart';
import '../model/digit.dart';
import '../narrative/narration_params.dart';
import '../visual/visual_hint.dart';
import 'technique_id.dart';

/// 一处删数结论：从 [cellIndex] 的候选中删去 [digit]。
@immutable
class Elimination {
  /// 构造一处删数。
  Elimination(this.cellIndex, this.digit) {
    Coord.requireIndex(cellIndex);
    Digit.requireDigit(digit);
  }

  /// 目标格索引。
  final int cellIndex;

  /// 被删除的候选数字。
  final int digit;

  /// 人类可读标签，如 `r5c2 的 5`。
  String get label => '${Coord.label(cellIndex)} 的 $digit';

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'cellIndex': cellIndex,
        'digit': digit,
      };

  /// 由 JSON map 反序列化。
  static Elimination fromJson(Map<String, Object?> json) =>
      Elimination(json['cellIndex']! as int, json['digit']! as int);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Elimination && other.cellIndex == cellIndex && other.digit == digit);

  @override
  int get hashCode => Object.hash(cellIndex, digit);

  @override
  String toString() => 'Elimination($label)';
}

/// 一处填数结论：在 [cellIndex] 填入 [digit]。
@immutable
class Placement {
  /// 构造一处填数。
  Placement(this.cellIndex, this.digit) {
    Coord.requireIndex(cellIndex);
    Digit.requireDigit(digit);
  }

  /// 目标格索引。
  final int cellIndex;

  /// 要填入的数字。
  final int digit;

  /// 人类可读标签，如 `r5c2 填 5`。
  String get label => '${Coord.label(cellIndex)} 填 $digit';

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'cellIndex': cellIndex,
        'digit': digit,
      };

  /// 由 JSON map 反序列化。
  static Placement fromJson(Map<String, Object?> json) =>
      Placement(json['cellIndex']! as int, json['digit']! as int);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Placement && other.cellIndex == cellIndex && other.digit == digit);

  @override
  int get hashCode => Object.hash(cellIndex, digit);

  @override
  String toString() => 'Placement($label)';
}

/// 一次技巧识别的完整结论。
///
/// 铁律（P0-ENG-09/10）：任何非空结果都**必须**同时携带
/// [visual]（UI 零推断）与 [narration]（文案零硬编码）。
@immutable
class TechniqueResult {
  /// 构造一个识别结果；[fingerprint] 省略时自动按结论内容计算。
  TechniqueResult({
    required this.techniqueId,
    List<Elimination> eliminations = const <Elimination>[],
    List<Placement> placements = const <Placement>[],
    VisualHint? visual,
    NarrationParams? narration,
    String? fingerprint,
  })  : eliminations = List<Elimination>.unmodifiable(eliminations),
        placements = List<Placement>.unmodifiable(placements),
        visual = visual ?? VisualHint.empty(),
        narration = narration ?? NarrationParams(techniqueId: techniqueId),
        fingerprint =
            fingerprint ?? computeFingerprint(techniqueId, eliminations, placements);

  /// 空结果（表示"本技巧在当前盘面无命中"）。
  factory TechniqueResult.empty(TechniqueId techniqueId) =>
      TechniqueResult(techniqueId: techniqueId);

  /// 命中的技巧。
  final TechniqueId techniqueId;

  /// 删数结论列表（可为空）。
  final List<Elimination> eliminations;

  /// 填数结论列表（可为空）。
  final List<Placement> placements;

  /// 可视化数据（P0-ENG-09）。
  final VisualHint visual;

  /// 讲解参数（P0-ENG-10）。
  final NarrationParams narration;

  /// 结论指纹，用于同一步的重复上报去重。
  final String fingerprint;

  /// 是否为空结果（既无删数也无填数）。
  bool get isEmpty => eliminations.isEmpty && placements.isEmpty;

  /// 是否有实际结论。
  bool get isNotEmpty => !isEmpty;

  /// 本步涉及的全部格索引（结论格 + 可视化格，升序去重）。
  List<int> involvedCells() {
    final Set<int> set = <int>{...visual.involvedCells()};
    for (final Elimination e in eliminations) {
      set.add(e.cellIndex);
    }
    for (final Placement p in placements) {
      set.add(p.cellIndex);
    }
    final List<int> list = set.toList()..sort();
    return List<int>.unmodifiable(list);
  }

  /// 按结论内容计算稳定指纹（与列表顺序无关）。
  static String computeFingerprint(
    TechniqueId techniqueId,
    List<Elimination> eliminations,
    List<Placement> placements,
  ) {
    final List<String> elimKeys = <String>[
      for (final Elimination e in eliminations) '${e.cellIndex}:${e.digit}',
    ]..sort();
    final List<String> placeKeys = <String>[
      for (final Placement p in placements) '${p.cellIndex}=${p.digit}',
    ]..sort();
    return '${techniqueId.id}|E[${elimKeys.join(',')}]|P[${placeKeys.join(',')}]';
  }

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'techniqueId': techniqueId.id,
        'eliminations': <Map<String, Object?>>[
          for (final Elimination e in eliminations) e.toJson(),
        ],
        'placements': <Map<String, Object?>>[
          for (final Placement p in placements) p.toJson(),
        ],
        'visual': visual.toJson(),
        'narration': narration.toJson(),
        'fingerprint': fingerprint,
      };

  /// 由 JSON map 反序列化。
  static TechniqueResult fromJson(Map<String, Object?> json) => TechniqueResult(
        techniqueId: TechniqueId.parse(json['techniqueId']! as String),
        eliminations: <Elimination>[
          for (final Object? item
              in (json['eliminations'] as List<Object?>? ?? const <Object?>[]))
            Elimination.fromJson(item! as Map<String, Object?>),
        ],
        placements: <Placement>[
          for (final Object? item
              in (json['placements'] as List<Object?>? ?? const <Object?>[]))
            Placement.fromJson(item! as Map<String, Object?>),
        ],
        visual: json['visual'] == null
            ? null
            : VisualHint.fromJson(json['visual']! as Map<String, Object?>),
        narration: json['narration'] == null
            ? null
            : NarrationParams.fromJson(json['narration']! as Map<String, Object?>),
        fingerprint: json['fingerprint'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TechniqueResult &&
          other.techniqueId == techniqueId &&
          other.fingerprint == fingerprint);

  @override
  int get hashCode => Object.hash(techniqueId, fingerprint);

  @override
  String toString() => 'TechniqueResult($fingerprint)';
}
