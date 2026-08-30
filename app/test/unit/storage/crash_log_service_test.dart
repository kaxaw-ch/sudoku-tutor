/// T-DOM-01 · 崩溃日志服务测试（P0-STO-07）。
///
/// 覆盖：保留**最近 20 条**、记录含堆栈与设备信息、绝不抛异常、
/// 清空与导出。日志写入是异步串行的，测试用真实异步等待。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/storage/crash_log_service.dart';

void main() {
  late Directory temp;
  late CrashLogService service;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('sudoku_crash_test_');
    service = CrashLogService(
        logsDir: Directory('${temp.path}${Platform.pathSeparator}logs'));
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('写入 25 条崩溃日志后仅保留最近 20 条', () async {
    for (int i = 1; i <= 25; i++) {
      await service.record(
        StateError('错误 #$i'),
        StackTrace.current,
        context: <String, Object?>{'deviceInfo': 'Test-Debugger', 'seq': i},
      );
    }

    final List<CrashLogEntry> entries = await service.readAll();
    expect(entries, hasLength(CrashLogService.kMaxEntries));

    // 最新在前：最老的一条（#1..#5）被淘汰，最新仍是 #25。
    expect(entries.first.context['seq'], 25);
    for (int i = 6; i <= 25; i++) {
      expect(
        entries.any((CrashLogEntry e) => e.context['seq'] == i),
        isTrue,
        reason: '条目 #$i 应被保留',
      );
    }
    expect(
      entries.any((CrashLogEntry e) => e.context['seq'] == 1),
      isFalse,
      reason: '最早的 #1 应被淘汰',
    );
  });

  test('记录包含堆栈与设备信息', () async {
    final StackTrace stack = StackTrace.current;
    await service.record(
      StateError('boom'),
      stack,
      context: <String, Object?>{'deviceInfo': 'Android 14 · 版本 0.1.0'},
    );

    final List<CrashLogEntry> entries = await service.readAll();
    expect(entries, hasLength(1));
    expect(entries.first.error, contains('boom'));
    expect(entries.first.stackTrace, isNotNull);
    expect(entries.first.deviceInfo, contains('Android'));
    expect(entries.first.timestamp, greaterThan(0));
  });

  test('record 绝不抛异常（日志目录不可写等场景被吞掉）', () async {
    // 让日志「路径」指向一个以文件占位的目录名，强制 IO 失败。
    final File blocker = File('${temp.path}${Platform.pathSeparator}blocked');
    await blocker.writeAsString('占位文件', flush: true);
    final CrashLogService broken =
        CrashLogService(logsDir: Directory(blocker.path));

    await expectLater(
      broken.record(StateError('x'), null),
      completes,
      reason: '崩溃日志自身失败不得抛出',
    );
  });

  test('清空与导出', () async {
    await service.record(StateError('a'), null);
    final File logFile = await service.exportLogFile();
    expect(await logFile.exists(), isTrue);
    expect(logFile.path, contains(CrashLogService.kLogFileName));

    await service.clear();
    expect(await service.readAll(), isEmpty);
  });
}
