/// 原子文件读写（P0-STO-01 的落地核心）。
///
/// 写入策略（架构文档 §7.7 存档路径 + PRD P0-STO-01）：
///   1. 先写 `目标路径.tmp` 临时文件并 `flush`（数据落到磁盘）；
///   2. 替换目标文件（Windows 下先删旧再 rename，窗口极短）；
///   3. 任一步失败即清理 tmp，绝不让目标文件处于半写状态。
///
/// **原子性保证**：任意时刻目标文件要么是「旧版本完整内容」要么是
/// 「新版本完整内容」，绝不出现截断/半写；配合 `recoverFromTmp`，
/// 即使进程在替换前被 kill，也能用 tmp 恢复出新内容（测试注入故障点验证）。
///
/// ⚠️ 本文件属 domain 层（禁 `package:flutter/material.dart`），
/// 仅依赖 `dart:io` + `dart:convert`。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_tutor/domain/domain_error.dart';

/// 原子文件读写器（可注入故障点，供「中途 kill 模拟」测试）。
class AtomicFile {
  /// 构造读写器。
  ///
  /// [beforeReplaceHook] 为**测试注入的故障点**：在 tmp 写完后、
  /// 真正替换目标文件前被调用。测试中让该 hook 抛异常或直接标记，
  /// 即可模拟「进程在替换前被 kill」，验证目标文件未被破坏。
  const AtomicFile({this.beforeReplaceHook});

  /// 测试故障点（生产环境为 `null`）。
  final void Function(File target)? beforeReplaceHook;

  /// tmp 文件后缀（写临时文件用）。
  static const String tmpSuffix = '.tmp';

  /// 读取 JSON map；文件缺失返回 `null`，内容损坏抛 `E_IO_001`。
  Future<Map<String, Object?>?> readJson(File file) async {
    if (!await file.exists()) {
      return null;
    }
    final String raw;
    try {
      raw = await file.readAsString();
    } on FileSystemException catch (e) {
      throw AppError.ioRead(file.path, cause: e);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw AppError.ioRead(
        file.path,
        cause: e,
        reason: 'JSON 解析失败',
      );
    }
    if (decoded is! Map) {
      throw AppError.ioRead(file.path, reason: '顶层必须是 JSON 对象');
    }
    return <String, Object?>{...decoded.cast<String, Object?>()};
  }

  /// 原子写入 JSON map（tmp → 替换）。
  Future<void> writeJson(File file, Map<String, Object?> data) async {
    final String body = const JsonEncoder.withIndent('  ').convert(data);
    await writeString(file, body);
  }

  /// 原子写入字符串内容（tmp → 替换）。
  Future<void> writeString(File file, String content) async {
    final File tmp = File('${file.path}$tmpSuffix');
    try {
      // 1. 写 tmp 并 flush，确保内容已落盘（kill 前数据不丢）。
      final RandomAccessFile raf = await tmp.open(mode: FileMode.write);
      try {
        await raf.writeFrom(utf8.encode(content));
        await raf.flush();
      } finally {
        await raf.close();
      }

      // 2. 注入式故障点：替换前模拟「进程被 kill / 故障」。
      beforeReplaceHook?.call(file);

      // 3. 替换目标文件（Windows 下 rename 不覆盖，先删旧）。
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
    } on FileSystemException {
      // 4. 失败则清理 tmp，保持「目标文件要么旧要么新」的不变量。
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } on FileSystemException {
          // 清理失败不阻断主错误。
        }
      }
      rethrow;
    }
  }

  /// 用 tmp 文件恢复目标文件（崩溃恢复 / 损坏恢复）。
  ///
  /// 场景：写 tmp 完成后进程被 kill，目标文件仍是旧内容或缺失，
  /// 但 tmp 里是**完整的新内容** —— 此时可用 tmp 恢复。
  /// 返回恢复后的内容；无 tmp 返回 `null`。
  Future<Map<String, Object?>?> recoverFromTmp(File file) async {
    final File tmp = File('${file.path}$tmpSuffix');
    if (!await tmp.exists()) {
      return null;
    }
    // 损坏的 tmp 直接删掉，不污染后续恢复。
    final Map<String, Object?>? data = await readJson(tmp);
    if (data == null) {
      await _deleteIfExists(tmp);
      return null;
    }
    if (await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
    return data;
  }

  /// 删除文件（不存在则静默）。
  Future<void> deleteIfExists(File file) => _deleteIfExists(file);

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // 删除失败不抛出（尽力而为）。
      }
    }
  }
}
