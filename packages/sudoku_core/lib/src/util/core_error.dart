/// 算法层统一错误码与异常类型。
///
/// 编码格式：`E_<域>_<三位编号>`（架构文档 §7.3）。
/// 域前缀：`E_BOARD_` 盘面/编解码、`E_SOLVE_` 求解、`E_TECH_` 技巧识别、
/// `E_IO_` 文件与资产、`E_SCHEMA_` 版本、`E_IMPORT_` 题目导入。
library;

/// 统一错误码枚举。
///
/// 说明：架构文档 §7.3 给出的是"示例"编号，下列条目在其基础上补齐了
/// 算法层实际需要的少量编号（`E_BOARD_004/005`、`E_TECH_003`），
/// 前缀与格式完全遵循原约定。
enum CoreErrorCode {
  // ---- 盘面 / 编解码 ----
  /// 81 字符串长度非法。
  boardStringLength('E_BOARD_001', '81 字符串长度非法'),

  /// 81 字符串含非法字符。
  boardStringChar('E_BOARD_002', '81 字符串含非法字符'),

  /// 初始盘面自相矛盾（同行/列/宫出现重复数字）。
  boardInconsistent('E_BOARD_003', '初始盘面自相矛盾'),

  /// 试图修改题面给定格。
  boardGivenImmutable('E_BOARD_004', '试图修改题面给定格'),

  /// 格索引或数字越界。
  boardIndexRange('E_BOARD_005', '格索引或数字越界'),

  // ---- 求解 ----
  /// 盘面无解。
  solveNoSolution('E_SOLVE_001', '盘面无解'),

  /// 盘面存在多解。
  solveMultipleSolutions('E_SOLVE_002', '盘面存在多解'),

  /// 纯逻辑不可解（超出当前规则集能力范围）。
  solveNotLogical('E_SOLVE_003', '纯逻辑不可解（超出规则集）'),

  // ---- 技巧识别 ----
  /// 删数命中终局解 —— SanityGuard 断言失败，视为 P0 缺陷。
  techEliminationHitsSolution('E_TECH_001', '删数命中终局解'),

  /// 唯一矩形族前提不满足却被调用。
  techUniquenessPrecondition('E_TECH_002', '唯一矩形前提不满足'),

  /// 技巧未注册到注册表。
  techNotRegistered('E_TECH_003', '技巧未注册'),

  // ---- 文件与资产 ----
  /// 存档读失败。
  ioReadFailed('E_IO_001', '存档读失败'),

  /// 原子写失败。
  ioWriteFailed('E_IO_002', '原子写失败'),

  /// 资产缺失。
  ioAssetMissing('E_IO_003', '资产缺失'),

  // ---- 版本 ----
  /// 数据 schema 版本高于当前支持版本。
  schemaTooNew('E_SCHEMA_001', 'schema 版本高于当前'),

  /// 迁移链缺失。
  schemaMigrationMissing('E_SCHEMA_002', 'schema 迁移链缺失'),

  // ---- 题目导入 ----
  /// 导入格式非法。
  importFormat('E_IMPORT_001', '导入格式非法'),

  /// 导入题目非唯一解。
  importNotUnique('E_IMPORT_002', '导入题目非唯一解');

  const CoreErrorCode(this.code, this.message);

  /// 机器可读错误码，形如 `E_BOARD_001`。
  final String code;

  /// 简体中文默认描述。
  final String message;

  /// 按错误码字符串反查枚举；找不到返回 `null`。
  static CoreErrorCode? tryParse(String code) {
    for (final CoreErrorCode value in CoreErrorCode.values) {
      if (value.code == code) {
        return value;
      }
    }
    return null;
  }
}

/// 算法层统一异常类型。
class CoreException implements Exception {
  /// 创建一个算法层异常。
  const CoreException(this.errorCode, [this.detail]);

  /// 错误码。
  final CoreErrorCode errorCode;

  /// 附加上下文（如具体格索引、非法字符等），可为空。
  final String? detail;

  /// 机器可读错误码字符串。
  String get code => errorCode.code;

  @override
  String toString() {
    final String base = '${errorCode.code} ${errorCode.message}';
    return detail == null ? 'CoreException($base)' : 'CoreException($base: $detail)';
  }
}
