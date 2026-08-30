/// 矩形 / 单元描边标记（doc 06 §6.4）。
///
/// Fish 族用 4 或 6 个角点，唯一矩形用 4 个角点，
/// 隐性唯一数等单元级技巧可直接传入该单元的 9 个格索引。
library;

import 'package:meta/meta.dart';

import '../model/coord.dart';
import 'mark_role.dart';

/// 一块被描边的区域。
@immutable
class RegionMark {
  /// 构造一个区域标记。
  RegionMark({
    required List<int> cornerCells,
    required this.role,
    this.dashed = true,
    this.animated = false,
  }) : cornerCells = List<int>.unmodifiable(cornerCells) {
    for (final int index in cornerCells) {
      Coord.requireIndex(index);
    }
  }

  /// 区域角点（或单元全部格）索引，顺序由识别器决定。
  final List<int> cornerCells;

  /// 角色（颜色通道语义）。
  final MarkRole role;

  /// 是否虚线描边（虚线 = 模式区域）。
  final bool dashed;

  /// 是否启用流动动效（蚂蚁线），演示关开启。
  final bool animated;

  /// 人类可读标签，如 `r2c3、r2c8、r7c3、r7c8`。
  String get label => Coord.labelAll(cornerCells);

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'cornerCells': cornerCells,
        'role': role.id,
        'dashed': dashed,
        'animated': animated,
      };

  /// 由 JSON map 反序列化。
  static RegionMark fromJson(Map<String, Object?> json) => RegionMark(
        cornerCells: <int>[
          for (final Object? item in (json['cornerCells'] as List<Object?>? ?? const <Object?>[]))
            item! as int,
        ],
        role: MarkRole.tryParse(json['role'] as String? ?? '') ?? MarkRole.pattern,
        dashed: json['dashed'] as bool? ?? true,
        animated: json['animated'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! RegionMark ||
        other.role != role ||
        other.dashed != dashed ||
        other.animated != animated ||
        other.cornerCells.length != cornerCells.length) {
      return false;
    }
    for (int i = 0; i < cornerCells.length; i++) {
      if (other.cornerCells[i] != cornerCells[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(cornerCells), role, dashed, animated);

  @override
  String toString() => 'RegionMark([$label],${role.id},dashed=$dashed)';
}
