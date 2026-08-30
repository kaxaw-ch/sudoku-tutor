/// 题库 JSON codec（T-CORE-09：LevelPuzzle 与自由练习题库集合的编解码）。
///
/// ⚠️ 三方对照结论（doc 06 §4.3 vs CLI 产物 vs 本 codec）：
/// - **自由练习题库 JSON**（export-bank 产物，`app/assets/puzzles/*.json.gz`）：
///   `{schemaVersion, difficulty, profile, seed, concurrency, count, generatedAt, puzzles[]}`，
///   `puzzles[]` 条目为 `AnnotatedPuzzle.toJson()` 形态——`script` 为**数组**、
///   `eliminations/placements` 用 **`cellIndex`** 键；
/// - **标注集合 JSON**（annotate 产物，`PuzzleCollection`）：`{schemaVersion, kind,
///   profile, seed, concurrency, count, puzzles[]}`，条目同上；
/// - **教学关候选 JSON**（export-level 产物）是**关卡形态**（`cell` 键 + `script`
///   对象），由 `level_codec.dart` 负责；本 codec 的 [PuzzleCodec.decodeItem] 也
///   兼容读取其中的 `puzzle81/solution81/script`（宽容忽略关卡元字段）。
///
/// 写侧统一对齐 CLI 产物：`cellIndex` 键 + `script` 数组（与 [SolutionScript.toStepJsonList]）。
library;

import '../grading/difficulty.dart';
import '../techniques/technique_id.dart';
import '../util/core_error.dart';
import 'puzzle.dart';
import 'solution_script.dart';

/// 题库 JSON schema 版本（doc 06 §7.2 `kPuzzleBankSchemaVersion`，CLI 同值）。
const int kPuzzleBankSchemaVersion = 1;

/// 解析后的题库/集合（record 形式，供上层直接使用）。
typedef ParsedPuzzleBank = ({
  int schemaVersion,
  Difficulty? difficulty,
  String profile,
  int seed,
  int concurrency,
  List<LevelPuzzle> puzzles,
});

/// [LevelPuzzle] 单条与题库集合的 JSON 编解码（静态纯函数）。
abstract final class PuzzleCodec {
  /// 单条 [LevelPuzzle] → JSON map（**题库条目形态**，对齐 CLI `AnnotatedPuzzle.toJson`）。
  ///
  /// [includeScript] 为 `false` 时跳过 `script` 字段（自由练习题库单题体积优化）。
  static Map<String, Object?> encodeItem(
    LevelPuzzle puzzle, {
    bool includeScript = true,
  }) =>
      <String, Object?>{
        'puzzle81': puzzle.puzzle81,
        'solution81': puzzle.solution81,
        if (puzzle.givenMask != null) 'givenMask': puzzle.givenMask,
        'seed': puzzle.seed,
        'fingerprint': puzzle.fingerprint,
        'givenCount': puzzle.givenCount,
        'difficulty': puzzle.difficulty?.id,
        'hardestTechnique': puzzle.hardestTechnique?.id,
        'stepCount': puzzle.stepCount,
        'techniques': <String>[
          for (final TechniqueId id in puzzle.techniques) id.id,
        ],
        'usageCounts': <String, int>{
          for (final MapEntry<TechniqueId, int> e in puzzle.usageCounts.entries)
            e.key.id: e.value,
        },
        if (puzzle.script != null && puzzle.script!.isNotEmpty && includeScript)
          'script': puzzle.script!.toStepJsonList(),
      };

  /// JSON map → [LevelPuzzle]（**题库条目形态**解析）。
  ///
  /// 兼容性：
  /// - `script` 支持**数组**（题库形态）与**对象** `{steps}`（关卡形态）；
  /// - `eliminations/placements` 的格索引键支持 `cellIndex` 与 `cell` 两种；
  /// - 缺失的可选字段（givenMask/difficulty/script 等）按缺省值处理。
  static LevelPuzzle decodeItem(Map<String, Object?> json) => LevelPuzzle(
        puzzle81: _requireString(json, 'puzzle81'),
        solution81: _requireString(json, 'solution81'),
        givenMask: json['givenMask'] as String?,
        seed: (json['seed'] as int?) ?? 0,
        fingerprint: (json['fingerprint'] as String?) ?? '',
        difficulty: json['difficulty'] == null
            ? null
            : Difficulty.tryParse(json['difficulty']! as String),
        hardestTechnique: json['hardestTechnique'] == null
            ? null
            : TechniqueId.tryParse(json['hardestTechnique']! as String),
        stepCount: (json['stepCount'] as int?) ?? 0,
        techniques: <TechniqueId>{
          for (final Object? v in (json['techniques'] as List<Object?>? ??
              const <Object?>[]))
            TechniqueId.parse(v! as String),
        },
        usageCounts: <TechniqueId, int>{
          for (final MapEntry<String, Object?> e
              in ((json['usageCounts'] as Map<String, Object?>?) ??
                  const <String, Object?>{}).entries)
            TechniqueId.parse(e.key): e.value! as int,
        },
        script: _decodeScript(json['script']),
      );

  /// 把 `script` 字段（数组/对象/缺失）解析为 [SolutionScript]。
  static SolutionScript? _decodeScript(Object? rawScript) {
    if (rawScript == null) {
      return null;
    }
    if (rawScript is List<Object?>) {
      return SolutionScript.fromStepJsonList(rawScript);
    }
    if (rawScript is Map<String, Object?>) {
      return SolutionScript.fromJson(rawScript);
    }
    throw CoreException(
      CoreErrorCode.importFormat,
      'script 字段类型非法：${rawScript.runtimeType}',
    );
  }

  /// 题库/集合根对象 → 解析结果（宽容忽略未知字段）。
  ///
  /// 支持两种 CLI 产物：
  /// - 自由练习题库：`{schemaVersion, difficulty, puzzles}`；
  /// - 标注集合：`{schemaVersion, kind, profile, seed, concurrency, puzzles}`。
  /// `schemaVersion` 高于当前时抛 `E_SCHEMA_001`。
  static ParsedPuzzleBank decodeBank(Map<String, Object?> root) {
    final Object? rawVersion = root['schemaVersion'];
    if (rawVersion is int && rawVersion > kPuzzleBankSchemaVersion) {
      throw CoreException(
        CoreErrorCode.schemaTooNew,
        '题库 schemaVersion=$rawVersion，当前支持 $kPuzzleBankSchemaVersion',
      );
    }
    final Object? rawPuzzles = root['puzzles'];
    if (rawPuzzles is! List<Object?>) {
      throw CoreException(
        CoreErrorCode.importFormat,
        '题库 JSON 缺少 puzzles 列表',
      );
    }
    final List<LevelPuzzle> puzzles = <LevelPuzzle>[
      for (final Object? item in rawPuzzles)
        decodeItem(item! as Map<String, Object?>),
    ];
    return (
      schemaVersion: (rawVersion as int?) ?? kPuzzleBankSchemaVersion,
      difficulty: root['difficulty'] == null
          ? null
          : Difficulty.tryParse(root['difficulty']! as String),
      profile: (root['profile'] as String?) ?? '',
      seed: (root['seed'] as int?) ?? 0,
      concurrency: (root['concurrency'] as int?) ?? 1,
      puzzles: puzzles,
    );
  }

  /// 题库/集合 → JSON map（[includeScript] 透传给单条 [encodeItem]）。
  static Map<String, Object?> encodeBank({
    required Difficulty? difficulty,
    required List<LevelPuzzle> puzzles,
    String profile = '',
    int seed = 0,
    int concurrency = 1,
    bool includeScript = true,
  }) =>
      <String, Object?>{
        'schemaVersion': kPuzzleBankSchemaVersion,
        if (difficulty != null) 'difficulty': difficulty.id,
        'profile': profile,
        'seed': seed,
        'concurrency': concurrency,
        'count': puzzles.length,
        'puzzles': <Map<String, Object?>>[
          for (final LevelPuzzle puzzle in puzzles)
            encodeItem(puzzle, includeScript: includeScript),
        ],
      };

  static String _requireString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String) {
      throw CoreException(
        CoreErrorCode.importFormat,
        'JSON 缺少或非法字段「$key」',
      );
    }
    return value;
  }
}
