/// 存档导入/导出门面（P0-STO-06 的 UI 消费面）。
///
/// `JsonProgressRepository` 已覆盖「字符串级导出 / 校验导入」；
/// 本服务补齐**文件级 IO**（桌面 file_selector 选路径落盘、移动端
/// share_plus 读共享文本），并提供统一的结果表达，供设置页
/// （T-UI-05）直接消费，避免 dart:io 逻辑散落在 Widget 层。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_tutor/domain/domain_error.dart';

import 'progress_repository.dart';

/// 导入结果（纯数据，供 UI 提示）。
class ImportResult {
  /// 构造结果。
  const ImportResult.ok()
      : ok = true,
        code = null,
        message = null;

  /// 构造失败结果。
  const ImportResult.fail(this.code, this.message) : ok = false;

  /// 是否成功。
  final bool ok;

  /// 失败时的错误码（如 `E_SCHEMA_001`）。
  final String? code;

  /// 失败时的中文说明。
  final String? message;
}

/// 导入/导出服务。
class ImportExportService {
  /// 构造服务。
  ImportExportService({required this.repository});

  /// 底层仓储。
  final ProgressRepository repository;

  // ------------------------------------------------------------ 导出

  /// 导出存档为 JSON 字符串（往返一致性的源）。
  Future<String> exportJson() => repository.exportArchive();

  /// 导出到指定文件路径（桌面端由 `file_selector` 提供路径）。
  Future<File> exportToFile(String path) async {
    final String json = await exportJson();
    final File file = File(path);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonDecode(json)),
      flush: true,
    );
    return file;
  }

  // ------------------------------------------------------------ 导入

  /// 从 JSON 字符串导入（含校验/迁移/自动备份，失败返回 [ImportResult.fail]）。
  Future<ImportResult> importJsonString(String json) async {
    try {
      await repository.importArchive(json);
      return const ImportResult.ok();
    } on AppError catch (e) {
      return ImportResult.fail(e.code, e.message);
    }
  }

  /// 从本地文件导入（读取 → 委托 [importJsonString]）。
  Future<ImportResult> importFromFile(String path) async {
    try {
      final String json = await File(path).readAsString();
      return importJsonString(json);
    } on FileSystemException catch (e) {
      return ImportResult.fail('E_IO_001', '读取导入文件失败：${e.message}');
    } on FormatException {
      return const ImportResult.fail('E_IMPORT_001', '导入文件不是合法的 JSON');
    }
  }
}
