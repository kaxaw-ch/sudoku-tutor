/// App 业务层统一错误（架构文档 §7.3 错误码约定）。
///
/// 格式 `E_<域>_<编号>`，域前缀与 core 的 `E_BOARD_`/`E_SOLVE_`/`E_TECH_`
/// 互补；本文件只定义**业务层**（domain）会抛的错误码。
///
/// | 码 | 含义 |
/// |---|---|
/// | `E_IO_001` | 存档读失败（缺失/损坏） |
/// | `E_IO_002` | 原子写失败 |
/// | `E_SCHEMA_001` | 存档版本高于当前 App 支持 |
/// | `E_SCHEMA_002` | 迁移链缺失（版本跳档无法迁移） |
/// | `E_IMPORT_001` | 导入内容格式非法 |
/// | `E_IMPORT_002` | 导入题目非唯一解（T-DOM-03 复用） |
/// | `E_ENGINE_001` | 引擎任务被取消（`cancelAll` 后过期结果） |
/// | `E_ENGINE_002` | 引擎任务执行失败（Isolate 内异常） |
library;

/// 业务层异常（携带稳定错误码与中文消息）。
class AppError implements Exception {
  /// 构造异常。
  const AppError(this.code, this.message, [this.cause]);

  /// 稳定错误码（`E_<域>_<编号>`）。
  final String code;

  /// 简体中文描述。
  final String message;

  /// 底层原因（可为空）。
  final Object? cause;

  // ------------------------------------------------------------ 工厂

  /// `E_IO_001`：读取失败。
  factory AppError.ioRead(String path, {Object? cause, String? reason}) =>
      AppError(
        'E_IO_001',
        '存档读取失败：$path${reason == null ? '' : '（$reason）'}',
        cause,
      );

  /// `E_IO_002`：原子写失败。
  factory AppError.ioWrite(String path, [Object? cause]) =>
      AppError('E_IO_002', '存档写入失败：$path', cause);

  /// `E_SCHEMA_001`：存档版本高于当前 App。
  factory AppError.schemaTooNew(int version, int current) => AppError(
        'E_SCHEMA_001',
        '存档版本 v$version 高于当前 App 支持的 v$current，请升级应用',
      );

  /// `E_SCHEMA_002`：迁移链缺失。
  factory AppError.schemaMigrationMissing(int from, int to) => AppError(
        'E_SCHEMA_002',
        '缺少 $from → $to 的存档迁移链',
      );

  /// `E_IMPORT_001`：导入内容格式非法。
  factory AppError.importFormat(String reason) =>
      AppError('E_IMPORT_001', '导入内容格式非法：$reason');

  /// `E_IMPORT_002`：导入题目非唯一解。
  factory AppError.importNotUnique() =>
      const AppError('E_IMPORT_002', '导入题目非唯一解');

  /// `E_ENGINE_001`：引擎任务被取消。
  factory AppError.engineCancelled(int taskId) =>
      AppError('E_ENGINE_001', '引擎任务 $taskId 已取消');

  /// `E_ENGINE_002`：引擎任务执行失败。
  factory AppError.engineFailed(int taskId, Object cause) =>
      AppError('E_ENGINE_002', '引擎任务 $taskId 执行失败', cause);

  @override
  String toString() => '[$code] $message';
}
