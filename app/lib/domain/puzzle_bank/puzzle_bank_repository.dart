/// 题库仓库 —— 读取 `assets/puzzles/*.json.gz`（五档自由练习题库）
/// 与 `assets/pools/ch*.json.gz`（章节试炼池），统一 rootBundle 读资产
/// + `GZipCodec` 解压（P0-PRA-01 底座，T-DOM-03）。
///
/// 设计要点：
/// - **跨端统一用 `flutter/services.dart` 的 rootBundle 读资产**（移动端
///   与桌面端 assets 均打包原始字节），不区分平台路径；
/// - [loader] 可注入（测试提供假资产字节），生产默认 rootBundle；
/// - 解压后 JSON 结构见批次 D 导出格式：顶层 `{schemaVersion, difficulty,
///   count, puzzles:[...]}`，每条 puzzle 含 `puzzle81 / solution81 /
///   givenMask / difficulty / techniques / usageCounts` 等；
/// - 解析产物复用 core 的 [Puzzle] 值对象（题面 + 终局解 + givenMask +
///   难度 + 技巧标签），与算法层零重复；
/// - 已解析的题库做**内存缓存**，避免反复解压（首次解压后常驻）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';

/// 题库 JSON schema 版本（架构文档 §7.2）。
const int kPuzzleBankSchemaVersion = 1;

/// 资产字节加载函数（注入测试用；生产默认 [defaultAssetLoader]）。
typedef PuzzleAssetLoader = Future<Uint8List> Function(String assetPath);

/// 生产默认加载器：rootBundle 读资产原始字节。
Future<Uint8List> defaultAssetLoader(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
}

/// 一档题库（解析后的内存形态）。
class DifficultyBank {
  /// 构造一档题库。
  DifficultyBank({
    required this.difficulty,
    required List<Puzzle> puzzles,
  }) : puzzles = List<Puzzle>.unmodifiable(puzzles);

  /// 档位。
  final Difficulty difficulty;

  /// 题库列表（不可变）。
  final List<Puzzle> puzzles;

  /// 题库数量。
  int get count => puzzles.length;
}

/// 一章试炼池（解析后的内存形态）。
class TrialPool {
  /// 构造试炼池。
  TrialPool({
    required this.chapter,
    required Set<TechniqueId> targetTechniques,
    required List<Puzzle> puzzles,
  })  : targetTechniques = Set<TechniqueId>.unmodifiable(targetTechniques),
        puzzles = List<Puzzle>.unmodifiable(puzzles);

  /// 章节号（0..3）。
  final int chapter;

  /// 本章目标技巧（P0-CLI-06：每章必含本章目标技巧）。
  final Set<TechniqueId> targetTechniques;

  /// 题池列表（不可变）。
  final List<Puzzle> puzzles;

  /// 题池数量。
  int get count => puzzles.length;
}

/// 题库仓库。
class PuzzleBankRepository {
  /// 构造仓库；[loader] 缺省用 [defaultAssetLoader]（rootBundle）。
  PuzzleBankRepository({PuzzleAssetLoader? loader})
      : _loader = loader ?? defaultAssetLoader;

  final PuzzleAssetLoader _loader;

  /// 五档题库内存缓存（难度 → 题库）。
  final Map<Difficulty, DifficultyBank> _bankCache =
      <Difficulty, DifficultyBank>{};

  /// 试炼池内存缓存（章节 → 池）。
  final Map<int, TrialPool> _poolCache = <int, TrialPool>{};

  /// 读原始 gz 字节（供测试与二次封装）。
  Future<Uint8List> loadRaw(String assetPath) => _loader(assetPath);

  /// 读 gz 资产并解压为 UTF-8 文本。
  Future<String> loadGzText(String assetPath) async {
    final Uint8List bytes;
    try {
      bytes = await _loader(assetPath);
    } on Object catch (e) {
      throw AppError('E_IO_003', '题库资产缺失：$assetPath', e);
    }
    try {
      return utf8.decode(GZipCodec().decode(bytes));
    } on Object catch (e) {
      throw AppError('E_IO_003', '题库资产解压失败：$assetPath', e);
    }
  }

  /// 加载五档题库（带缓存）。
  Future<DifficultyBank> loadBank(Difficulty difficulty) async {
    final DifficultyBank? cached = _bankCache[difficulty];
    if (cached != null) {
      return cached;
    }
    final String text = await loadGzText(_bankAsset(difficulty));
    final DifficultyBank bank = _parseBank(text, difficulty);
    _bankCache[difficulty] = bank;
    return bank;
  }

  /// 加载章节试炼池（带缓存）。
  Future<TrialPool> loadPool(int chapter) async {
    final TrialPool? cached = _poolCache[chapter];
    if (cached != null) {
      return cached;
    }
    final String text = await loadGzText(_poolAsset(chapter));
    final TrialPool pool = _parsePool(text, chapter);
    _poolCache[chapter] = pool;
    return pool;
  }

  // ------------------------------------------------------------ 内部

  /// 五档题库资产路径。
  static String _bankAsset(Difficulty difficulty) =>
      'assets/puzzles/${difficulty.id}.json.gz';

  /// 章节试炼池资产路径。
  static String _poolAsset(int chapter) => 'assets/pools/ch$chapter.json.gz';

  /// 解析一档题库 JSON 文本。
  DifficultyBank _parseBank(String text, Difficulty expected) {
    final Map<String, Object?> root = _decodeRoot(text, '题库');
    _checkSchema(root);
    final Object? rawPuzzles = root['puzzles'];
    if (rawPuzzles is! List) {
      throw AppError('E_IO_003', '题库缺少 puzzles 数组');
    }
    return DifficultyBank(
      difficulty: expected,
      puzzles: <Puzzle>[
        for (final Object? item in rawPuzzles)
          _parsePuzzle(item! as Map<String, Object?>),
      ],
    );
  }

  /// 解析一章试炼池 JSON 文本。
  TrialPool _parsePool(String text, int chapter) {
    final Map<String, Object?> root = _decodeRoot(text, '试炼池');
    _checkSchema(root);
    final Object? rawPuzzles = root['puzzles'];
    if (rawPuzzles is! List) {
      throw AppError('E_IO_003', '试炼池缺少 puzzles 数组');
    }
    final Set<TechniqueId> targets = <TechniqueId>{};
    final Object? rawTargets = root['targetTechniques'];
    if (rawTargets is List) {
      for (final Object? id in rawTargets) {
        final TechniqueId? technique = TechniqueId.tryParse(id! as String);
        if (technique != null) {
          targets.add(technique);
        }
      }
    }
    return TrialPool(
      chapter: chapter,
      targetTechniques: targets,
      puzzles: <Puzzle>[
        for (final Object? item in rawPuzzles)
          _parsePuzzle(item! as Map<String, Object?>),
      ],
    );
  }

  /// 解析单条 puzzle 记录（字段缺失容错，难度/技巧可选）。
  Puzzle _parsePuzzle(Map<String, Object?> json) {
    final String puzzle81 = json['puzzle81']! as String;
    final String solution81 = json['solution81']! as String;
    final Board given = Board.fromPuzzleString(puzzle81, markGivens: false);
    final List<int> solution = <int>[
      for (final String ch in solution81.split('')) int.parse(ch),
    ];

    // givenMask：优先取资产里固化的掩码，缺省按非空推断。
    List<bool> givenMask = <bool>[for (final int v in given.values) v != 0];
    final Object? rawMask = json['givenMask'];
    if (rawMask is String && rawMask.length == kCellCount) {
      givenMask = <bool>[
        for (final String ch in rawMask.split('')) ch == '1',
      ];
    }

    final Set<TechniqueId> techniques = <TechniqueId>{};
    final Object? rawTechniques = json['techniques'];
    if (rawTechniques is List) {
      for (final Object? id in rawTechniques) {
        final TechniqueId? technique = TechniqueId.tryParse(id! as String);
        if (technique != null) {
          techniques.add(technique);
        }
      }
    }

    return Puzzle(
      given: given.toValueList(),
      solution: solution,
      givenMask: givenMask,
      difficulty: _difficultyOf(json['difficulty']),
      techniques: techniques,
      seed: (json['seed'] as int?) ?? 0,
    );
  }

  /// 解析难度（未知回退 null，由调用方按档位兜底）。
  Difficulty? _difficultyOf(Object? raw) {
    if (raw is! String) {
      return null;
    }
    return Difficulty.tryParse(raw);
  }

  /// 顶层 JSON 解码（格式非法抛 E_IO_003）。
  Map<String, Object?> _decodeRoot(String text, String what) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw AppError('E_IO_003', '$what JSON 非法', e);
    }
    if (decoded is! Map) {
      throw AppError('E_IO_003', '$what 顶层必须是 JSON 对象');
    }
    return Map<String, Object?>.from(decoded);
  }

  /// schema 版本校验：高于当前支持版本即拒绝（E_SCHEMA_001）。
  void _checkSchema(Map<String, Object?> root) {
    final int version = (root['schemaVersion'] as int?) ?? 1;
    if (version > kPuzzleBankSchemaVersion) {
      throw AppError.schemaTooNew(version, kPuzzleBankSchemaVersion);
    }
  }
}
