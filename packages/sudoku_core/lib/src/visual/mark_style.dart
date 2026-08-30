/// `MarkRole` → **颜色语义 token + 形状** 的双通道完整映射（doc 06 §6.4，T-CORE-09）。
///
/// 色盲友好双通道原则：
/// - **通道一（颜色）**：本文件只给出**语义 token**（如 `teaching.pattern`），
///   真实色值由 `app/lib/ui/theme/teaching_palette.dart` 按 token 查表，
///   从而保证 `sudoku_core` 零 Flutter / 零 `dart:ui` 依赖（R1 分层闸门）；
/// - **通道二（形状）**：复用 [ShapeCode.defaultShapeOf]。
///
/// 完整性铁律：[MarkRole] 每新增一个枚举值，[MarkStyles.colorTokenOf] 的
/// `switch` 会在**编译期**报「非穷尽」错误，从而不可能漏配；
/// [MarkStyles.missingRoles] 提供运行期自检，供单测断言。
library;

import 'package:meta/meta.dart';

import 'mark_role.dart';
import 'shape_code.dart';

/// 一个标记角色的完整呈现样式（颜色 token + 形状）。
@immutable
class MarkStyle {
  /// 构造一份样式。
  const MarkStyle({
    required this.role,
    required this.colorToken,
    required this.shape,
  });

  /// 对应角色。
  final MarkRole role;

  /// 颜色语义 token（UI 主题按此查表取色，算法层不含色值）。
  final String colorToken;

  /// 形状编码（第二通道）。
  final ShapeCode shape;

  /// 双通道是否都已给出（token 非空且形状非 [ShapeCode.none]）。
  bool get isDualChannel => colorToken.isNotEmpty && shape != ShapeCode.none;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'role': role.id,
        'colorToken': colorToken,
        'shape': shape.id,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarkStyle &&
          other.role == role &&
          other.colorToken == colorToken &&
          other.shape == shape);

  @override
  int get hashCode => Object.hash(role, colorToken, shape);

  @override
  String toString() => 'MarkStyle(${role.id},$colorToken,${shape.id})';
}

/// 角色样式查表（全部为静态纯函数）。
abstract final class MarkStyles {
  /// 主题 token 统一前缀。
  static const String tokenPrefix = 'teaching';

  /// 取 [role] 的颜色语义 token。
  ///
  /// 使用 `switch` 表达式而非 Map，令新增枚举值时**编译期**即暴露遗漏。
  static String colorTokenOf(MarkRole role) => switch (role) {
        MarkRole.pattern => '$tokenPrefix.pattern',
        MarkRole.fin => '$tokenPrefix.fin',
        MarkRole.cover => '$tokenPrefix.cover',
        MarkRole.pivot => '$tokenPrefix.pivot',
        MarkRole.pincer => '$tokenPrefix.pincer',
        MarkRole.chainStrong => '$tokenPrefix.chainStrong',
        MarkRole.chainWeak => '$tokenPrefix.chainWeak',
        MarkRole.elimination => '$tokenPrefix.elimination',
        MarkRole.target => '$tokenPrefix.target',
      };

  /// 取 [role] 的完整双通道样式。
  static MarkStyle of(MarkRole role) => MarkStyle(
        role: role,
        colorToken: colorTokenOf(role),
        shape: ShapeCode.defaultShapeOf(role),
      );

  /// 全部角色的样式（按枚举声明顺序）。
  static List<MarkStyle> all() => List<MarkStyle>.unmodifiable(<MarkStyle>[
        for (final MarkRole role in MarkRole.values) of(role),
      ]);

  /// 双通道不完整的角色（正常恒为空列表，供 CI / 单测自检）。
  static List<MarkRole> missingRoles() => List<MarkRole>.unmodifiable(<MarkRole>[
        for (final MarkRole role in MarkRole.values)
          if (!of(role).isDualChannel) role,
      ]);

  /// 双通道映射是否对每个 [MarkRole] 都完整。
  static bool get isComplete => missingRoles().isEmpty;

  /// 导出为 `role.id -> {colorToken, shape}` 的 JSON map（供 UI 主题生成）。
  static Map<String, Object?> toJson() => <String, Object?>{
        for (final MarkStyle style in all())
          style.role.id: <String, Object?>{
            'colorToken': style.colorToken,
            'shape': style.shape.id,
          },
      };
}
