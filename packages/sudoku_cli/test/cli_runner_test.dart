/// `SudokuCliRunner` 命令级冒烟测试（--help / selftest / 端到端链路）。
library;

import 'dart:io';

import 'package:test/test.dart';

import 'package:sudoku_cli/sudoku_cli.dart';

void main() {
  late Directory dir;
  late StringBuffer out;
  late StringBuffer usage;
  late SudokuCliRunner runner;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cli_runner_test_');
    out = StringBuffer();
    usage = StringBuffer();
    runner = SudokuCliRunner(
      outSink: out,
      usageSink: (String message) => usage.writeln(message),
    );
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  test('--help 输出完整命令清单', () async {
    final int code = await runner.run(<String>['--help']);
    expect(code, 0);
    final String text = usage.toString();
    for (final String command in <String>[
      'selftest',
      'generate',
      'annotate',
      'filter',
      'export-bank',
      'export-pool',
      'export-level',
      'verify',
    ]) {
      expect(text, contains(command), reason: '帮助应列出 $command');
    }
  });

  test('selftest 返回 0 且自检通过', () async {
    final int code = await runner.run(<String>['selftest']);
    expect(code, 0);
    expect(out.toString(), contains('自检通过'));
  });

  test('未知命令返回 2', () async {
    final int code = await runner.run(<String>['nope']);
    expect(code, 2);
  });

  test('generate 缺 --count 返回 2（UsageException）', () async {
    final int code = await runner.run(<String>['generate']);
    expect(code, 2);
    expect(out.toString(), contains('--count'));
  });

  test('generate → annotate → verify 端到端链路', () async {
    final String raw = '${dir.path}/raw.json';
    final String annotated = '${dir.path}/annotated.json';

    // 1) generate 纯生成（不标注）；36 提示数可解率高，保证后续 3/3 可标注。
    int code = await runner.run(<String>[
      'generate',
      '--count',
      '3',
      '--seed',
      '12345',
      '--target-givens',
      '36',
      '--out',
      raw,
    ]);
    expect(code, 0, reason: 'generate 应成功');
    expect(File(raw).existsSync(), isTrue);

    // 2) annotate 标注。
    code = await runner.run(<String>[
      'annotate',
      '--input',
      raw,
      '--out',
      annotated,
    ]);
    expect(code, 0, reason: 'annotate 应成功');
    final Map<String, Object?> root = JsonWriter.readJsonMap(annotated);
    expect(root['count'], 3,
        reason: '36 提示数下应全部可标注（可解率接近 100%）');

    // 3) verify 回放校验标注集合。
    code = await runner.run(<String>['verify', '--input', annotated]);
    expect(code, 0, reason: 'verify 应全部通过');
    expect(out.toString(), contains('全部通过'));
  });

  test('export-bank 小规模导出并 verify', () async {
    final String bank = '${dir.path}/hard.json.gz';
    final int code = await runner.run(<String>[
      'export-bank',
      '--difficulty',
      'hard',
      '--count',
      '3',
      '--seed',
      '20260805',
      '--max-attempts',
      '120',
      '--out',
      bank,
    ]);
    expect(code, 0, reason: 'export-bank hard 3 道应成功');
    expect(File(bank).existsSync(), isTrue);

    // 校验压缩题库内容。
    final Map<String, Object?> root = JsonWriter.readJsonMap(bank);
    expect(root['difficulty'], 'hard');
    expect(root['schemaVersion'], 1);
    final List<Object?> puzzles = root['puzzles'] as List<Object?>;
    expect(puzzles.length, 3);

    // verify 应通过。
    final int verifyCode = await runner.run(<String>['verify', '--input', bank]);
    expect(verifyCode, 0);
  });

  test('export-level 从标注集合导出关卡 JSON 且 verify 通过', () async {
    final String annotated = '${dir.path}/annotated.json';
    final String levels = '${dir.path}/levels';
    int code = await runner.run(<String>[
      'generate',
      '--count',
      '3',
      '--seed',
      '20260805',
      '--annotate',
      '--out',
      annotated,
    ]);
    expect(code, 0);

    code = await runner.run(<String>[
      'export-level',
      '--input',
      annotated,
      '--chapter',
      '0',
      '--out',
      levels,
    ]);
    expect(code, 0);
    expect(Directory(levels).existsSync(), isTrue);

    // 关卡 JSON 单关校验。
    code = await runner.run(<String>['verify', '--dataset', levels]);
    expect(code, 0, reason: '导出关卡必须能通过回放校验');
  });

  test('export-pool 默认带脚本、--no-script 时不含 script 且仍可 verify', () async {
    final String withScript = '${dir.path}/pool_with.json.gz';
    final String noScript = '${dir.path}/pool_no.json.gz';

    // 1) 默认：puzzles[] 携带 script。
    int code = await runner.run(<String>[
      'export-pool',
      '--chapter',
      '1',
      '--target',
      'nakedTriple,hiddenTriple',
      '--count',
      '2',
      '--seed',
      '20260807',
      '--max-attempts',
      '30000',
      '--concurrency',
      '2',
      '--out',
      withScript,
    ]);
    expect(code, 0, reason: 'export-pool 带脚本模式应成功');
    Map<String, Object?> root = JsonWriter.readJsonMap(withScript);
    expect(root['chapter'], 1);
    expect(root['targetTechniques'], <Object?>['nakedTriple', 'hiddenTriple']);
    final List<Object?> withPuzzles = root['puzzles'] as List<Object?>;
    expect(withPuzzles, isNotEmpty);
    expect((withPuzzles.first as Map<String, Object?>)['script'], isNotNull,
        reason: '默认必须携带解题脚本（试炼关标注复用）');

    // 2) --no-script：puzzles[] 不含 script，但技巧标注仍保留。
    code = await runner.run(<String>[
      'export-pool',
      '--chapter',
      '1',
      '--target',
      'nakedTriple,hiddenTriple',
      '--count',
      '2',
      '--seed',
      '20260807',
      '--max-attempts',
      '30000',
      '--concurrency',
      '2',
      '--no-script',
      '--out',
      noScript,
    ]);
    expect(code, 0, reason: 'export-pool --no-script 应成功');
    root = JsonWriter.readJsonMap(noScript);
    final List<Object?> noScriptPuzzles = root['puzzles'] as List<Object?>;
    expect(noScriptPuzzles, isNotEmpty);
    final Map<String, Object?> first = noScriptPuzzles.first as Map<String, Object?>;
    expect(first['script'], isNull, reason: '--no-script 后不得携带 script');
    expect(first['techniques'], isNotNull, reason: '技巧标注必须保留');
    expect(first['usageCounts'], isNotNull, reason: 'usageCounts 必须保留');

    // 3) 两份题池都能通过回放校验。
    code = await runner.run(<String>['verify', '--input', noScript]);
    expect(code, 0, reason: '无脚本题池也应通过 verify（集合条目回放）');
  });
}
