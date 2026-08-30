/// 崩溃日志服务（P0-STO-07，不接任何第三方 SDK）。
///
/// - 本地落盘为 **JSON Lines**（每行一条完整 JSON，追加写）；
/// - 保留**最近 [kMaxEntries]（20）条**，超出截断头部（最旧）；
/// - 每条含时间戳、异常 toString、堆栈、上下文（如设备信息）；
/// - **铁律：本服务绝不抛异常** —— 崩溃日志本身失败不能引发二次崩溃；
///   所有 IO 错误一律吞掉并静默放弃本条。
///
/// 设备信息由调用方（bootstrap / 设置页）采集后作为 [context] 传入，
/// 本服务不直接依赖 `device_info_plus`，保持 domain 层轻量与可测。
library;

import 'dart:convert';
import 'dart:io';

/// 一条崩溃日志记录（纯数据）。
class CrashLogEntry {
  /// 构造记录。
  const CrashLogEntry({
    required this.timestamp,
    required this.error,
    this.stackTrace,
    this.deviceInfo,
    this.context = const <String, Object?>{},
  });

  /// 发生时间（epoch 毫秒，int UTC）。
  final int timestamp;

  /// 异常描述（`error.toString()`）。
  final String error;

  /// 堆栈（可为空）。
  final String? stackTrace;

  /// 设备信息摘要（如「Windows 11 · 版本 0.1.0」，由调用方提供）。
  final String? deviceInfo;

  /// 附加上下文（JSON 可序列化）。
  final Map<String, Object?> context;

  /// 序列化为单行 JSON。
  Map<String, Object?> toJson() => <String, Object?>{
        'timestamp': timestamp,
        'error': error,
        if (stackTrace != null) 'stackTrace': stackTrace,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
        'context': context,
      };

  /// 由 JSON map 反序列化。
  factory CrashLogEntry.fromJson(Map<String, Object?> json) => CrashLogEntry(
        timestamp: (json['timestamp'] as int?) ?? 0,
        error: (json['error'] as String?) ?? '(未知异常)',
        stackTrace: json['stackTrace'] as String?,
        deviceInfo: json['deviceInfo'] as String?,
        context: json['context'] is Map
            ? Map<String, Object?>.from(json['context']! as Map)
            : const <String, Object?>{},
      );

  /// 人类可读摘要（调试用）。
  String get summary =>
      '[${DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()}] $error';
}

/// 崩溃日志服务。
class CrashLogService {
  /// 构造服务。
  CrashLogService({required this.logsDir});

  /// 崩溃日志目录（由 `StoragePaths.logsDir` 提供）。
  final Directory logsDir;

  /// 日志文件名。
  static const String kLogFileName = 'crash.log';

  /// 保留条数上限（最近 20 条）。
  static const int kMaxEntries = 20;

  /// 串行写队列：崩溃日志可能是并发触发的（多层错误捕获），
  /// 用 Future 链保证「读-改-写」不交错。
  Future<void> _tail = Future<void>.value();

  /// 记录一条崩溃日志。
  ///
  /// [context] 可携带 `deviceInfo` 之外的附加信息；本方法**绝不抛出**。
  Future<void> record(
    Object error,
    StackTrace? stack, {
    Map<String, Object?> context = const <String, Object?>{},
  }) async {
    final CrashLogEntry entry = CrashLogEntry(
      timestamp: DateTime.now().toUtc().millisecondsSinceEpoch,
      error: error.toString(),
      stackTrace: stack?.toString(),
      deviceInfo: context['deviceInfo'] as String?,
      context: context,
    );
    // 串行化，避免并发写坏行。
    _tail = _tail.then<void>((_) => _append(entry));
    try {
      await _tail;
    } on Object {
      // 绝不抛：崩溃日志自身失败不得引发二次崩溃。
    }
  }

  /// 读取全部日志（最新在前；按需解析，坏行跳过）。
  Future<List<CrashLogEntry>> readAll() async {
    final File file = _file();
    if (!await file.exists()) {
      return <CrashLogEntry>[];
    }
    final List<CrashLogEntry> entries = <CrashLogEntry>[];
    final List<String> lines = await file.readAsLines();
    for (final String line in lines) {
      if (line.trim().isEmpty) {
        continue;
      }
      try {
        final Object? decoded = jsonDecode(line);
        if (decoded is Map) {
          entries.add(
            CrashLogEntry.fromJson(
              Map<String, Object?>.from(decoded),
            ),
          );
        }
      } on FormatException {
        // 坏行跳过（可能是被强杀时写了一半）。
      }
    }
    return entries.reversed.toList(growable: false);
  }

  /// 导出日志文件路径（设置页「导出日志」用）。
  Future<File> exportLogFile() async {
    await logsDir.create(recursive: true);
    return _file();
  }

  /// 清空日志（开发者模式/重置用）。
  Future<void> clear() async {
    final File file = _file();
    if (await file.exists()) {
      try {
        await file.delete();
      } on FileSystemException {
        // 忽略。
      }
    }
  }

  /// 追加一条日志并修剪到最近 20 条。
  Future<void> _append(CrashLogEntry entry) async {
    try {
      await logsDir.create(recursive: true);
      final File file = _file();
      final String line = jsonEncode(entry.toJson());
      final File target = await file.exists()
          ? await file.writeAsString(
              '$line\n',
              mode: FileMode.append,
              flush: true,
            )
          : await file.writeAsString('$line\n', flush: true);

      // 修剪：超 20 条则保留最近 20 条重写（readAsLines 顺序=旧→新）。
      final List<String> lines = await target.readAsLines();
      if (lines.length > kMaxEntries) {
        final List<String> keep = lines.sublist(lines.length - kMaxEntries);
        await target.writeAsString('${keep.join('\n')}\n', flush: true);
      }
    } on Object {
      // 见类注释：绝不抛。
    }
  }

  File _file() => File(
        '${logsDir.path}${Platform.pathSeparator}$kLogFileName',
      );
}
