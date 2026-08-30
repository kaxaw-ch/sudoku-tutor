/// `export-pool` 子命令：导出综合试炼关题池（每章 ≥20 题且必含本章目标技巧）。
///
/// 复用 [GenerationPipeline]；目标技巧经 `--target`（可多次/逗号分隔）声明，
/// 命中条件为「至少出现一个目标技巧」（T-CNT-02 验收：必含本章目标技巧）。
library;

import 'package:sudoku_core/sudoku_core.dart';

import '../config/cli_config.dart';
import '../config/default_profiles.dart';
import '../io/json_writer.dart';
import '../pipeline/filter_spec.dart';
import '../pipeline/generation_pipeline.dart';
import 'command_base.dart';

/// 题池 JSON schema 版本（对齐 doc 06 §7.2）。
const int kPoolSchemaVersion = 1;

/// 题池导出命令。
class ExportPoolCommand extends SudokuCommand {
  /// 构造命令。
  ExportPoolCommand(super.reporter) {
    argParser
      ..addOption(
        'chapter',
        help: '章节号（必填，用于命名 ch{N}.json.gz）',
      )
      ..addOption(
        'target',
        help: '目标技巧 id（逗号分隔；命中任意一个即收录）',
      )
      ..addOption(
        'count',
        abbr: 'c',
        help: '目标收录数量（默认 20）',
        defaultsTo: '20',
      )
      ..addOption(
        'target-givens',
        help: '挖洞目标提示数（默认按难度档取内建值）',
      )
      ..addOption(
        'max-attempts',
        help: '全局生成尝试预算上限（默认按 profile）',
      )
      ..addFlag(
        'no-script',
        help: '试炼题池不携带解题脚本（默认带；试炼关只需技巧标注，脚本由教学关携带）',
        defaultsTo: false,
      );
    addFilterOptions();
  }

  @override
  String get name => 'export-pool';

  @override
  String get description => '导出综合试炼关题池（每章 ≥20 题，必含目标技巧）';

  @override
  Future<Object?> run() async {
    final String? chapterRaw = argResults!['chapter'] as String?;
    final int? chapter = int.tryParse(chapterRaw ?? '');
    if (chapter == null || chapter < 0) {
      throw UsageException('--chapter 必填且为 ≥0 的整数', usage);
    }

    final Set<TechniqueId> targets = _targets();
    if (targets.isEmpty) {
      throw UsageException('--target 必填（至少一个目标技巧 id）', usage);
    }

    final Difficulty difficulty = Difficulty.tryParse(
          argResults!['difficulty'] as String? ?? Difficulty.hard.id,
        ) ??
        Difficulty.hard;
    final int count = _intOption('count', fallback: 20);
    final ProfileSpec profile = profileValue();
    final int seed = seedValue();
    final int concurrency = concurrencyValue();
    final String profileName =
        kDefaultProfileByDifficulty[difficulty] ?? profile.name;
    final int targetGivens =
        kDefaultTargetGivensByDifficulty[difficulty] ?? 30;
    final int maxAttempts = _resolveMaxAttempts();
    final bool noScript = argResults!['no-script'] as bool;

    final FilterSpec filter = FilterSpec(
      exactDifficulty: difficulty,
      anyRequiredTechniques: targets,
      bannedTechniques: _techniqueCsvArg('banned'),
    );

    reporter.section('export-pool：第 $chapter 章，$count 道 ${difficulty.zhName}'
        '（目标技巧：${_ids(targets)}）');

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

    reporter.section('题池命中率报表（ch$chapter）');
    reporter.reportStats(result.stats, title: 'export-pool 命中率（ch$chapter）');

    final String out = outValue() ?? '';
    final String target = out.isEmpty
        ? resolvePath('pools/ch$chapter.json.gz')
        : resolvePath(out);
    final Map<String, Object?> pool = <String, Object?>{
      'schemaVersion': kPoolSchemaVersion,
      'chapter': chapter,
      'targetTechniques': _ids(targets),
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
    JsonWriter.writeJsonAuto(target, json: pool);
    reporter.info('已写出题池：$target（${result.puzzles.length} 道）');

    if (!result.isComplete) {
      reporter.warn('未能凑足 $count 道（收录 ${result.puzzles.length}），'
          '建议加大 --max-attempts 或加入更多 --target 技巧。');
      return 1;
    }
    return 0;
  }

  Set<TechniqueId> _targets() {
    final Set<TechniqueId> result = <TechniqueId>{};
    final String? raw = argResults!['target'] as String?;
    if (raw == null || raw.isEmpty) {
      return result;
    }
    for (final String part in raw.split(',')) {
      final String id = part.trim();
      final TechniqueId? technique = TechniqueId.tryParse(id);
      if (technique == null) {
        throw UsageException('--target 未知技巧 id「$id」', usage);
      }
      result.add(technique);
    }
    return result;
  }

  Set<TechniqueId> _techniqueCsvArg(String option) {
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

  int _intOption(String option, {required int fallback}) {
    final int? value = int.tryParse(argResults![option] as String);
    return (value == null || value < 1) ? fallback : value;
  }

  static List<String> _ids(Set<TechniqueId> ids) =>
      <String>[for (final TechniqueId id in ids) id.id];
}
