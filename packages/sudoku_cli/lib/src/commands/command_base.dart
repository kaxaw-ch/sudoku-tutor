/// 子命令基类：公共参数 + profile/筛选/路径的解析助手（doc 06 §3.2）。
///
/// 设计（doc 07 T-CLI-01）：
/// - 公共参数：`--profile` / `--seed` / `--concurrency` / `--out` / `--quiet`；
/// - 公共筛选参数：`--difficulty` / `--required` / `--any-required` / `--banned`
///   （各命令按需调用 [addFilterOptions] 注册）；
/// - 所有解析产物（[ProfileSpec] / [FilterSpec]）直接对接 sudoku_core。
library;

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:sudoku_core/sudoku_core.dart';

import '../config/cli_config.dart';
import '../io/progress_reporter.dart';
import '../pipeline/filter_spec.dart';

// 子命令普遍需要抛 UsageException，统一从本基类 re-export，避免到处 import args。
export 'package:args/command_runner.dart' show Command, CommandRunner, UsageException;

/// 所有子命令的公共基类。
abstract class SudokuCommand extends Command<Object?> {
  /// 构造基类（公共参数在此注册）。
  SudokuCommand(this.reporter) {
    argParser
      ..addOption(
        'profile',
        abbr: 'p',
        help: '出题 profile：内建名（t1 / t2）或 YAML 文件路径（默认 t2）',
        defaultsTo: 't2',
      )
      ..addOption(
        'seed',
        help: '随机种子（不传则用当前时间；传了保证同参可复现）',
      )
      ..addOption(
        'concurrency',
        abbr: 'j',
        help: '并发分片数（Isolate 并行，默认 1）',
        defaultsTo: '1',
      )
      ..addOption(
        'out',
        abbr: 'o',
        help: '输出路径（文件或目录，命令各异）',
      )
      ..addFlag(
        'quiet',
        help: '安静模式：隐藏逐条进度，只输出关键信息与报表',
        defaultsTo: false,
      );
  }

  /// 终端输出器（quiet 等行为封装在内）。
  final ProgressReporter reporter;

  /// 解析 profile（参数值优先，回退默认 t2）。
  ProfileSpec profileValue() {
    final String value = argResults!['profile'] as String;
    try {
      return CliConfig.loadProfile(value);
    } on FormatException catch (e) {
      throw UsageException('profile 解析失败：${e.message}', usage);
    }
  }

  /// 有效随机种子（显式传入则解析，否则取当前时钟）。
  int seedValue() {
    final String? raw = argResults!['seed'] as String?;
    if (raw == null || raw.isEmpty) {
      final int seed = Rng.fromClock().seed;
      reporter.progress('未指定 --seed，使用当前时间种子：$seed（复现请补 --seed $seed）');
      return seed;
    }
    final int? parsed = int.tryParse(raw);
    if (parsed == null) {
      throw UsageException('--seed 必须是整数：$raw', usage);
    }
    return parsed;
  }

  /// 并发数（>=1）。
  int concurrencyValue() {
    final int? value = int.tryParse(argResults!['concurrency'] as String);
    if (value == null || value < 1) {
      throw UsageException('--concurrency 必须是 ≥1 的整数', usage);
    }
    return value;
  }

  /// 输出路径（`--out` 未给时返回 null，命令各自决定默认值）。
  String? outValue() => argResults!['out'] as String?;

  /// 把相对路径解析为绝对路径（相对当前工作目录）。
  String resolvePath(String path) =>
      p.isAbsolute(path) ? p.normalize(path) : p.normalize(p.join(Directory.current.path, path));

  // ------------------------------------------------------------ 筛选选项

  /// 注册常用筛选参数（generate / filter / export-* 命令使用）。
  void addFilterOptions() {
    argParser
      ..addOption(
        'difficulty',
        help: '精确难度档：beginner|easy|medium|hard|master',
      )
      ..addOption(
        'min-difficulty',
        help: '难度下限（含）：beginner|easy|medium|hard|master',
      )
      ..addOption(
        'max-difficulty',
        help: '难度上限（含）：beginner|easy|medium|hard|master',
      )
      ..addOption(
        'required',
        help: '必须全部出现的技巧 id（逗号分隔，如 xWing,xyWing）',
      )
      ..addOption(
        'any-required',
        help: '至少出现一个的技巧 id（逗号分隔，如 finnedXWing,swordfish）',
      )
      ..addOption(
        'banned',
        help: '禁止出现的技巧 id（逗号分隔）',
      );
  }

  /// 由命令行参数构建 [FilterSpec]（未提供难度条件时 `difficulty == null`）。
  FilterSpec filterFromArgs() {
    final Difficulty? exact = _difficultyOf('difficulty');
    final Difficulty? min = _difficultyOf('min-difficulty');
    final Difficulty? max = _difficultyOf('max-difficulty');
    return FilterSpec(
      requiredTechniques: _techniqueCsv('required'),
      anyRequiredTechniques: _techniqueCsv('any-required'),
      bannedTechniques: _techniqueCsv('banned'),
      exactDifficulty: exact,
      minDifficulty: min,
      maxDifficulty: max,
    );
  }

  /// 由命令行解析单个难度档；未提供或非法返回 null。
  Difficulty? _difficultyOf(String option) {
    final String? raw = argResults![option] as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final Difficulty? difficulty = Difficulty.tryParse(raw);
    if (difficulty == null) {
      throw UsageException('$option 未知难度档「$raw」'
          '（可用：beginner/easy/medium/hard/master）', usage);
    }
    return difficulty;
  }

  /// 解析逗号分隔的技巧 id 列表；非法 id 抛 UsageException。
  Set<TechniqueId> _techniqueCsv(String option) {
    final String? raw = argResults![option] as String?;
    if (raw == null || raw.isEmpty) {
      return const <TechniqueId>{};
    }
    final Set<TechniqueId> result = <TechniqueId>{};
    for (final String part in raw.split(',')) {
      final String id = part.trim();
      if (id.isEmpty) {
        continue;
      }
      final TechniqueId? technique = TechniqueId.tryParse(id);
      if (technique == null) {
        throw UsageException('$option 未知技巧 id「$id」', usage);
      }
      result.add(technique);
    }
    return result;
  }
}
