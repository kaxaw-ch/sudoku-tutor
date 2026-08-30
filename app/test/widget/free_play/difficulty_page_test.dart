/// T-UI-04 · 难度选择页测试（S-07，P0-PRA-01/09/10）。
///
/// 覆盖：
/// - 五档难度卡片渲染（入门/简单/中等/困难/大师）与「最高需用到 XX 技巧」
///   文案存在（读题库代表题技巧标注）；
/// - 无断点存档：`ResumeBanner` 不出现；
/// - 有断点存档：`ResumeBanner` 出现且「继续上次对局 / 开始新局（将覆盖）」
///   两个操作存在；
/// - 底部「从文本导入题目」入口存在。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/session_snapshot.dart';
import 'package:sudoku_tutor/ui/features/free_play/difficulty_page.dart';
import 'package:sudoku_tutor/ui/features/free_play/free_play_page.dart';
import 'package:sudoku_tutor/ui/features/free_play/resume_banner.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  Future<void> pumpDifficultyPage(
    WidgetTester tester,
    FakeProgressRepository repo,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/free-play',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
        ),
        GoRoute(
          path: '/free-play',
          name: 'difficulty',
          builder: (_, __) => const DifficultyPage(),
        ),
        GoRoute(
          path: '/free-play/session',
          name: 'freePlay',
          builder: (_, __) => const FreePlayPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
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
    // 推进 hasSessionProvider / difficultyMetaProvider 的异步加载。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('五档难度卡片渲染 + 最高需用到技巧文案', (WidgetTester tester) async {
    await pumpDifficultyPage(tester, FakeProgressRepository());

    for (final Difficulty d in Difficulty.values) {
      expect(find.text(d.zhName), findsOneWidget, reason: '${d.zhName} 卡片');
    }
    // 每档卡片下都有「最高需用到：XX 技巧」说明（加载完成后）。
    expect(find.textContaining('最高需用到：'), findsNWidgets(5));
    // 底部入口。
    expect(find.text('从文本导入题目'), findsOneWidget);
  });

  testWidgets('无断点存档：ResumeBanner 不出现', (WidgetTester tester) async {
    await pumpDifficultyPage(tester, FakeProgressRepository());
    expect(find.byType(ResumeBanner), findsNothing);
    expect(find.text('检测到未完成的对局'), findsNothing);
  });

  testWidgets('有断点存档：ResumeBanner 出现且双操作存在', (WidgetTester tester) async {
    final Puzzle puzzle = buildTestPuzzle();
    final FakeProgressRepository repo = FakeProgressRepository()
      ..snapshot = SessionSnapshot(
        puzzle81: puzzle.givenString,
        board81: puzzle.givenString,
        elapsedMs: 1200,
        difficultyId: Difficulty.medium.id,
        solution81: puzzle.solutionString,
      );
    await pumpDifficultyPage(tester, repo);

    expect(find.byType(ResumeBanner), findsOneWidget);
    expect(find.text('检测到未完成的对局'), findsOneWidget);
    expect(find.text('继续上次对局'), findsOneWidget);
    expect(find.text('开始新局（将覆盖）'), findsOneWidget);
  });
}
