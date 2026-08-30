/// T-UI-08 · 首次启动引导页测试（S-01 / P0-UI-08）。
///
/// 覆盖（对齐任务验收点）：
/// - 3 页横滑（PageView：产品定位 → 教学体系 → 自由练习），每页标题/副文案；
/// - 底部页码点（3 个，当前页高亮）；
/// - 右上角常驻「跳过」；
/// - 末页「开始学习」按钮；
/// - **跳过 / 开始学习**都写入 `onboardingDone=true` 并直达第 0 章第 1 关
///   （测试课程索引 ch0 首关为 demo → `/demo/ch0_l01`）；
/// - `onboardingDone=true` 时初始路由为学习地图，引导页不再出现。
///
/// 数据注入：内存 `FakeProgressRepository` + 内存课程 loader
/// （[buildTeachingCurriculumLoader]，ch0 首关为 demo）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/app.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/ui/features/onboarding/onboarding_page.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

void main() {
  late GoRouter router;

  Future<void> pumpOnboarding(
    WidgetTester tester,
    FakeProgressRepository repo,
  ) async {
    router = GoRouter(
      initialLocation: RoutePaths.onboarding,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.onboarding,
          name: RouteNames.onboarding,
          builder: (_, __) => const OnboardingPage(),
        ),
        GoRoute(
          path: RoutePaths.demo,
          name: RouteNames.demo,
          builder: (_, __) => const Scaffold(body: Text('demo-page')),
        ),
        GoRoute(
          path: RoutePaths.practiceLevel,
          name: RouteNames.practiceLevel,
          builder: (_, __) => const Scaffold(body: Text('practice-page')),
        ),
        GoRoute(
          path: RoutePaths.trial,
          name: RouteNames.trial,
          builder: (_, __) => const Scaffold(body: Text('trial-page')),
        ),
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (_, __) => const Scaffold(body: Text('home-page')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
          curriculumRepositoryProvider.overrideWithValue(
            CurriculumRepository(
              loader: buildTeachingCurriculumLoader(
                levelJsonById: buildDefaultTeachingLevels(),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pump();
  }

  /// 跳到最后一页（走「下一步」按钮，确定性推进）。
  Future<void> goToLastPage(WidgetTester tester) async {
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
  }

  group('T-UI-08 首次启动引导', () {
    testWidgets('3 页横滑 + 页码点 + 常驻「跳过」', (WidgetTester tester) async {
      await pumpOnboarding(tester, FakeProgressRepository());

      // 第 1 页：产品定位。
      expect(find.text('零门槛入门数独'), findsOneWidget);
      // 页码点（3 个）。
      for (int i = 0; i < 3; i++) {
        expect(
          find.byKey(ValueKey<String>('onboarding-dot-$i')),
          findsOneWidget,
          reason: '页码点 $i',
        );
      }
      // 「跳过」右上角常驻。
      expect(find.text('跳过'), findsOneWidget);
      // 末页按钮尚未出现。
      expect(find.text('开始学习'), findsNothing);

      // 「下一步」→ 第 2 页：教学体系。
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('四章渐进学习'), findsOneWidget);
      expect(find.text('跳过'), findsOneWidget, reason: '跳过常驻');

      // 「下一步」→ 第 3 页：自由练习 + 「开始学习」。
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      expect(find.text('海量题库 · 即时反馈'), findsOneWidget);
      expect(find.text('开始学习'), findsOneWidget);
      expect(find.text('下一步'), findsNothing);
    });

    testWidgets('「跳过」→ onboardingDone 落盘并直达 /demo/ch0_l01',
        (WidgetTester tester) async {
      final FakeProgressRepository repo = FakeProgressRepository();
      await pumpOnboarding(tester, repo);

      expect(repo.current.onboardingDone, isFalse, reason: '初始未完成');

      await tester.tap(find.text('跳过'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repo.current.onboardingDone, isTrue, reason: '跳过即视为完成');
      expect(router.state.uri.path, '/demo/ch0_l01',
          reason: '完成引导直达第 0 章第 1 关（当前索引 ch0 首关为 demo）');
    });

    testWidgets('末页「开始学习」→ onboardingDone 落盘并直达 /demo/ch0_l01',
        (WidgetTester tester) async {
      final FakeProgressRepository repo = FakeProgressRepository();
      await pumpOnboarding(tester, repo);

      await goToLastPage(tester);
      await tester.tap(find.text('开始学习'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(repo.current.onboardingDone, isTrue, reason: '完成引导落盘');
      expect(router.state.uri.path, '/demo/ch0_l01');
    });

    testWidgets('onboardingDone=true 时初始路由为学习地图，引导页不再出现',
        (WidgetTester tester) async {
      final FakeProgressRepository repo = FakeProgressRepository(
        initial: const ProgressState(
          schemaVersion: 1,
          deviceId: 'test',
          onboardingDone: true,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            progressRepositoryProvider.overrideWith((Ref ref) async => repo),
            curriculumRepositoryProvider.overrideWithValue(
              CurriculumRepository(
                loader: buildTeachingCurriculumLoader(
                  levelJsonById: buildDefaultTeachingLevels(),
                ),
              ),
            ),
          ],
          child: const SudokuTutorApp(initialLocation: RoutePaths.home),
        ),
      );
      // 推进课程状态加载。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // 引导页不再出现；学习地图出现。
      expect(find.text('零门槛入门数独'), findsNothing);
      expect(find.text('学习地图'), findsOneWidget);
    });
  });
}
