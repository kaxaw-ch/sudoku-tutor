/// 分片写出 + GZip 压缩 + 原子落盘（doc 06 §3.2 `lib/src/io/json_writer.dart`）。
///
/// 铁律（T-CLI-03 验收项）：
/// - **原子落盘**：先写 `xxx.json.gz.tmp`，`flush + close` 成功后 `rename`，
///   进程中途被杀不会留下半截文件（对齐 doc 06 §5.3 时序图 JW）；
/// - GZip 只在本文件使用 `dart:io` 的 `GZipCodec`（**仅 CLI 层可用**，
///   sudoku_core 禁 dart:io）；
/// - 读侧按扩展名自动探测 `.gz`，便于 `verify` 命令直接校验压缩题库。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// CLI 层统一的 I/O 异常（携带可读中文信息，命令层捕获后输出）。
class CliIoException implements Exception {
  /// 构造异常。
  const CliIoException(this.message, [this.cause]);

  /// 可读信息。
  final String message;

  /// 底层原因（可空）。
  final Object? cause;

  @override
  String toString() => 'CliIoException($message)';
}

/// JSON 落盘与读取工具（静态纯函数集合）。
abstract final class JsonWriter {
  /// 把 [json] 序列化并写入 [target]，按 [gzip] 决定是否压缩。
  ///
  /// 原子性保证：**只写 tmp → flush → rename 覆盖目标**；
  /// 进程中途被杀最多留下 `.tmp` 残片，目标文件始终保持完整旧版本。
  static void writeJsonFile(
    String target, {
    required Object json,
    bool gzip = false,
    bool pretty = true,
  }) {
    final String content =
        pretty ? const JsonEncoder.withIndent('  ').convert(json) : jsonEncode(json);
    final File file = File(target);
    final String tmpPath = '$target.tmp';
    final File tmp = File(tmpPath);
    try {
      tmp.parent.createSync(recursive: true);
      final List<int> bytes = gzip
          ? GZipCodec(level: 6).encode(utf8.encode(content))
          : utf8.encode(content);
      // 单次同步写 tmp，保证内容整体性。
      tmp.writeAsBytesSync(bytes, flush: true);
      // 同目录内 rename：覆盖已存在目标为原子替换语义（Windows MoveFileEx）。
      tmp.renameSync(file.absolute.path);
    } on FileSystemException catch (e) {
      _cleanupTmp(tmp);
      throw CliIoException('写入失败：$target（${e.message}）', e);
    } on IOException catch (e) {
      _cleanupTmp(tmp);
      throw CliIoException('写入失败：$target（$e）', e);
    }
  }

  /// 按扩展名自动决定是否 GZip（`.gz` 结尾 → 压缩）。
  static void writeJsonAuto(
    String target, {
    required Object json,
    bool pretty = true,
  }) =>
      writeJsonFile(
        target,
        json: json,
        gzip: target.toLowerCase().endsWith('.gz'),
        pretty: pretty,
      );
  /// 读取 JSON 文件（`.gz` 结尾自动解压）。
  ///
  /// 返回解码后的对象；文件不存在/非法 JSON 抛 [CliIoException]。
  static Object? readJsonFile(String path) {
    final File file = File(path);
    if (!file.existsSync()) {
      throw CliIoException('文件不存在：$path');
    }
    final List<int> bytes = file.readAsBytesSync();
    final String text = path.toLowerCase().endsWith('.gz')
        ? utf8.decode(GZipCodec().decode(bytes))
        : utf8.decode(bytes);
    try {
      return jsonDecode(text);
    } on FormatException catch (e) {
      throw CliIoException('JSON 解析失败：$path（${e.message}）', e);
    }
  }

  /// 读取并强转（未读可绕过解压层的场景极少，暴露给命令层用）。
  static Map<String, Object?> readJsonMap(String path) {
    final Object? root = readJsonFile(path);
    if (root is! Map<String, Object?>) {
      throw CliIoException('$path 不是 JSON 对象');
    }
    return root;
  }

  /// 分片写出：把 [items] 按每片 [perFile] 条切分，写入 [dir] 下
  /// `{baseName}.{shard}.json(.gz)`。
  ///
  /// 题库/标注集合较大时分片便于人工审校与增量校验；返回实际写出的文件列表。
  static List<String> writeShards(
    String dir,
    String baseName, {
    required List<Map<String, Object?>> items,
    required int perFile,
    bool gzip = false,
  }) {
    final List<String> written = <String>[];
    if (items.isEmpty) {
      return written;
    }
    final String shardDir = p.join(dir, baseName);
    Directory(shardDir).createSync(recursive: true);
    for (int start = 0; start < items.length; start += perFile) {
      final int end = (start + perFile) < items.length ? start + perFile : items.length;
      final int shard = start ~/ perFile;
      final String suffix = gzip ? '.json.gz' : '.json';
      final String target = p.join(
        shardDir,
        '$baseName.${shard.toString().padLeft(3, '0')}$suffix',
      );
      writeJsonFile(
        target,
        json: <String, Object?>{
          'schemaVersion': 1,
          'shardIndex': shard,
          'items': items.sublist(start, end),
        },
        gzip: gzip,
      );
      written.add(target);
    }
    return written;
  }

  static void _cleanupTmp(File tmp) {
    try {
      if (tmp.existsSync()) {
        tmp.deleteSync();
      }
    } on FileSystemException {
      // 清理失败不阻断主流程。
    }
  }
}
