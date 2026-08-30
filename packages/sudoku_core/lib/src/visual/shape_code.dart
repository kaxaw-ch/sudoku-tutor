/// 形状编码枚举（doc 06 §6.4，色盲双通道的**第二通道**）。
///
/// 与 [MarkRole] 的默认对应关系见 [defaultShapeOf]，识别器可显式覆盖。
library;

import 'mark_role.dart';

/// 形状通道编码。
enum ShapeCode {
  /// 无额外形状（仅颜色）。
  none('none', '无'),

  /// 实线粗框。
  solidThickBorder('solidThickBorder', '实线粗框'),

  /// 实线细框。
  solidThinBorder('solidThinBorder', '实线细框'),

  /// 虚线框。
  dashedBorder('dashedBorder', '虚线框'),

  /// 虚线框 + 圆点角标（结论目标格专用）。
  dashedBorderWithCornerDot('dashedBorderWithCornerDot', '虚线框加圆点角标'),

  /// 斜纹填充。
  diagonalHatch('diagonalHatch', '斜纹填充'),

  /// 圆点角标。
  cornerDot('cornerDot', '圆点角标'),

  /// 划除线。
  strikeThrough('strikeThrough', '划除线'),

  /// 无边框浅底。
  plainFill('plainFill', '无边框浅底'),

  /// 实线连线（链路端点）。
  solidLink('solidLink', '实线连线'),

  /// 虚线连线（链路端点）。
  dashedLink('dashedLink', '虚线连线');

  const ShapeCode(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文形状名。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static ShapeCode? tryParse(String id) {
    for (final ShapeCode value in ShapeCode.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  /// `MarkRole` → 默认形状的固定映射（doc 06 §6.4 表，逐行一致）。
  static ShapeCode defaultShapeOf(MarkRole role) => switch (role) {
        MarkRole.pattern => ShapeCode.solidThickBorder,
        MarkRole.fin => ShapeCode.diagonalHatch,
        MarkRole.cover => ShapeCode.plainFill,
        MarkRole.pivot => ShapeCode.cornerDot,
        MarkRole.pincer => ShapeCode.solidThinBorder,
        MarkRole.chainStrong => ShapeCode.solidLink,
        MarkRole.chainWeak => ShapeCode.dashedLink,
        MarkRole.elimination => ShapeCode.strikeThrough,
        MarkRole.target => ShapeCode.dashedBorderWithCornerDot,
      };
}
