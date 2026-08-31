import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/duel/async_duel_codec.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/ui/features/async_duel/async_duel_page.dart';
import 'package:sudoku_tutor/ui/features/free_play/free_play_page.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  late GoRouter router;
  Object? receivedLaunch;

  Future<void> pumpPage(
    WidgetTester tester, {
    AsyncDuelResult? initialResult,
  }) async {
    receivedLaunch = null;
    router = GoRouter(
      initialLocation: RoutePaths.asyncDuel,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.asyncDuel,
          name: RouteNames.asyncDuel,
          builder: (_, __) => AsyncDuelPage(initialResult: initialResult),
        ),
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (_, __) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: RoutePaths.freePlay,
          name: RouteNames.freePlay,
          builder: (_, GoRouterState state) {
            receivedLaunch = state.extra;
            return const Scaffold(body: Text('challenge-game'));
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          puzzleBankRepositoryProvider.overrideWithValue(
            FakePuzzleBankRepository(),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('显示三段离线流程并可生成挑战码', (WidgetTester tester) async {
    await pumpPage(tester);

    expect(find.text('离线对决'), findsOneWidget);
    expect(find.text('发起挑战'), findsOneWidget);
    expect(find.text('接受挑战'), findsOneWidget);
    expect(find.text('比较成绩'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('duel-player-name')),
      '小明',
    );
    await tester.tap(find.byKey(const ValueKey<String>('create-duel-code')));
    await tester.pumpAndSettle();

    final Finder box = find.byKey(const ValueKey<String>('created-duel-code'));
    expect(box, findsOneWidget);
    final SelectableText codeText = tester.widget<SelectableText>(
      find.descendant(of: box, matching: find.byType(SelectableText)),
    );
    expect(codeText.data, startsWith('SDKD1.'));
    expect(AsyncDuelCodec.decodeChallenge(codeText.data!).challengerName, '小明');
  });

  testWidgets('导入有效挑战码后携带挑战与昵称进入做题页', (WidgetTester tester) async {
    await pumpPage(tester);
    final AsyncDuelChallenge challenge = AsyncDuelChallenge.create(
      challengerName: '发起者',
      puzzle: buildTestPuzzle(difficulty: Difficulty.easy),
      difficulty: Difficulty.easy,
      createdAtMs: 1700000000000,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('duel-player-name')),
      '应战者',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('challenge-code-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('challenge-code-input')),
      AsyncDuelCodec.encodeChallenge(challenge),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('join-duel')));
    await tester.pumpAndSettle();

    expect(find.text('challenge-game'), findsOneWidget);
    expect(receivedLaunch, isA<FreePlayLaunchChallenge>());
    final FreePlayLaunchChallenge launch =
        receivedLaunch! as FreePlayLaunchChallenge;
    expect(launch.playerName, '应战者');
    expect(launch.challenge.id, challenge.id);
  });

  testWidgets('两份同挑战成绩码可离线比较胜负', (WidgetTester tester) async {
    final AsyncDuelChallenge challenge = AsyncDuelChallenge.create(
      challengerName: '甲',
      puzzle: buildTestPuzzle(difficulty: Difficulty.medium),
      difficulty: Difficulty.medium,
      createdAtMs: 1700000000000,
    );
    final AsyncDuelResult first = AsyncDuelResult.completed(
      challenge: challenge,
      playerName: '甲',
      elapsedMs: 60000,
      wrongCount: 0,
    );
    final AsyncDuelResult second = AsyncDuelResult.completed(
      challenge: challenge,
      playerName: '乙',
      elapsedMs: 65000,
      wrongCount: 0,
    );
    await pumpPage(tester, initialResult: first);

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('second-result-input')),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('second-result-input')),
      AsyncDuelCodec.encodeResult(second),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('compare-duel-results')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('compare-duel-results')),
    );
    await tester.pump();

    expect(find.text('甲 获胜'), findsOneWidget);
    expect(find.textContaining('甲：01:00'), findsOneWidget);
  });
}
