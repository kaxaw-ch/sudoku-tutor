/// `sudoku_cli` 入口（批次 D：CommandRunner 分发）。
///
/// 用法示例：
///   dart run sudoku_cli:sudoku_cli --help
///   dart run sudoku_cli:sudoku_cli generate --count 50 --difficulty medium
///   dart run sudoku_cli:sudoku_cli export-bank --difficulty hard --count 200
///   dart run sudoku_cli:sudoku_cli verify --input hard.json.gz
///
/// 退出码约定：0=成功；1=业务未达标；2=参数/IO 错误（见 `cli_runner.dart`）。
library;

import 'dart:io';

import 'package:sudoku_cli/sudoku_cli.dart';

Future<void> main(List<String> args) async {
  final int exitCode = await SudokuCliRunner().run(args);
  exit(exitCode);
}
