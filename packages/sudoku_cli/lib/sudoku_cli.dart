/// `sudoku_cli` 对外 barrel（bin 入口与测试统一从这里 import）。
///
/// 模块划分对齐 doc 06 §3.2：
/// - config：profile 载入与规则集声明；
/// - pipeline：生成 → 标注 → 筛选 → 去重 编排；
/// - io：JSON 原子落盘 / GZip / 进度报表；
/// - model：CLI 侧标注题目数据模型（纯 JSON 编解码，零算法）；
/// - commands：全部子命令。
library;

export 'src/cli_runner.dart';
export 'src/commands/annotate_command.dart';
export 'src/commands/command_base.dart';
export 'src/commands/export_bank_command.dart';
export 'src/commands/export_level_command.dart';
export 'src/commands/export_pool_command.dart';
export 'src/commands/filter_command.dart';
export 'src/commands/generate_command.dart';
export 'src/commands/selftest_command.dart';
export 'src/commands/verify_command.dart';
export 'src/config/cli_config.dart';
export 'src/config/default_profiles.dart';
export 'src/io/json_writer.dart';
export 'src/io/progress_reporter.dart';
export 'src/model/annotated_puzzle.dart';
export 'src/model/puzzle_collection.dart';
export 'src/pipeline/dedup.dart';
export 'src/pipeline/filter_spec.dart';
export 'src/pipeline/generation_pipeline.dart';
export 'src/qa/dataset_evaluator.dart';
