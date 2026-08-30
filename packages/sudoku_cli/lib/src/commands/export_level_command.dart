/// `export-level` 子命令：导出教学关候选盘面（供人工精选，T-CNT-03）。
///
/// 输入：标注集合 JSON（含完整解题脚本与可视化数据）。
/// 输出：每关一个 JSON，**对齐 doc 06 §4.3 关卡 JSON schema**
/// （`script.steps[].eliminations` 用 `cell` 字段，与 core 内部 `cellIndex` 不同，
/// 本文件负责该字段名映射；其余字段直接透传 `VisualHint`）。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sudoku_core/sudoku_core.dart';

import '../io/json_writer.dart';
import '../model/annotated_puzzle.dart';
import '../model/puzzle_collection.dart';
import 'command_base.dart';

/// 关卡 JSON schema 版本（对齐 doc 06 §7.2 `kLevelSchemaVersion`）。
const int kLevelSchemaVersion = 1;

/// 教学关候选导出命令。
class ExportLevelCommand extends SudokuCommand {
  /// 构造命令。
  ExportLevelCommand(super.reporter) {
    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help: '输入标注集合 JSON 路径（annotate 产物，必填）',
      )
      ..addOption(
        'chapter',
        help: '章节号（默认 0，用于命名 ch{N}_l{M}）',
        defaultsTo: '0',
      )
      ..addOption(
        'order-start',
        help: '起始序号（默认 1）',
        defaultsTo: '1',
      )
      ..addOption(
        'kind',
        help: '关卡类型：demo|guidedPractice|trial（默认 guidedPractice）',
        defaultsTo: 'guidedPractice',
      )
      ..addOption(
        'title',
        help: '标题模板（默认用最高技巧中文名，如「{tech} 实战演练」）',
      )
      ..addOption(
        'tags',
        help: '技巧标签（逗号分隔；默认取每题 techniques 全集）',
      );
  }

  @override
  String get name => 'export-level';

  @override
  String get description =>
      '导出教学关候选盘面（标注集合 → 每关一个 JSON，对齐关卡 schema）';

  @override
  Future<Object?> run() async {
    final String? rawInput = argResults!['input'] as String?;
    if (rawInput == null || rawInput.isEmpty) {
      throw UsageException('--input 必填（annotate 产出的标注集合）', usage);
    }
    final int chapter = _intOption('chapter', fallback: 0);
    final int orderStart = _intOption('order-start', fallback: 1);
    final String kind = argResults!['kind'] as String;
    if (!const <String>{'demo', 'guidedPractice', 'trial'}.contains(kind)) {
      throw UsageException('--kind 仅支持 demo|guidedPractice|trial', usage);
    }
    final String titleTemplate =
        argResults!['title'] as String? ?? '{tech} 实战演练';
    final Set<TechniqueId>? tags = _tags();

    final Map<String, Object?> root =
        JsonWriter.readJsonMap(resolvePath(rawInput));
    final ParsedCollection collection = PuzzleCollection.decode(root);

    // 仅导出已标注（含脚本）的题。
    final List<AnnotatedPuzzle> annotated = <AnnotatedPuzzle>[
      for (final AnnotatedPuzzle puzzle in collection.puzzles)
        if (puzzle.isAnnotated) puzzle,
    ];
    final int skipped = collection.puzzles.length - annotated.length;
    reporter.section('export-level：${annotated.length} 道候选'
        '（跳过 $skipped 道未标注）→ 第 $chapter 章，kind=$kind');

    final String out = outValue() ?? '';
    final String outDir = out.isEmpty
        ? resolvePath('dataset/level_candidates/ch$chapter')
        : resolvePath(out);
    Directory(outDir).createSync(recursive: true);

    int order = orderStart;
    final List<String> written = <String>[];
    for (final AnnotatedPuzzle puzzle in annotated) {
      final String levelId = 'ch${chapter}_l${order.toString().padLeft(2, '0')}';
      final TechniqueId? hardest = puzzle.hardestTechnique;
      final Set<TechniqueId> levelTags = tags ?? puzzle.techniques;
      final String title = titleTemplate.replaceAll(
        '{tech}',
        hardest?.zhName ?? '数独',
      );

      final Map<String, Object?> level = <String, Object?>{
        'schemaVersion': kLevelSchemaVersion,
        'id': levelId,
        'chapter': chapter,
        'order': order,
        'kind': kind,
        'title': title,
        'intro': '本关练习技巧：${_techNames(levelTags)}（候选题，供人工精选）。',
        'techniqueTags': _techIds(levelTags),
        'puzzle81': puzzle.puzzle81,
        'solution81': puzzle.solution81,
        'poolRef': null,
        'script': _scriptToLevelJson(puzzle.script),
      };

      final String target = p.join(outDir, '$levelId.json');
      JsonWriter.writeJsonFile(target, json: level);
      written.add(target);
      reporter.progress('  $levelId ← 题面 ${puzzle.puzzle81}'
          '（最高技巧：${hardest?.zhName ?? '-'}，${puzzle.stepCount} 步）');
      order++;
    }

    reporter.info('已写出 ${written.length} 个候选：$outDir');
    reporter.info('提示：人工精选后把 script.kind/title/intro 定稿即可入册'
        '（需配 app/assets/curriculum/index.json 登记一行）。');
    return 0;
  }

  /// 标注脚本 → 关卡 JSON `script.steps[]`（`cellIndex` → `cell` 字段名映射）。
  Map<String, Object?> _scriptToLevelJson(List<AnnotatedScriptStep> script) =>
      <String, Object?>{
        'steps': <Map<String, Object?>>[
          for (final AnnotatedScriptStep step in script)
            <String, Object?>{
              'order': step.order,
              'techniqueId': step.techniqueId.id,
              'involvedCells': List<int>.of(step.involvedCells),
              'eliminations': <Map<String, Object?>>[
                for (final Elimination e in step.eliminations)
                  <String, Object?>{'cell': e.cellIndex, 'digit': e.digit},
              ],
              'placements': <Map<String, Object?>>[
                for (final Placement pl in step.placements)
                  <String, Object?>{'cell': pl.cellIndex, 'digit': pl.digit},
              ],
              'narration': step.narration,
              'visual': step.visual,
            },
        ],
      };

  Set<TechniqueId>? _tags() {
    final String? raw = argResults!['tags'] as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final Set<TechniqueId> result = <TechniqueId>{};
    for (final String part in raw.split(',')) {
      final String id = part.trim();
      final TechniqueId? technique = TechniqueId.tryParse(id);
      if (technique == null) {
        throw UsageException('--tags 未知技巧 id「$id」', usage);
      }
      result.add(technique);
    }
    return result;
  }

  int _intOption(String option, {required int fallback}) {
    final int? value = int.tryParse(argResults![option] as String);
    return (value == null || value < 0) ? fallback : value;
  }

  static List<String> _techIds(Set<TechniqueId> ids) =>
      <String>[for (final TechniqueId id in ids) id.id];

  static String _techNames(Set<TechniqueId> ids) => ids
      .map((TechniqueId id) => id.zhName)
      .join('、');
}
