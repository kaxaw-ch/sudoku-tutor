/// 教学调色板 —— `MarkRole` → 颜色 + 形状双通道映射（P0-UI-03，架构 §6.4）。
///
/// 色觉双通道：约 8% 男性有红绿色觉异常，**纯颜色不可接受**；
/// 因此每个 `MarkRole` 同时绑定「颜色」与「形状」，二者共同传达语义。
///
/// 映射与架构文档 §6.4 表**逐行一致**：
/// - **颜色**：本文件定义具体色值（core 不含任何颜色值，零 Flutter 依赖）；
/// - **形状**：委托 `ShapeCode.defaultShapeOf(role)`（core 中的唯一事实源），
///   保证 UI 侧形状永远与 core 的视觉协议同步，不会各自漂移。
library;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';

/// 单个角色的双通道样式。
class MarkRoleStyle {
  /// 构造样式。
  const MarkRoleStyle({
    required this.role,
    required this.color,
    required this.shape,
  });

  /// 角色。
  final MarkRole role;

  /// 颜色通道（白色主题下的具体色值）。
  final Color color;

  /// 形状通道（委托 core 的 `ShapeCode.defaultShapeOf`）。
  final ShapeCode shape;

  /// 简体中文语义（来自 core，供无障碍朗读/调试）。
  String get zhName => role.zhName;
}

/// 教学调色板。
abstract final class TeachingPalette {
  /// 模式主体格（紫，与棋盘蓝色选中态区分）。
  static const Color pattern = Color(0xFF6D28D9);

  /// 鳍格（橙）。
  static const Color fin = Color(0xFFEA580C);

  /// 被覆盖的行/列区域（天蓝；需在浅色棋盘上保持清晰描边）。
  static const Color cover = Color(0xFF0284C7);

  /// 枢轴格（品红）。
  static const Color pivot = Color(0xFFC026D3);

  /// 夹翼格（青）。
  static const Color pincer = Color(0xFF0891B2);

  /// 强链端点（绿）。
  static const Color chainStrong = Color(0xFF15803D);

  /// 弱链端点（蓝灰）。
  static const Color chainWeak = Color(0xFF64748B);

  /// 被删候选所在格（红）。
  static const Color elimination = Color(0xFFDC2626);

  /// 结论目标格（琥珀，与红色删数明确区分）。
  static const Color target = Color(0xFFCA8A04);

  /// 角色 → 双通道样式（与 doc 06 §6.4 表逐行一致）。
  static MarkRoleStyle styleOf(MarkRole role) {
    final Color color = switch (role) {
      MarkRole.pattern => pattern,
      MarkRole.fin => fin,
      MarkRole.cover => cover,
      MarkRole.pivot => pivot,
      MarkRole.pincer => pincer,
      MarkRole.chainStrong => chainStrong,
      MarkRole.chainWeak => chainWeak,
      MarkRole.elimination => elimination,
      MarkRole.target => target,
    };
    return MarkRoleStyle(
      role: role,
      color: color,
      shape: ShapeCode.defaultShapeOf(role),
    );
  }

  /// 便捷：按 [MarkRole] 取颜色（供后续棋盘/教学图层绘制使用）。
  static Color colorOf(MarkRole role) => styleOf(role).color;
}
