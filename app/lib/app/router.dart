/// go_router 路由表（批次 E 收口：T-UI-04/T-UI-05 全部接入）。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/duel/async_duel_codec.dart';
import 'package:sudoku_tutor/ui/features/async_duel/async_duel_page.dart';
import 'package:sudoku_tutor/ui/features/demo/demo_page.dart';
import 'package:sudoku_tutor/ui/features/developer/developer_page.dart';
import 'package:sudoku_tutor/ui/features/free_play/difficulty_page.dart';
import 'package:sudoku_tutor/ui/features/free_play/free_play_page.dart';
import 'package:sudoku_tutor/ui/features/home/home_page.dart';
import 'package:sudoku_tutor/ui/features/onboarding/onboarding_page.dart';
import 'package:sudoku_tutor/ui/features/practice_level/practice_level_page.dart';
import 'package:sudoku_tutor/ui/features/settings/settings_page.dart';
import 'package:sudoku_tutor/ui/features/trial/trial_page.dart';
import 'package:sudoku_tutor/ui/features/wiki/technique_wiki_page.dart';

/// 构建应用路由表。
GoRouter buildRouter({String initialLocation = RoutePaths.home}) => GoRouter(
      initialLocation: initialLocation,
      debugLogDiagnostics: false,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (_, __) => const SettingsPage(),
          routes: <RouteBase>[
            GoRoute(
              path: 'developer',
              name: RouteNames.developer,
              builder: (_, __) => const DeveloperPage(),
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.wiki,
          name: RouteNames.wiki,
          builder: (_, __) => const TechniqueWikiPage(),
        ),
        GoRoute(
          path: RoutePaths.asyncDuel,
          name: RouteNames.asyncDuel,
          builder: (_, GoRouterState state) => AsyncDuelPage(
            initialResult: state.extra is AsyncDuelResult
                ? state.extra! as AsyncDuelResult
                : null,
          ),
        ),
        GoRoute(
          path: RoutePaths.onboarding,
          name: RouteNames.onboarding,
          builder: (_, __) => const OnboardingPage(),
        ),
        GoRoute(
          path: RoutePaths.difficulty,
          name: RouteNames.difficulty,
          builder: (_, __) => const DifficultyPage(),
        ),
        GoRoute(
          path: RoutePaths.freePlay,
          name: RouteNames.freePlay,
          builder: (_, __) => const FreePlayPage(),
        ),
        GoRoute(
          path: RoutePaths.demo,
          name: RouteNames.demo,
          pageBuilder: (_, GoRouterState state) {
            final String levelId = state.pathParameters['levelId'] ?? '';
            return MaterialPage<void>(
              // 路由模板相同而参数变化时，go_router 可能复用子树。
              // 同时把 levelId 传入页面并设置 key，确保连续同类型关卡重载。
              key: ValueKey<String>('demo-$levelId'),
              child: DemoPage(
                key: ValueKey<String>('demo-content-$levelId'),
                levelId: levelId,
              ),
            );
          },
        ),
        GoRoute(
          path: RoutePaths.practiceLevel,
          name: RouteNames.practiceLevel,
          pageBuilder: (_, GoRouterState state) {
            final String levelId = state.pathParameters['levelId'] ?? '';
            return MaterialPage<void>(
              key: ValueKey<String>('practice-$levelId'),
              child: PracticeLevelPage(
                key: ValueKey<String>('practice-content-$levelId'),
                levelId: levelId,
              ),
            );
          },
        ),
        GoRoute(
          path: RoutePaths.trial,
          name: RouteNames.trial,
          pageBuilder: (_, GoRouterState state) {
            final String levelId = state.pathParameters['levelId'] ?? '';
            return MaterialPage<void>(
              key: ValueKey<String>('trial-$levelId'),
              child: TrialPage(
                key: ValueKey<String>('trial-content-$levelId'),
                levelId: levelId,
              ),
            );
          },
        ),
      ],
    );
