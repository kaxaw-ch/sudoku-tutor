import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/duel/async_duel_codec.dart';

final Puzzle _puzzle = Puzzle(
  given: Board.fromPuzzleString(
    '59.43..8...3..97....6....4..649.7..82798....18.5..3..7..8.25...731.....5.5.......',
  ).toValueList(),
  solution: <int>[
    for (final String ch
        in '597432186483169752126578349364917528279856431815243967948725613731684295652391874'
            .split(''))
      int.parse(ch),
  ],
  difficulty: Difficulty.medium,
);

void main() {
  group('AsyncDuelCodec 挑战码', () {
    test('编码后可在另一设备仅凭题面恢复同一唯一解', () {
      final AsyncDuelChallenge source = AsyncDuelChallenge.create(
        challengerName: '小明',
        puzzle: _puzzle,
        difficulty: Difficulty.medium,
        createdAtMs: 1700000000000,
      );

      final String code = AsyncDuelCodec.encodeChallenge(source);
      final AsyncDuelChallenge decoded =
          AsyncDuelCodec.decodeChallenge('  $code\n');

      expect(code, startsWith('SDKD1.'));
      expect(decoded.id, source.id);
      expect(decoded.challengerName, '小明');
      expect(decoded.difficulty, Difficulty.medium);
      expect(decoded.puzzle.givenString, _puzzle.givenString);
      expect(decoded.puzzle.solution, _puzzle.solution);
      expect(decoded.puzzle.fingerprint, _puzzle.fingerprint);
    });

    test('复制损坏会被校验和拒绝', () {
      final String code = AsyncDuelCodec.encodeChallenge(
        AsyncDuelChallenge.create(
          challengerName: 'A',
          puzzle: _puzzle,
          difficulty: Difficulty.easy,
          createdAtMs: 1700000000000,
        ),
      );
      final String broken = '${code.substring(0, code.length - 1)}0';

      expect(
        () => AsyncDuelCodec.decodeChallenge(broken),
        throwsA(
          isA<AsyncDuelCodeException>().having(
            (AsyncDuelCodeException e) => e.message,
            'message',
            contains('校验失败'),
          ),
        ),
      );
    });

    test('昵称长度受限', () {
      expect(
        () => AsyncDuelChallenge.create(
          challengerName: '12345678901234567',
          puzzle: _puzzle,
          difficulty: Difficulty.easy,
        ),
        throwsA(isA<AsyncDuelCodeException>()),
      );
    });
  });

  group('AsyncDuelCodec 成绩码', () {
    late AsyncDuelChallenge challenge;

    setUp(() {
      challenge = AsyncDuelChallenge.create(
        challengerName: '甲',
        puzzle: _puzzle,
        difficulty: Difficulty.medium,
        createdAtMs: 1700000000000,
      );
    });

    test('成绩往返保留用时、错误和计分', () {
      final AsyncDuelResult source = AsyncDuelResult.completed(
        challenge: challenge,
        playerName: '乙',
        elapsedMs: 65000,
        wrongCount: 2,
        completedAtMs: 1700000100000,
      );
      final String code = AsyncDuelCodec.encodeResult(source);
      final AsyncDuelResult decoded = AsyncDuelCodec.decodeResult(code);

      expect(code, startsWith('SDKR1.'));
      expect(decoded.challengeId, challenge.id);
      expect(decoded.playerName, '乙');
      expect(decoded.elapsedMs, 65000);
      expect(decoded.wrongCount, 2);
      expect(decoded.scoreMs, 75000);
    });

    test('按实际用时加错误罚时比较胜负', () {
      final AsyncDuelResult fastButWrong = AsyncDuelResult.completed(
        challenge: challenge,
        playerName: '甲',
        elapsedMs: 60000,
        wrongCount: 2,
      );
      final AsyncDuelResult steady = AsyncDuelResult.completed(
        challenge: challenge,
        playerName: '乙',
        elapsedMs: 68000,
        wrongCount: 0,
      );

      final AsyncDuelComparison comparison =
          AsyncDuelCodec.compare(fastButWrong, steady);
      expect(comparison.winner, same(steady));
      expect(comparison.isDraw, isFalse);
    });

    test('不同挑战的成绩不可比较', () {
      final AsyncDuelResult first = AsyncDuelResult.completed(
        challenge: challenge,
        playerName: '甲',
        elapsedMs: 60000,
        wrongCount: 0,
      );
      final AsyncDuelChallenge other = AsyncDuelChallenge.create(
        challengerName: '乙',
        puzzle: _puzzle,
        difficulty: Difficulty.medium,
        createdAtMs: 1700000000001,
      );
      final AsyncDuelResult second = AsyncDuelResult.completed(
        challenge: other,
        playerName: '乙',
        elapsedMs: 59000,
        wrongCount: 0,
      );

      expect(
        () => AsyncDuelCodec.compare(first, second),
        throwsA(isA<AsyncDuelCodeException>()),
      );
    });
  });
}
