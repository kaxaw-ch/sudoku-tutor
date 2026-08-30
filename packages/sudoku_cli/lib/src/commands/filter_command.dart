/// `filter` 子命令：按技巧标签 / 难度 / 已学范围筛选标注集合。
///
/// 判定规则全部由 `sudoku_core` 的 `TechniqueId` / `Difficulty` 表达，
/// [FilterSpec] 只做匹配（doc 06 §3.2 `filter_spec.dart`）。
library;

import '../io/json_writer.dart';
import '../model/puzzle_collection.dart';
import '../pipeline/filter_spec.dart';
import 'command_base.dart';

/// 筛选命令。
class FilterCommand extends SudokuCommand {
  /// 构造命令。
  FilterCommand(super.reporter) {
    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help: '输入集合 JSON 路径（必填）',
      )
      ..addOption(
        'count',
        abbr: 'c',
        help: '取前 N 道（不传则全量输出）',
      );
    addFilterOptions();
  }

  @override
  String get name => 'filter';

  @override
  String get description => '按技巧标签 / 难度 / 范围筛选标注集合';

  @override
  Future<Object?> run() async {
    final String? rawInput = argResults!['input'] as String?;
    if (rawInput == null || rawInput.isEmpty) {
      throw UsageException('--input 必填（标注集合 JSON）', usage);
    }
    final String inputPath = resolvePath(rawInput);
    final FilterSpec filter = filterFromArgs();

    final Map<String, Object?> root = JsonWriter.readJsonMap(inputPath);
    final ParsedCollection collection = PuzzleCollection.decode(root);

    final int? count = _optionalCount();
    final int limit = count ?? collection.puzzles.length;

    final List<Object?> kept = <Object?>[];
    int matched = 0;
    for (final puzzle in collection.puzzles) {
      if (filter.matches(puzzle)) {
        matched++;
        if (kept.length < limit) {
          kept.add(puzzle.toJson());
        }
      }
    }

    reporter.section('filter：${collection.puzzles.length} 道 → 命中 $matched 道'
        '（$filter）');
    if (count != null && matched > limit) {
      reporter.progress('  仅保留前 $limit 道（--count）。');
    }

    final String out = outValue() ?? '';
    if (out.isNotEmpty) {
      final String target = resolvePath(out);
      JsonWriter.writeJsonAuto(
        target,
        json: <String, Object?>{
          'schemaVersion': 1,
          'kind': collection.kind,
          'profile': collection.profile,
          'seed': collection.seed,
          'concurrency': collection.concurrency,
          'count': kept.length,
          'puzzles': kept,
        },
      );
      reporter.info('已写出：$target（${kept.length} 道）');
    } else {
      reporter.info('提示：加 --out <file.json> 落盘筛选结果。');
    }
    return 0;
  }

  int? _optionalCount() {
    final String? raw = argResults!['count'] as String?;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final int? value = int.tryParse(raw);
    if (value == null || value < 1) {
      throw UsageException('--count 必须是 ≥1 的整数', usage);
    }
    return value;
  }
}
