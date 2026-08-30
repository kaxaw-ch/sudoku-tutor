/// 16 项技巧枚举 + **定死中文译名** + 英文名（doc 03 §1、doc 06 §6.2）。
///
/// ⚠️ 中文译名一次性定死，后续文档、代码注释、教学文案一律沿用，不得改写。
/// 枚举声明顺序 = doc 06 §6.2 的 rank 升序，便于肉眼比对。
library;

import '../util/core_error.dart';

/// 本期实现的 16 项数独技巧。
enum TechniqueId {
  /// 唯一余数（rank 10）。
  nakedSingle('nakedSingle', '唯一余数', 'Naked Single'),

  /// 隐性唯一数（rank 20）。
  hiddenSingle('hiddenSingle', '隐性唯一数', 'Hidden Single'),

  /// 裸对（rank 30）。
  nakedPair('nakedPair', '裸对', 'Naked Pair'),

  /// 隐对（rank 40）。
  hiddenPair('hiddenPair', '隐对', 'Hidden Pair'),

  /// 区块排除（rank 50，含指针法与占位法两种情形）。
  lockedCandidates('lockedCandidates', '区块排除', 'Pointing & Claiming'),

  /// 裸三（rank 60）。
  nakedTriple('nakedTriple', '裸三', 'Naked Triple'),

  /// 隐三（rank 70）。
  hiddenTriple('hiddenTriple', '隐三', 'Hidden Triple'),

  /// X 翼（rank 80）。
  xWing('xWing', 'X 翼', 'X-Wing'),

  /// 鳍形 X 翼（rank 90，含 Sashimi 退化形态）。
  finnedXWing('finnedXWing', '鳍形 X 翼（含 Sashimi）', 'Finned X-Wing'),

  /// 剑鱼（rank 100，仅标准 N=3）。
  swordfish('swordfish', '剑鱼（标准）', 'Swordfish'),

  /// XY 翼（rank 110）。
  xyWing('xyWing', 'XY 翼', 'XY-Wing'),

  /// XYZ 翼（rank 120）。
  xyzWing('xyzWing', 'XYZ 翼', 'XYZ-Wing'),

  /// W 翼（rank 130，严格共轭对强链）。
  wWing('wWing', 'W 翼', 'W-Wing'),

  /// 唯一矩形 型一（rank 140）。
  urType1('urType1', '唯一矩形 型一', 'Unique Rectangle Type 1'),

  /// 唯一矩形 型二（rank 150）。
  urType2('urType2', '唯一矩形 型二', 'Unique Rectangle Type 2'),

  /// 简单涂色（rank 160，仅 Rule 2 + Rule 4）。
  simpleColouring('simpleColouring', '简单涂色', 'Simple Colouring');

  const TechniqueId(this.id, this.zhName, this.enName);

  /// JSON 序列化与 CLI 参数用的稳定标识（小驼峰）。
  final String id;

  /// **定死**的简体中文译名（doc 03 §1 / doc 06 §6.2）。
  final String zhName;

  /// 英文常用名。
  final String enName;

  /// 按 [id] 反查；未知返回 `null`。
  static TechniqueId? tryParse(String id) {
    for (final TechniqueId value in TechniqueId.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }

  /// 按 [id] 反查；未知抛 `E_TECH_003`。
  static TechniqueId parse(String id) {
    final TechniqueId? found = tryParse(id);
    if (found == null) {
      throw CoreException(CoreErrorCode.techNotRegistered, '未知技巧标识「$id」');
    }
    return found;
  }
}
