/// 课程数据仓库（T-EDU-01 / P0-EDU-01，PRD C-25）。
///
/// 职责：读取 `assets/curriculum/index.json` 与单关 JSON，**解析一律复用
/// `sudoku_core` 的 [LevelIndex] / [LevelCodec]**（T-CORE-09 已交付），
/// 本仓库不另写任何解析器，只做「资产读取 → 文本 → core codec」的转接。
///
/// 「新增一关 = 加一个 JSON 文件 + 在 `index.json` 登记一行」由
/// [loadIndex]/[loadLevel] 的数据驱动天然满足，零逻辑代码改动。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';

/// 资产读取函数签名（注入测试用；生产默认 [defaultCurriculumAssetLoader]）。
typedef CurriculumAssetLoader = Future<String> Function(String assetPath);

/// 生产默认加载器：rootBundle 读资产文本。
///
/// 不使用 `loadString`：它会在文件超过约 50 KB 时临时启动 Isolate 解码。
/// 部分教学 JSON 恰好越过该阈值，连续切关时会出现长时间等待；这类小文本
/// 直接解码字节更稳定，也避免重复点击叠加后台任务。
Future<String> defaultCurriculumAssetLoader(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return utf8.decode(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
}

/// 课程数据仓库。
class CurriculumRepository {
  /// 构造仓库；[loader] 缺省用 [defaultCurriculumAssetLoader]。
  CurriculumRepository({CurriculumAssetLoader? loader})
      : _loader = loader ?? defaultCurriculumAssetLoader;

  final CurriculumAssetLoader _loader;

  /// 课程索引内存缓存（避免反复解析 index.json）。
  LevelIndex? _cachedIndex;

  /// 单关内存缓存（id → 关卡）。
  final Map<String, LessonLevel> _levelCache = <String, LessonLevel>{};

  /// 读课程索引 `assets/curriculum/index.json` → [LevelIndex]。
  ///
  /// schemaVersion 高于当前抛 `E_SCHEMA_001`（由 [LevelIndex.fromJson] 保证）。
  Future<LevelIndex> loadIndex() async {
    final LevelIndex? cached = _cachedIndex;
    if (cached != null) {
      return cached;
    }
    final String text = await _read('assets/curriculum/index.json', '课程索引');
    try {
      final LevelIndex index = LevelIndex.fromJson(_decodeMap(text, '课程索引'));
      _cachedIndex = index;
      return index;
    } on CoreException catch (e) {
      // core 的 schema 版本校验（E_SCHEMA_001 等）统一包装成 AppError，
      // 与 domain 层其它仓储的错误类型保持一致（UI 只消费 AppError）。
      throw AppError(e.code, '课程索引解析失败：${e.detail ?? e.code}', e);
    }
  }

  /// 按关卡 id 加载单关 `LessonLevel`（经 [LevelCodec.decode]，零自研解析）。
  ///
  /// - 先在索引中查登记项（file 字段）；
  /// - 再读 `assets/curriculum/<file>` 并解码；
  /// - 单关内 `schemaVersion` 高于当前抛 `E_SCHEMA_001`。
  Future<LessonLevel> loadLevel(String levelId) async {
    final LessonLevel? cached = _levelCache[levelId];
    if (cached != null) {
      return cached;
    }
    final LevelIndex index = await loadIndex();
    final LevelEntry? entry = index.byId(levelId);
    if (entry == null) {
      throw AppError('E_IO_003', '课程索引未登记关卡：$levelId');
    }
    final String text =
        await _read('assets/curriculum/${entry.file}', '关卡 $levelId');
    try {
      final LessonLevel level =
          LevelCodec.decode(_decodeMap(text, '关卡 $levelId'));
      _levelCache[levelId] = level;
      return level;
    } on CoreException catch (e) {
      throw AppError(e.code, '关卡解析失败：${e.detail ?? e.code}', e);
    }
  }

  /// 按章节加载该章全部单关（顺序与索引一致）。
  Future<List<LessonLevel>> loadChapter(int chapter) async {
    final LevelIndex index = await loadIndex();
    final List<LessonLevel> levels = <LessonLevel>[];
    for (final LevelEntry entry in index.allLevels) {
      if (entry.chapter == chapter) {
        levels.add(await loadLevel(entry.id));
      }
    }
    return levels;
  }

  /// 按章节号取章入口（`null` = 章节不存在）。
  Future<ChapterEntry?> chapterEntry(int chapter) async {
    final LevelIndex index = await loadIndex();
    for (final ChapterEntry c in index.chapters) {
      if (c.chapter == chapter) {
        return c;
      }
    }
    return null;
  }

  /// 读资产文本；失败抛 `E_IO_003`。
  Future<String> _read(String path, String what) async {
    try {
      return await _loader(path);
    } on Object {
      throw AppError('E_IO_003', '$what 资产缺失：$path');
    }
  }

  /// JSON 文本 → `Map<String, Object?>`；格式非法抛 `E_IMPORT_001`。
  Map<String, Object?> _decodeMap(String text, String what) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw AppError.importFormat('$what JSON 非法');
    }
    if (decoded is! Map) {
      throw AppError.importFormat('$what 顶层必须是 JSON 对象');
    }
    return Map<String, Object?>.from(decoded);
  }
}
