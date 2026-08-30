/// 高亮格标记：格索引 + 角色 + 形状 + 可选候选子集（doc 06 §6.4）。
library;

import 'package:meta/meta.dart';

import '../model/candidate_set.dart';
import '../model/coord.dart';
import 'mark_role.dart';
import 'shape_code.dart';

/// 一个被高亮的格子。
@immutable
class CellMark {
  /// 构造一个格标记；[shape] 省略时取 [MarkRole] 的默认形状。
  CellMark({
    required this.index,
    required this.role,
    ShapeCode? shape,
    this.focusDigits = CandidateSet.none,
  }) : shape = shape ?? ShapeCode.defaultShapeOf(role) {
    Coord.requireIndex(index);
  }

  /// 格索引 `0..80`。
  final int index;

  /// 角色（颜色通道语义）。
  final MarkRole role;

  /// 形状（第二通道）。
  final ShapeCode shape;

  /// 该格中需要强调的候选数子集，可为空集。
  final CandidateSet focusDigits;

  /// 人类可读坐标标签，如 `r2c3`。
  String get label => Coord.label(index);

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'index': index,
        'role': role.id,
        'shape': shape.id,
        'focusDigits': focusDigits.digits(),
      };

  /// 由 JSON map 反序列化；未知枚举值回落到默认。
  static CellMark fromJson(Map<String, Object?> json) {
    final MarkRole role = MarkRole.tryParse(json['role'] as String? ?? '') ?? MarkRole.pattern;
    final List<int> digits = <int>[
      for (final Object? item in (json['focusDigits'] as List<Object?>? ?? const <Object?>[]))
        item! as int,
    ];
    return CellMark(
      index: json['index']! as int,
      role: role,
      shape: ShapeCode.tryParse(json['shape'] as String? ?? ''),
      focusDigits: CandidateSet.fromDigits(digits),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CellMark &&
          other.index == index &&
          other.role == role &&
          other.shape == shape &&
          other.focusDigits.mask == focusDigits.mask);

  @override
  int get hashCode => Object.hash(index, role, shape, focusDigits.mask);

  @override
  String toString() => 'CellMark($label,${role.id},${shape.id},${focusDigits.describe()})';
}
