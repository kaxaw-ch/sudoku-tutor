/// `sudoku_cli` 命令分发器（CommandRunner）。
///
/// - 全部子命令通过 [CommandRunner] 注册与分发（doc 07 T-CLI-01）；
/// - 终端输出统一收敛到 [ProgressReporter]（可注入 sink，测试友好）；
/// - 顶层异常在此捕获并转成友好的中文提示 + 退出码约定：
///   0=成功；1=业务未达标（如收录不足 / 校验有不一致）；2=参数或 IO 错误。
library;

import 'package:args/command_runner.dart';
import 'package:sudoku_core/sudoku_core.dart';

import 'commands/annotate_command.dart';
import 'commands/export_bank_command.dart';
import 'commands/export_level_command.dart';
import 'commands/export_pool_command.dart';
import 'commands/filter_command.dart';
import 'commands/generate_command.dart';
import 'commands/selftest_command.dart';
import 'commands/verify_command.dart';
import 'io/json_writer.dart';
import 'io/progress_reporter.dart';

/// 命令分发器（继承 [CommandRunner] 以便重写 `printUsage` 注入输出）。
class SudokuCliRunner extends CommandRunner<Object?> {
  /// 构造分发器；[outSink] / [usageSink] 可注入（测试捕获输出用）。
  SudokuCliRunner({StringSink? outSink, void Function(String message)? usageSink})
      : reporter = ProgressReporter(sink: outSink),
        _usageSink = usageSink,
        super('sudoku_cli', '数独教学游戏离线出题工具：批量生成、逐级标注、'
            '筛选去重与题库导出。') {
    addCommand(SelftestCommand(reporter));
    addCommand(GenerateCommand(reporter));
    addCommand(AnnotateCommand(reporter));
    addCommand(FilterCommand(reporter));
    addCommand(ExportBankCommand(reporter));
    addCommand(ExportPoolCommand(reporter));
    addCommand(ExportLevelCommand(reporter));
    addCommand(VerifyCommand(reporter));
  }

  /// 终端输出器。
  final ProgressReporter reporter;

  final void Function(String message)? _usageSink;

  /// 重写 usage 输出，使其可注入（默认回落 print）。
  @override
  void printUsage() {
    final void Function(String message)? sink = _usageSink;
    if (sink != null) {
      sink(usage);
    } else {
      super.printUsage();
    }
  }

  /// 运行 [args]，返回退出码。
  ///
  /// 返回类型协变到 `int`（`Object?` 的子类型），bin 直接 `exit(码)`。
  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final Object? result = await super.run(args);
      return result is int ? result : 0;
    } on UsageException catch (e) {
      reporter.error(e.message);
      if (e.usage.isNotEmpty) {
        printUsage();
      }
      return 2;
    } on FormatException catch (e) {
      reporter.error('参数错误：${e.message}');
      return 2;
    } on CliIoException catch (e) {
      reporter.error(e.message);
      return 2;
    } on CoreException catch (e) {
      reporter.error('算法层错误：${e.errorCode.code} ${e.detail ?? ''}');
      return 2;
    } on RangeError catch (e) {
      reporter.error('数值越界：${e.message}');
      return 2;
    }
  }
}
