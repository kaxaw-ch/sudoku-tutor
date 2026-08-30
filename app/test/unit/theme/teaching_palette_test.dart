/// T-UI-01 · 教学调色板测试（P0-UI-03，架构 §6.4 映射表逐行一致）。
///
/// 色觉双通道铁律：每个 `MarkRole` 同时有「颜色」与「形状」，
/// 且映射与 doc 06 §6.4 表逐行一致；形状通道委托 core 的
/// `ShapeCode.defaultShapeOf`（单一事实源，永不漂移）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/ui/theme/teaching_palette.dart';

void main() {
  group('MarkRole → 易区分颜色映射（doc 06 §6.4 逐行一致）', () {
    test('pattern 模式主体 = 紫 #6D28D9', () {
      expect(TeachingPalette.pattern, const Color(0xFF6D28D9));
    });
    test('fin 鳍格 = 橙 #EA580C', () {
      expect(TeachingPalette.fin, const Color(0xFFEA580C));
    });
    test('cover 覆盖区域 = 浅天蓝 #E0F2FE', () {
      expect(TeachingPalette.cover, const Color(0xFFE0F2FE));
    });
    test('pivot 枢轴格 = 品红 #C026D3', () {
      expect(TeachingPalette.pivot, const Color(0xFFC026D3));
    });
    test('pincer 夹翼格 = 青 #0891B2', () {
      expect(TeachingPalette.pincer, const Color(0xFF0891B2));
    });
    test('chainStrong 强链端点 = 绿 #15803D', () {
      expect(TeachingPalette.chainStrong, const Color(0xFF15803D));
    });
    test('chainWeak 弱链端点 = 蓝灰 #64748B', () {
      expect(TeachingPalette.chainWeak, const Color(0xFF64748B));
    });
    test('elimination 删数格 = 红 #DC2626', () {
      expect(TeachingPalette.elimination, const Color(0xFFDC2626));
    });
    test('target 结论目标格 = 琥珀 #CA8A04', () {
      expect(TeachingPalette.target, const Color(0xFFCA8A04));
      expect(TeachingPalette.target, isNot(TeachingPalette.elimination));
    });
  });

  test('九个教学角色使用九种不同颜色', () {
    final Set<Color> colors = <Color>{
      for (final MarkRole role in MarkRole.values)
        TeachingPalette.colorOf(role),
    };
    expect(colors, hasLength(MarkRole.values.length));
  });

  test('styleOf 对 9 个角色全覆盖，且颜色通道齐全', () {
    expect(MarkRole.values, hasLength(9));
    for (final MarkRole role in MarkRole.values) {
      final MarkRoleStyle style = TeachingPalette.styleOf(role);
      expect(style.role, role);
      expect(style.color, isNotNull);
      expect(style.zhName, isNotEmpty, reason: '每个角色有中文语义');
    }
  });

  test('形状通道与 core 的 ShapeCode.defaultShapeOf 逐行一致（单一事实源）', () {
    // 9 个角色逐一断言：UI 形状 == core 默认形状。
    const Map<MarkRole, ShapeCode> expected = <MarkRole, ShapeCode>{
      MarkRole.pattern: ShapeCode.solidThickBorder, // 实线粗框
      MarkRole.fin: ShapeCode.diagonalHatch, // 斜纹填充
      MarkRole.cover: ShapeCode.plainFill, // 无边框浅底
      MarkRole.pivot: ShapeCode.cornerDot, // 圆点角标
      MarkRole.pincer: ShapeCode.solidThinBorder, // 实线细框
      MarkRole.chainStrong: ShapeCode.solidLink, // 实线连线
      MarkRole.chainWeak: ShapeCode.dashedLink, // 虚线连线
      MarkRole.elimination: ShapeCode.strikeThrough, // 划除线
      MarkRole.target: ShapeCode.dashedBorderWithCornerDot, // 虚线框+圆点角标
    };
    expect(expected.length, MarkRole.values.length, reason: '映射表必须覆盖全部角色');

    for (final MapEntry<MarkRole, ShapeCode> e in expected.entries) {
      expect(
        TeachingPalette.styleOf(e.key).shape,
        e.value,
        reason: '${e.key.id} 的形状与 doc 06 §6.4 表不一致',
      );
      expect(
        ShapeCode.defaultShapeOf(e.key),
        e.value,
        reason: 'core 默认形状与 doc 06 §6.4 表不一致',
      );
    }
  });

  test('颜色+形状双通道：任何角色都不只靠颜色区分（形状均非 none）', () {
    for (final MarkRole role in MarkRole.values) {
      expect(
        TeachingPalette.styleOf(role).shape,
        isNot(ShapeCode.none),
        reason: '${role.id} 必须携带形状通道（色觉异常用户可辨）',
      );
    }
  });

  test('colorOf 便捷访问与 styleOf 一致', () {
    for (final MarkRole role in MarkRole.values) {
      expect(
          TeachingPalette.colorOf(role), TeachingPalette.styleOf(role).color);
    }
  });
}
