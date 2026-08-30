/// 高亮角色枚举（doc 06 §6.4，色盲双通道的**颜色通道语义**）。
///
/// ⚠️ 本文件只定义**语义**，绝不含任何色值；
/// 具体色值与画笔在 `app/lib/ui/theme/teaching_palette.dart` 定义，
/// 以保证 `sudoku_core` 零 Flutter 依赖。
library;

/// 标记角色。
enum MarkRole {
  /// 构成技巧的主体格（蓝）。
  pattern('pattern', '模式主体'),

  /// 鳍格（橙），仅鳍形 X 翼使用。
  fin('fin', '鳍格'),

  /// 被覆盖的行/列区域（浅蓝），Fish 族使用。
  cover('cover', '覆盖区域'),

  /// 枢轴格（紫），XY/XYZ 翼使用。
  pivot('pivot', '枢轴格'),

  /// 夹翼格（青），XY/XYZ/W 翼使用。
  pincer('pincer', '夹翼格'),

  /// 强链端点（绿），W 翼与涂色使用。
  chainStrong('chainStrong', '强链端点'),

  /// 弱链端点（灰绿），涂色使用。
  chainWeak('chainWeak', '弱链端点'),

  /// 被删候选所在格（红）。
  elimination('elimination', '删数格'),

  /// 结论目标格（红）。
  target('target', '结论目标');

  const MarkRole(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文语义名（调试与无障碍朗读用）。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static MarkRole? tryParse(String id) {
    for (final MarkRole value in MarkRole.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}
