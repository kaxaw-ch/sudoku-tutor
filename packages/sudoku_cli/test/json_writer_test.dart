/// `JsonWriter` 原子落盘 / GZip 往返单测（T-CLI-03）。
library;

import 'dart:io';

import 'package:test/test.dart';

import 'package:sudoku_cli/sudoku_cli.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('json_writer_test_');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('普通 JSON 写出 + 读取往返一致', () {
    final String path = '${dir.path}/a.json';
    JsonWriter.writeJsonFile(
      path,
      json: <String, Object?>{
        'name': '测试',
        'count': 3,
        'items': <Object?>[1, 2, 3],
      },
    );
    final Map<String, Object?> loaded = JsonWriter.readJsonMap(path);
    expect(loaded['name'], '测试');
    expect(loaded['count'], 3);
    expect(loaded['items'], <Object?>[1, 2, 3]);
  });

  test('GZip 写出 + 自动解压读取往返一致', () {
    final String path = '${dir.path}/bank.json.gz';
    final Map<String, Object?> payload = <String, Object?>{
      'schemaVersion': 1,
      'count': 5,
      'puzzles': <Object?>[
        for (int i = 0; i < 5; i++) <String, Object?>{'id': i, 'data': '题面$i'},
      ],
    };
    JsonWriter.writeJsonFile(path, json: payload, gzip: true);
    // 目标文件是 gzip 字节。
    final List<int> bytes = File(path).readAsBytesSync();
    expect(bytes, isNotEmpty);
    // 读取自动解压。
    final Map<String, Object?> loaded = JsonWriter.readJsonMap(path);
    expect(loaded['count'], 5);
    final List<Object?> puzzles = loaded['puzzles'] as List<Object?>;
    expect(puzzles.length, 5);
  });

  test('原子落盘：成功写入后无 .tmp 残片', () {
    final String path = '${dir.path}/atomic.json';
    JsonWriter.writeJsonFile(path, json: <String, Object?>{'ok': true});
    expect(File(path).existsSync(), isTrue);
    expect(File('$path.tmp').existsSync(), isFalse);
  });

  test('原子覆盖：第二次写入替换旧内容', () {
    final String path = '${dir.path}/atomic.json';
    JsonWriter.writeJsonFile(path, json: <String, Object?>{'v': 1});
    JsonWriter.writeJsonFile(path, json: <String, Object?>{'v': 2});
    final Map<String, Object?> loaded = JsonWriter.readJsonMap(path);
    expect(loaded['v'], 2);
  });

  test('读取不存在的文件抛 CliIoException', () {
    expect(
      () => JsonWriter.readJsonFile('${dir.path}/nope.json'),
      throwsA(isA<CliIoException>()),
    );
  });

  test('非法 JSON 抛 CliIoException', () {
    final String path = '${dir.path}/bad.json';
    File(path).writeAsStringSync('{ not json ');
    expect(
      () => JsonWriter.readJsonFile(path),
      throwsA(isA<CliIoException>()),
    );
  });

  test('writeShards 分片写出', () {
    final List<Map<String, Object?>> items = <Map<String, Object?>>[
      for (int i = 0; i < 7; i++) <String, Object?>{'i': i},
    ];
    final List<String> files = JsonWriter.writeShards(
      dir.path,
      'bank',
      items: items,
      perFile: 3,
    );
    expect(files.length, 3, reason: '7 条按每片 3 条 → 3 片');
    for (final String file in files) {
      expect(File(file).existsSync(), isTrue);
    }
  });
}
