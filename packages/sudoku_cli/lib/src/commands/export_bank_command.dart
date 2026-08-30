/// `export-bank` 子命令：导出自由练习题库（五档 × 200–500，gz ≤1MB）。
///
/// 端到端管线：生成 → 标注 → 筛选（目标难度）→ 去重 → GZip 原子落盘，
/// 并对齐 doc 06 §7.2 `kPuzzleBankSchemaVersion=1` 题库 JSON。
/// `--no-script` 时落盘 JSON 不携带解题脚本（单题 ~600B，五档合计 ≤1MB）；
/// 管线内部仍正常标注，命中率报表不受影响。
library;

import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

import '../config/cli_config.dart';
import '../config/default_profiles.dart';
import '../io/json_writer.dart';
import '../pipeline/filter_spec.dart';
import '../pipeline/generation_pipeline.dart';
import 'command_base.dart';

/// 题库 JSON schema 版本（对齐 doc 06 §7.2）。
const int kPuzzleBankSchemaVersion = 1;

/// 题库导出命令。
class ExportBankCommand extends SudokuCommand {
  /// 构造命令。
  ExportBankCommand(super.reporter) {
    argParser
      ..addOption(
        'count',
        abbr: 'c',
        help: '目标收录数量（默认 200）',
        defaultsTo: '200',
      )
      ..addOption(
        'target-givens',
        help: '挖洞目标提示数（默认按难度档取内建值）',
      )
      ..addOption(
        'max-attempts',
        help: '全局生成尝试预算上限（默认按 profile）',
      )
      ..addOption(
        'report',
        help: '命中率报表 JSON 落盘路径（可选）',
      )
      ..addFlag(
        'no-script',
        help: '自由练习题库不携带解题脚本（默认带，体积小 30 倍）',
        defaultsTo: false,
      );
    addFilterOptions();
  }

  @override
  String get name => 'export-bank';

  @override
  String get description =>
      '导出自由练习题库（五档 JSON.gz；生成+标注+筛选+去重+压缩原子落盘）';

  @override
  Future<Object?> run() async {
    final String? difficultyRaw = argResults!['difficulty'] as String?;
    final Difficulty? difficulty = difficultyRaw == null || difficultyRaw.isEmpty
        ? null
        : Difficulty.tryParse(difficultyRaw);
    if (difficulty == null) {
      throw UsageException('--difficulty 必填：beginner|easy|medium|hard|master', usage);
    }
    final int count = _intOption('count', fallback: 200);
    final ProfileSpec profile = profileValue();
    final int seed = seedValue();
    final int concurrency = concurrencyValue();
    final int targetGivens = _resolveTargetGivens(difficulty);
    final int maxAttempts = _resolveMaxAttempts();
    final bool noScript = argResults!['no-script'] as bool;
    final String profileName =
        kDefaultProfileByDifficulty[difficulty] ?? profile.name;

    // 目标难度精确命中 + 可选技巧条件。
    final FilterSpec filter = FilterSpec(
      exactDifficulty: difficulty,
      requiredTechniques: _techniqueFilter('required'),
      anyRequiredTechniques: _techniqueFilter('any-required'),
      bannedTechniques: _techniqueFilter('banned'),
    );

    reporter.section('export-bank：$count 道 ${difficulty.zhName}'
        '（profile=$profileName，seed=$seed，并发 $concurrency）');

    final GenerationPipeline pipeline = GenerationPipeline(reporter: reporter);
    final PipelineRunResult result = await pipeline.run(
      targetCount: count,
      baseSeed: seed,
      profile: profile,
      filter: filter,
      maxAttempts: maxAttempts,
      targetGivens: targetGivens,
      concurrency: concurrency,
      annotate: true,
    );

    reporter.section('题库命中率报表（${difficulty.id} 档）');
    reporter.reportStats(result.stats, title: 'export-bank 命中率（${difficulty.id}）');

    // 落盘：默认 {difficulty}.json.gz；--out 可覆盖完整路径。
    final String out = outValue() ?? '';
    final String target = out.isEmpty
        ? resolvePath('${difficulty.id}.json.gz')
        : resolvePath(out);
    final Map<String, Object?> bank = <String, Object?>{
      'schemaVersion': kPuzzleBankSchemaVersion,
      'difficulty': difficulty.id,
      'profile': profileName,
      'seed': seed,
      'concurrency': concurrency,
      'count': result.puzzles.length,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'puzzles': <Map<String, Object?>>[
        for (final puzzle in result.puzzles)
          puzzle.toJson(includeScript: !noScript),
      ],
    };
    JsonWriter.writeJsonAuto(target, json: bank);
    reporter.info('已写出题库：$target（${result.puzzles.length} 道，'
        '${_sizeOf(target)}）');

    _writeReport(result, difficulty);

    if (!result.isComplete) {
      reporter.warn('未能凑足 $count 道（收录 ${result.puzzles.length}），'
          '建议：加大 --max-attempts / 放宽难度筛选 / 检查 profile 规则集覆盖。');
      return 1;
    }
    return 0;
  }

  void _writeReport(PipelineRunResult result, Difficulty difficulty) {
    final String? reportPath = argResults!['report'] as String?;
    if (reportPath == null || reportPath.isEmpty) {
      return;
    }
    final String target = resolvePath(reportPath);
    JsonWriter.writeJsonAuto(
      target,
      json: <String, Object?>{
        ...result.toReportJson(),
        'difficulty': difficulty.id,
      },
    );
    reporter.info('命中率报表已写出：$target');
  }

  int _resolveTargetGivens(Difficulty difficulty) {
    final String? raw = argResults!['target-givens'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final int? value = int.tryParse(raw);
      if (value == null || value < PuzzleGenerator.kMinGivens || value > 81) {
        throw UsageException('--target-givens 必须在 17..81', usage);
      }
      return value;
    }
    return kDefaultTargetGivensByDifficulty[difficulty] ?? 30;
  }

  int _resolveMaxAttempts() {
    final String? raw = argResults!['max-attempts'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final int? value = int.tryParse(raw);
      if (value == null || value < 1) {
        throw UsageException('--max-attempts 必须是 ≥1 的整数', usage);
      }
      return value;
    }
    return profileValue().maxAttempts;
  }

  Set<TechniqueId> _techniqueFilter(String option) {
    final String? raw = argResults![option] as String?;
    if (raw == null || raw.isEmpty) {
      return const <TechniqueId>{};
    }
    final Set<TechniqueId> result = <TechniqueId>{};
    for (final String part in raw.split(',')) {
      final String id = part.trim();
      final TechniqueId? technique = TechniqueId.tryParse(id);
      if (technique == null) {
        throw UsageException('$option 未知技巧 id「$id」', usage);
      }
      result.add(technique);
    }
    return result;
  }

  int _intOption(String option, {required int fallback}) {
    final int? value = int.tryParse(argResults![option] as String);
    return (value == null || value < 1) ? fallback : value;
  }

  static String _sizeOf(String path) {
    try {
      final int bytes = File(path).lengthSync();
      if (bytes < 1024) {
        return '$bytes B';
      }
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } on FileSystemException {
      return '?';
    }
  }
}
