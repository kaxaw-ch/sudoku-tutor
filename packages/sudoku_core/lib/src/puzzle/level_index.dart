/// 课程索引模型（T-CORE-09：`curriculum/index.json` 清单解析）。
///
/// doc 06 §4.3 约定：`index.json` 仅登记
/// `{id, chapter, order, kind, title, techniqueTags, file}`，
/// **新增关卡 = 加一个 JSON 文件 + 登记一行，零逻辑代码改动**（PRD C-25）。
///
/// 结构（对齐 doc 06 §4.3 类图 `LevelIndex`：`schemaVersion` + `chapters`）：
/// ```jsonc
/// {
///   "schemaVersion": 1,
///   "chapters": [
///     { "chapter": 0, "title": "第 0 章 规则与基础",
///       "techniqueTags": ["nakedSingle", "hiddenSingle"],
///       "levels": [
///         { "id": "ch0_l01", "chapter": 0, "order": 1, "kind": "demo",
///           "title": "唯一余数", "techniqueTags": ["nakedSingle"],
///           "file": "ch0_l01.json" }
///       ] }
///   ]
/// }
/// ```
library;

import 'package:meta/meta.dart';

import '../techniques/technique_id.dart';
import '../util/core_error.dart';
import 'level_model.dart';

/// 索引 schema 版本（复用关卡 schema 版本号，doc 06 §7.2）。
const int kLevelIndexSchemaVersion = kLevelSchemaVersion;

/// 索引中的一条关卡登记。
@immutable
class LevelEntry {
  /// 构造关卡登记。
  LevelEntry({
    required this.id,
    required this.chapter,
    required this.order,
    required this.kind,
    required this.title,
    Set<TechniqueId> techniqueTags = const <TechniqueId>{},
    required this.file,
  }) : techniqueTags = Set<TechniqueId>.unmodifiable(techniqueTags);

  /// 关卡唯一标识（与关卡 JSON 的 `id` 一致）。
  final String id;

  /// 所属章节。
  final int chapter;

  /// 章内序号。
  final int order;

  /// 关卡类型。
  final LevelKind kind;

  /// 标题。
  final String title;

  /// 技巧标签。
  final Set<TechniqueId> techniqueTags;

  /// 关卡 JSON 文件名（相对 `assets/curriculum/`）。
  final String file;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'chapter': chapter,
        'order': order,
        'kind': kind.id,
        'title': title,
        'techniqueTags': <String>[
          for (final TechniqueId id in techniqueTags) id.id,
        ],
        'file': file,
      };

  /// 由 JSON map 反序列化。
  static LevelEntry fromJson(Map<String, Object?> json) {
    final Object? rawKind = json['kind'];
    final LevelKind? kind = rawKind is String ? LevelKind.tryParse(rawKind) : null;
    if (kind == null) {
      throw CoreException(
        CoreErrorCode.importFormat,
        '索引关卡缺少合法 kind 字段，实际 ${rawKind ?? "缺失"}',
      );
    }
    return LevelEntry(
      id: json['id']! as String,
      chapter: json['chapter']! as int,
      order: json['order']! as int,
      kind: kind,
      title: json['title']! as String,
      techniqueTags: <TechniqueId>{
        for (final Object? v in (json['techniqueTags'] as List<Object?>? ??
            const <Object?>[]))
          TechniqueId.parse(v! as String),
      },
      file: json['file']! as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LevelEntry &&
          other.id == id &&
          other.chapter == chapter &&
          other.order == order &&
          other.kind == kind &&
          other.title == title &&
          other.file == file);

  @override
  int get hashCode => Object.hash(id, chapter, order, kind, title, file);

  @override
  String toString() => 'LevelEntry($id, ${kind.id}, $title, file=$file)';
}

/// 索引中的一个章节（含章内全部关卡登记）。
@immutable
class ChapterEntry {
  /// 构造章节条目。
  ChapterEntry({
    required this.chapter,
    this.title,
    Set<TechniqueId> techniqueTags = const <TechniqueId>{},
    List<LevelEntry> levels = const <LevelEntry>[],
  })  : techniqueTags = Set<TechniqueId>.unmodifiable(techniqueTags),
        levels = List<LevelEntry>.unmodifiable(levels);

  /// 章节号。
  final int chapter;

  /// 章节名（可空）。
  final String? title;

  /// 章节目标技巧标签。
  final Set<TechniqueId> techniqueTags;

  /// 章内关卡清单（按 `order` 升序）。
  final List<LevelEntry> levels;

  /// 按 `order` 升序排序后构造。
  ChapterEntry sorted() => ChapterEntry(
        chapter: chapter,
        title: title,
        techniqueTags: techniqueTags,
        levels: <LevelEntry>[
          ...levels,
        ]..sort((LevelEntry a, LevelEntry b) => a.order.compareTo(b.order)),
      );

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'chapter': chapter,
        if (title != null) 'title': title,
        'techniqueTags': <String>[
          for (final TechniqueId id in techniqueTags) id.id,
        ],
        'levels': <Map<String, Object?>>[
          for (final LevelEntry entry in levels) entry.toJson(),
        ],
      };

  /// 由 JSON map 反序列化。
  static ChapterEntry fromJson(Map<String, Object?> json) => ChapterEntry(
        chapter: json['chapter']! as int,
        title: json['title'] as String?,
        techniqueTags: <TechniqueId>{
          for (final Object? v in (json['techniqueTags'] as List<Object?>? ??
              const <Object?>[]))
            TechniqueId.parse(v! as String),
        },
        levels: <LevelEntry>[
          for (final Object? item in (json['levels'] as List<Object?>? ??
              const <Object?>[]))
            LevelEntry.fromJson(item! as Map<String, Object?>),
        ],
      );

  @override
  String toString() => 'ChapterEntry(ch$chapter, levels=${levels.length})';
}

/// 课程索引（`curriculum/index.json` 清单模型）。
@immutable
class LevelIndex {
  /// 构造索引。
  LevelIndex({
    this.schemaVersion = kLevelIndexSchemaVersion,
    List<ChapterEntry> chapters = const <ChapterEntry>[],
  }) : chapters = List<ChapterEntry>.unmodifiable(chapters);

  /// 索引 schema 版本。
  final int schemaVersion;

  /// 章节清单。
  final List<ChapterEntry> chapters;

  /// 全部关卡（按章节、章内序号展开）。
  List<LevelEntry> get allLevels => <LevelEntry>[
        for (final ChapterEntry chapter in chapters) ...chapter.levels,
      ];

  /// 按 `id` 查关卡登记；未找到返回 `null`。
  LevelEntry? byId(String levelId) {
    for (final ChapterEntry chapter in chapters) {
      for (final LevelEntry entry in chapter.levels) {
        if (entry.id == levelId) {
          return entry;
        }
      }
    }
    return null;
  }

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': schemaVersion,
        'chapters': <Map<String, Object?>>[
          for (final ChapterEntry chapter in chapters) chapter.toJson(),
        ],
      };

  /// 由 JSON map 反序列化；`schemaVersion` 高于当前抛 `E_SCHEMA_001`。
  static LevelIndex fromJson(Map<String, Object?> json) {
    final Object? rawVersion = json['schemaVersion'];
    if (rawVersion is int && rawVersion > kLevelIndexSchemaVersion) {
      throw CoreException(
        CoreErrorCode.schemaTooNew,
        '课程索引 schemaVersion=$rawVersion，当前支持 $kLevelIndexSchemaVersion',
      );
    }
    return LevelIndex(
      schemaVersion: (rawVersion as int?) ?? kLevelIndexSchemaVersion,
      chapters: <ChapterEntry>[
        for (final Object? item in (json['chapters'] as List<Object?>? ??
            const <Object?>[]))
          ChapterEntry.fromJson(item! as Map<String, Object?>),
      ],
    );
  }

  @override
  String toString() => 'LevelIndex(chapters=${chapters.length}, '
      'levels=${allLevels.length})';
}
