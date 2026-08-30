/// go_router 路由表（批次 E 收口：T-UI-04/T-UI-05 全部接入）。
library;

import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
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
          builder: (_, __) => const DemoPage(),
        ),
        GoRoute(
          path: RoutePaths.practiceLevel,
          name: RouteNames.practiceLevel,
          builder: (_, __) => const PracticeLevelPage(),
        ),
        GoRoute(
          path: RoutePaths.trial,
          name: RouteNames.trial,
          builder: (_, __) => const TrialPage(),
        ),
      ],
    );
