/// `PuzzleCollection` 集合 JSON 编解码单测。
library;

import 'package:test/test.dart';
import 'package:sudoku_core/sudoku_core.dart';

import 'package:sudoku_cli/sudoku_cli.dart';

void main() {
  test('集合 encode/decode 往返一致', () {
    final Puzzle core1 = PuzzleGenerator().generate(Rng(1), targetGivens: 36);
    final Puzzle core2 = PuzzleGenerator().generate(Rng(2), targetGivens: 36);
    final List<AnnotatedPuzzle> puzzles = <AnnotatedPuzzle>[
      fromPuzzleOnly(puzzle: core1, seed: 1),
      fromPuzzleOnly(puzzle: core2, seed: 2),
    ];
    final Map<String, Object?> json = PuzzleCollection.encode(
      kind: CollectionKind.generated,
      profile: 't2',
      seed: 42,
      concurrency: 2,
      puzzles: puzzles,
    );
    expect(json['schemaVersion'], kAnnotatedSchemaVersion);
    expect(json['count'], 2);

    final ParsedCollection parsed = PuzzleCollection.decode(json);
    expect(parsed.kind, 'generated');
    expect(parsed.profile, 't2');
    expect(parsed.seed, 42);
    expect(parsed.concurrency, 2);
    expect(parsed.puzzles.length, 2);
    expect(parsed.puzzles.first.puzzle81, puzzles.first.puzzle81);
  });

  test('schemaVersion 不匹配抛 FormatException', () {
    expect(
      () => PuzzleCollection.decode(<String, Object?>{
        'schemaVersion': 99,
        'puzzles': <Object?>[],
      }),
      throwsFormatException,
    );
  });

  test('缺 puzzles 抛 FormatException', () {
    expect(
      () => PuzzleCollection.decode(<String, Object?>{
        'schemaVersion': kAnnotatedSchemaVersion,
      }),
      throwsFormatException,
    );
  });
}
