/// T-DOM-01 · 原子文件读写测试（P0-STO-01）。
///
/// 覆盖：写入→读取往返、**中途 kill 模拟**（注入式故障点）、
/// tmp 损坏恢复、损坏文件报错 `E_IO_001`。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';
import 'package:sudoku_tutor/domain/storage/atomic_file.dart';

void main() {
  late Directory temp;
  late File target;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('sudoku_atomic_test_');
    target = File('${temp.path}${Platform.pathSeparator}progress.json');
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('写入 → 读取 往返一致', () async {
    const AtomicFile io = AtomicFile();
    final Map<String, Object?> data = <String, Object?>{
      'schemaVersion': 2,
      'deviceId': 'abc-123',
      'settings': <String, Object?>{'theme': 'white'},
    };

    await io.writeJson(target, data);
    final Map<String, Object?>? read = await io.readJson(target);

    expect(read, isNotNull);
    expect(read!['schemaVersion'], 2);
    expect(read['deviceId'], 'abc-123');
    expect((read['settings']! as Map)['theme'], 'white');
  });

  test('注入故障点：替换前「进程被 kill」→ 目标文件保持旧内容，tmp 可恢复', () async {
    // 1. 先写入旧档。
    const AtomicFile clean = AtomicFile();
    await clean.writeJson(
      target,
      <String, Object?>{'schemaVersion': 2, 'deviceId': 'old'},
    );

    // 2. 用带故障点的实例写新档：hook 在替换前抛异常模拟「进程被杀」。
    bool hookCalled = false;
    final AtomicFile faulty = AtomicFile(
      beforeReplaceHook: (File _) {
        hookCalled = true;
        throw const ProcessKilled();
      },
    );

    await expectLater(
      faulty.writeJson(target, <String, Object?>{
        'schemaVersion': 2,
        'deviceId': 'new',
      }),
      throwsA(isA<ProcessKilled>()),
    );
    expect(hookCalled, isTrue, reason: '故障点必须被触发');

    // 3. 目标文件仍是旧完整内容（未被破坏）。
    final Map<String, Object?>? stillOld = await clean.readJson(target);
    expect(stillOld!['deviceId'], 'old');

    // 4. tmp 文件是完整的新内容，可用 recoverFromTmp 恢复。
    final Map<String, Object?>? recovered = await clean.recoverFromTmp(target);
    expect(recovered!['deviceId'], 'new');
    final Map<String, Object?>? after = await clean.readJson(target);
    expect(after!['deviceId'], 'new', reason: '恢复后目标文件应为新内容');
  });

  test('临时文件损坏恢复：目标损坏 + 完好 tmp → recover 成功', () async {
    const AtomicFile io = AtomicFile();
    // 手工构造一个「目标被半写损坏、tmp 完整」的崩溃现场。
    final File tmp = File('${target.path}${AtomicFile.tmpSuffix}');
    await tmp.writeAsString(jsonEncode(<String, Object?>{'deviceId': 'x'}),
        flush: true);
    await target.writeAsString('{ 坏掉的 JSON', flush: true);

    final Map<String, Object?>? recovered = await io.recoverFromTmp(target);
    expect(recovered, isNotNull);
    expect(recovered!['deviceId'], 'x');
    // 恢复后 tmp 已被消费（rename），目标文件为完整新内容。
    expect(await tmp.exists(), isFalse);
  });

  test('损坏的主文件 + 无 tmp → readJson 抛 E_IO_001', () async {
    const AtomicFile io = AtomicFile();
    await target.writeAsString('{ 不是合法 JSON', flush: true);

    await expectLater(
      io.readJson(target),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_IO_001'),
      ),
    );
  });

  test('文件不存在 → readJson 返回 null', () async {
    const AtomicFile io = AtomicFile();
    final Map<String, Object?>? read = await io.readJson(target);
    expect(read, isNull);
  });

  test('消息内容可用 jsonEncode 再次编码（纯 JSON 数据保证）', () async {
    const AtomicFile io = AtomicFile();
    await io.writeJson(target, <String, Object?>{
      'a': 1,
      'b': <Object?>[true, null]
    });
    final String raw = await target.readAsString();
    expect(jsonDecode(raw), isA<Map<String, Object?>>());
  });
}

/// 模拟进程被强杀（非标准异常，仅测试用）。
class ProcessKilled implements Exception {
  /// 构造异常。
  const ProcessKilled();
}
