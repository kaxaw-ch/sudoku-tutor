/// 关卡 JSON codec（T-CORE-09：一关一 JSON，doc 06 §4.3 权威 schema）。
///
/// 编码/解码形态与 CLI `export-level` 产物（`dataset/level_candidates/ch{N}/*.json`）
/// 完全一致：
/// ```jsonc
/// {
///   "schemaVersion": 1, "id": "ch1_l03", "chapter": 1, "order": 3,
///   "kind": "demo", "title": "...", "intro": "...",
///   "techniqueTags": ["xWing"], "puzzle81": "...", "solution81": "...",
///   "poolRef": null,
///   "script": { "steps": [ { "order":1, "techniqueId":"xWing",
///     "involvedCells":[...], "eliminations":[{"cell":19,"digit":5}],
///     "placements":[], "narration":"...", "visual":{...} } ] }
/// }
/// ```
///
/// ⚠️ 差异说明（三方对照）：
/// - `script` 为**对象**形态（doc 06 §4.3 与候选 JSON 一致）；解码时同时兼容
///   **数组**形态（题库条目），但编码固定输出对象形态；
/// - `eliminations/placements` 写 **`cell`** 键（doc 06 §4.3 / 候选 JSON），
///   读侧对 `cell`/`cellIndex` 双兼容；
/// - [LessonLevel.givenMask]/[LessonLevel.narration] 为 doc 06 §4.3 未定义的
///   扩展字段，非空时才输出（见 `level_model.dart`）。
library;

import 'package:meta/meta.dart';

import '../techniques/technique_id.dart';
import '../util/core_error.dart';
import 'level_model.dart';
import 'solution_script.dart';

/// 关卡 JSON 编解码（静态纯函数，零算法、零 IO）。
@immutable
abstract final class LevelCodec {
  /// [LessonLevel] → 关卡 JSON map（与 export-level 产物逐字段对齐）。
  static Map<String, Object?> encode(LessonLevel level) => <String, Object?>{
        'schemaVersion': level.schemaVersion,
        'id': level.id,
        'chapter': level.chapter,
        'order': level.order,
        'kind': level.kind.id,
        'title': level.title,
        'intro': level.intro,
        if (level.narration.isNotEmpty) 'narration': List<String>.of(level.narration),
        'techniqueTags': <String>[
          for (final TechniqueId id in level.techniqueTags) id.id,
        ],
        'puzzle81': level.puzzle81,
        'solution81': level.solution81,
        if (level.givenMask != null) 'givenMask': level.givenMask,
        'poolRef': level.poolRef,
        if (level.hasScript) 'script': level.script!.toJson(),
      };

  /// 关卡 JSON map → [LessonLevel]。
  ///
  /// 校验：
  /// - `schemaVersion` 高于 [kLevelSchemaVersion] → 抛 `E_SCHEMA_001`；
  /// - 缺失必填字段（id/puzzle81/solution81 等）→ 抛 [CoreException]；
  /// - `kind` 未知 → 抛 [CoreException]。
  static LessonLevel decode(Map<String, Object?> json) {
    final Object? rawVersion = json['schemaVersion'];
    if (rawVersion is int && rawVersion > kLevelSchemaVersion) {
      throw CoreException(
        CoreErrorCode.schemaTooNew,
        '关卡「$rawVersion」schemaVersion=$rawVersion，当前支持 $kLevelSchemaVersion',
      );
    }
    final Object? rawKind = json['kind'];
    final LevelKind? kind = rawKind is String ? LevelKind.tryParse(rawKind) : null;
    if (kind == null) {
      throw CoreException(
        CoreErrorCode.importFormat,
        '关卡缺少合法 kind 字段（demo|guidedPractice|trial），实际 ${rawKind ?? "缺失"}',
      );
    }
    return LessonLevel(
      schemaVersion: (rawVersion as int?) ?? kLevelSchemaVersion,
      id: _requireString(json, 'id'),
      chapter: _requireInt(json, 'chapter'),
      order: _requireInt(json, 'order'),
      kind: kind,
      title: _requireString(json, 'title'),
      intro: (json['intro'] as String?) ?? '',
      narration: <String>[
        for (final Object? item in (json['narration'] as List<Object?>? ??
            const <Object?>[]))
          item! as String,
      ],
      techniqueTags: <TechniqueId>{
        for (final Object? v in (json['techniqueTags'] as List<Object?>? ??
            const <Object?>[]))
          TechniqueId.parse(v! as String),
      },
      puzzle81: _requireString(json, 'puzzle81'),
      solution81: _requireString(json, 'solution81'),
      givenMask: json['givenMask'] as String?,
      poolRef: json['poolRef'] as String?,
      script: _decodeScript(json['script']),
    );
  }

  /// 解析 `script` 字段：对象（关卡形态）/ 数组（题库形态）/ 缺失。
  static SolutionScript? _decodeScript(Object? rawScript) {
    if (rawScript == null) {
      return null;
    }
    if (rawScript is Map<String, Object?>) {
      return SolutionScript.fromJson(rawScript);
    }
    if (rawScript is List<Object?>) {
      return SolutionScript.fromStepJsonList(rawScript);
    }
    throw CoreException(
      CoreErrorCode.importFormat,
      'script 字段类型非法：${rawScript.runtimeType}',
    );
  }

  static String _requireString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String) {
      throw CoreException(
        CoreErrorCode.importFormat,
        '关卡 JSON 缺少或非法字段「$key」',
      );
    }
    return value;
  }

  static int _requireInt(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! int) {
      throw CoreException(
        CoreErrorCode.importFormat,
        '关卡 JSON 缺少或非法字段「$key」',
      );
    }
    return value;
  }
}
