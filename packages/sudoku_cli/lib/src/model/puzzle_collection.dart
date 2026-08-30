/// 标注集合（批量题目 JSON）的读写封装。
///
/// `generate` / `annotate` / `filter` 命令共用同一份 JSON 形态：
/// ```jsonc
/// {
///   "schemaVersion": 1,
///   "kind": "annotated" | "generated",
///   "profile": "t2",
///   "seed": 123,
///   "concurrency": 1,
///   "count": 50,
///   "puzzles": [ <AnnotatedPuzzle.toJson()> ... ]
/// }
/// ```
/// 纯数据编解码，不涉及任何算法。
library;

import 'annotated_puzzle.dart';

/// 集合的 kind 取值。
enum CollectionKind {
  /// 仅题面（generate 未标注）。
  generated('generated'),

  /// 完整标注（难度 + 技巧 + 脚本）。
  annotated('annotated');

  const CollectionKind(this.id);

  /// 稳定标识。
  final String id;
}

/// 解析后的集合（record 形式，命令层直接使用）。
typedef ParsedCollection = ({
  String profile,
  String kind,
  int seed,
  int concurrency,
  List<AnnotatedPuzzle> puzzles,
});

/// 集合 JSON 编解码。
abstract final class PuzzleCollection {
  /// 编码为 JSON map。
  static Map<String, Object?> encode({
    required CollectionKind kind,
    required String profile,
    required int seed,
    required int concurrency,
    required List<AnnotatedPuzzle> puzzles,
  }) =>
      <String, Object?>{
        'schemaVersion': kAnnotatedSchemaVersion,
        'kind': kind.id,
        'profile': profile,
        'seed': seed,
        'concurrency': concurrency,
        'count': puzzles.length,
        'puzzles': <Map<String, Object?>>[
          for (final AnnotatedPuzzle puzzle in puzzles) puzzle.toJson(),
        ],
      };

  /// 解码为 [ParsedCollection]；结构非法抛 [FormatException]。
  static ParsedCollection decode(Map<String, Object?> root) {
    final Object? rawVersion = root['schemaVersion'];
    if (rawVersion != kAnnotatedSchemaVersion) {
      throw FormatException('集合 schemaVersion 为 $rawVersion，期望 $kAnnotatedSchemaVersion');
    }
    final Object? rawPuzzles = root['puzzles'];
    if (rawPuzzles is! List<Object?>) {
      throw const FormatException('集合缺少 puzzles 列表');
    }
    final List<AnnotatedPuzzle> puzzles = <AnnotatedPuzzle>[
      for (final Object? item in rawPuzzles)
        AnnotatedPuzzle.fromJson(item! as Map<String, Object?>),
    ];
    return (
      profile: (root['profile'] as String?) ?? 't2',
      kind: (root['kind'] as String?) ?? 'annotated',
      seed: (root['seed'] as int?) ?? 0,
      concurrency: (root['concurrency'] as int?) ?? 1,
      puzzles: puzzles,
    );
  }
}
