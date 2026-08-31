/// T-EDU-06 · 学习地图主页测试（S-02）。
///
/// 覆盖（对齐任务验收点）：
/// - 章节纵向卡片渲染：章号「第 N 章」/名称/本章技巧标签组/进度 `n/m`；
/// - 所有章节与关卡都可自由展开、进入；
/// - 点击章节卡片展开/收起关卡格栅（展开动画）；
/// - 关卡格栅无锁态，每关直接展示“主技巧 + 完整类型”，已完成时显示星数；
/// - 「自由练习」入口常驻并跳转 `/free-play`；
/// - 点击关卡 → 按关类型跳路由：demo→`/demo/:id`、实操→`/practice/:id`、
///   trial→`/trial/:id`。
///
/// 数据注入：内存 `FakeProgressRepository` + 内存课程 loader（两章四关），
/// 全程不触真实 path_provider / rootBundle。
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/ui/features/home/home_page.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

/// 两章索引：第 0 章 3 关（demo/实操/试炼）+ 第 1 章 1 关（demo，默认锁态）。
String _indexJson() => jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'chapters': <Object?>[
        <String, Object?>{
          'chapter': 0,
          'title': '第 0 章 · 测试',
          'techniqueTags': <String>['nakedSingle', 'hiddenSingle'],
          'levels': <Object?>[
            <String, Object?>{
              'id': 'ch0_l01',
              'chapter': 0,
              'order': 1,
              'kind': 'demo',
              'title': '演示关',
              'techniqueTags': <String>['nakedSingle'],
              'file': 'ch0_l01.json',
            },
            <String, Object?>{
              'id': 'ch0_l02',
              'chapter': 0,
              'order': 2,
              'kind': 'guidedPractice',
              'title': '实操关',
              'techniqueTags': <String>['hiddenSingle'],
              'file': 'ch0_l02.json',
            },
            <String, Object?>{
              'id': 'ch0_l03',
              'chapter': 0,
              'order': 3,
              'kind': 'trial',
              'title': '试炼关',
              'techniqueTags': <String>['hiddenSingle'],
              'file': 'ch0_l03.json',
            },
          ],
        },
        <String, Object?>{
          'chapter': 1,
          'title': '第 1 章 · 进阶',
          'techniqueTags': <String>['xWing'],
          'levels': <Object?>[
            <String, Object?>{
              'id': 'ch1_l01',
              'chapter': 1,
              'order': 1,
              'kind': 'demo',
              'title': 'X 翼演示',
              'techniqueTags': <String>['xWing'],
              'file': 'ch1_l01.json',
            },
          ],
        },
      ],
    });

/// 内存课程 loader（两章四关，index 由 [_indexJson] 提供）。
CurriculumAssetLoader _homeCurriculumLoader() {
  final Map<String, String> levels = <String, String>{
    'assets/curriculum/ch0_l01.json': buildTeachingLevelJson(
      id: 'ch0_l01',
      kind: 'demo',
      title: '演示关',
      techniqueTags: const <TechniqueId>{TechniqueId.nakedSingle},
    ),
    'assets/curriculum/ch0_l02.json': buildTeachingLevelJson(
      id: 'ch0_l02',
      kind: 'guidedPractice',
      order: 2,
      title: '实操关',
      techniqueTags: const <TechniqueId>{TechniqueId.hiddenSingle},
    ),
    'assets/curriculum/ch0_l03.json': buildTeachingLevelJson(
      id: 'ch0_l03',
      kind: 'trial',
      order: 3,
      title: '试炼关',
      techniqueTags: const <TechniqueId>{TechniqueId.hiddenSingle},
    ),
    'assets/curriculum/ch1_l01.json': buildTeachingLevelJson(
      id: 'ch1_l01',
      kind: 'demo',
      chapter: 1,
      title: 'X 翼演示',
      techniqueTags: const <TechniqueId>{TechniqueId.xWing},
    ),
  };
  return (String path) async {
    if (path == 'assets/curriculum/index.json') {
      return _indexJson();
    }
    return levels[path] ?? '';
  };
}

void main() {
  late GoRouter router;

  Future<void> pumpHome(
    WidgetTester tester,
    FakeProgressRepository repo,
  ) async {
    router = GoRouter(
      initialLocation: RoutePaths.home,
      routes: <RouteBase>[
        GoRoute(
          path: RoutePaths.home,
          name: RouteNames.home,
          builder: (_, __) => const HomePage(),
        ),
        GoRoute(
          path: RoutePaths.difficulty,
          name: RouteNames.difficulty,
          builder: (_, __) => const Scaffold(body: Text('difficulty-page')),
        ),
        GoRoute(
          path: RoutePaths.settings,
          name: RouteNames.settings,
          builder: (_, __) => const Scaffold(body: Text('settings-page')),
        ),
        GoRoute(
          path: RoutePaths.wiki,
          name: RouteNames.wiki,
          builder: (_, __) => const Scaffold(body: Text('wiki-page')),
        ),
        GoRoute(
          path: RoutePaths.asyncDuel,
          name: RouteNames.asyncDuel,
          builder: (_, __) => const Scaffold(body: Text('async-duel-page')),
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
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
          curriculumRepositoryProvider.overrideWithValue(
            CurriculumRepository(loader: _homeCurriculumLoader()),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    // 推进 curriculumStateProvider 异步加载。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// 断言某关方块是否在树中（用于展开/收起与锁态判断）。
  Finder levelSquare(String levelId) =>
      find.byKey(ValueKey<String>('level-square-$levelId'));

  group('T-EDU-06 学习地图', () {
    testWidgets('章节卡片渲染：章号/名称/技巧标签/进度 n/m + P1 占位',
        (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());

      // 章号「第 N 章」。
      expect(find.text('第 0 章'), findsOneWidget);
      expect(find.text('第 1 章'), findsOneWidget);
      // 章节名称。
      expect(find.text('第 0 章 · 测试'), findsOneWidget);
      expect(find.text('第 1 章 · 进阶'), findsOneWidget);
      // 本章技巧标签组。
      expect(find.text('唯一余数'), findsOneWidget);
      expect(find.text('隐性唯一数'), findsOneWidget);
      expect(find.text('X 翼'), findsOneWidget);
      // 进度 n/m（S-02 文案：已通关 n/m）。
      expect(find.text('已通关 0/3'), findsOneWidget);
      expect(find.text('已通关 0/1'), findsOneWidget);
      // 总进度行 + P1 占位入口。
      expect(find.text('已完成 0/4 关'), findsOneWidget);
      expect(find.text('离线对决'), findsOneWidget);
      expect(find.text('挑战码异步竞速'), findsOneWidget);
      expect(find.text('每日一题'), findsNothing);
      expect(find.text('即将推出'), findsNothing);
      // 底部常驻「自由练习」入口。
      expect(find.text('自由练习'), findsOneWidget);
    });

    testWidgets('所有章节无需前置进度即可展开', (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());

      expect(find.byIcon(Icons.lock_outline), findsNothing);
      await tester.tap(find.text('第 1 章 · 进阶'));
      await tester.pumpAndSettle();
      expect(
        levelSquare('ch1_l01'),
        findsOneWidget,
        reason: '未完成第 0 章也能自由打开第 1 章',
      );
    });

    testWidgets('点击离线对决入口进入挑战码大厅', (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());

      await tester.ensureVisible(find.text('离线对决'));
      await tester.tap(find.text('离线对决'));
      await tester.pumpAndSettle();

      expect(find.text('async-duel-page'), findsOneWidget);
    });

    testWidgets('点击章节卡片展开关卡格栅，再次点击收起（动画）', (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());

      // 初始未展开：格栅不在树中。
      expect(levelSquare('ch0_l01'), findsNothing);

      // 点击第 0 章卡片 → 展开。
      await tester.tap(find.text('第 0 章 · 测试'));
      await tester.pumpAndSettle();
      expect(levelSquare('ch0_l01'), findsOneWidget);
      expect(levelSquare('ch0_l02'), findsOneWidget);
      expect(levelSquare('ch0_l03'), findsOneWidget);
      // 每关直接展示主技巧 + 完整类型，便于自由选择。
      expect(find.text('教学演示'), findsOneWidget);
      expect(find.text('引导实操'), findsOneWidget);
      expect(find.text('综合试炼'), findsOneWidget);
      expect(
        find.descendant(
          of: levelSquare('ch0_l01'),
          matching: find.text('唯一余数'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: levelSquare('ch0_l02'),
          matching: find.text('隐性唯一数'),
        ),
        findsOneWidget,
      );

      // 再次点击 → 收起。
      await tester.tap(find.text('第 0 章 · 测试'));
      await tester.pumpAndSettle();
      expect(levelSquare('ch0_l01'), findsNothing);
    });

    testWidgets('干净存档中章内所有关卡均显示序号且可选', (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());

      await tester.tap(find.text('第 0 章 · 测试'));
      await tester.pumpAndSettle();

      for (int order = 1; order <= 3; order++) {
        expect(
          find.descendant(
            of: levelSquare('ch0_l0$order'),
            matching: find.text('第 $order 小关'),
          ),
          findsOneWidget,
        );
      }
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });

    testWidgets('已完成关卡显示对勾与星数', (WidgetTester tester) async {
      final FakeProgressRepository repo = FakeProgressRepository(
        initial: const ProgressState(
          schemaVersion: 1,
          deviceId: 'test',
          onboardingDone: true,
          levels: <String, LevelProgress>{
            'ch0_l01': LevelProgress(
              levelId: 'ch0_l01',
              status: LevelStatus.completed,
              stars: 2,
            ),
            'ch0_l02': LevelProgress(
              levelId: 'ch0_l02',
              status: LevelStatus.completed,
              stars: 3,
            ),
            'ch0_l03': LevelProgress(
              levelId: 'ch0_l03',
              status: LevelStatus.completed,
              stars: 1,
            ),
          },
        ),
      );
      await pumpHome(tester, repo);

      // 第 0 章进度 3/3；章节本就可自由进入。
      expect(find.text('已通关 3/3'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing,
          reason: '自由选关模式不显示章节锁');

      await tester.tap(find.text('第 0 章 · 测试'));
      await tester.pumpAndSettle();

      // 已完成方块：对勾 + 星数。
      for (final String s in <String>['★2', '★3', '★1']) {
        expect(find.text(s), findsOneWidget, reason: '星数 $s');
      }
      expect(
        find.descendant(
          of: levelSquare('ch0_l01'),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('「自由练习」入口常驻并跳转难度选择页', (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());

      await tester.tap(find.text('自由练习'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/free-play');
    });

    testWidgets('AppBar 的技巧 Wiki 入口可用', (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());

      await tester.tap(find.byTooltip('技巧 Wiki'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, RoutePaths.wiki);
      expect(find.text('wiki-page'), findsOneWidget);
    });

    testWidgets('点击关卡按类型跳路由：demo/实操/trial', (WidgetTester tester) async {
      await pumpHome(tester, FakeProgressRepository());
      await tester.tap(find.text('第 0 章 · 测试'));
      await tester.pumpAndSettle();

      // 无完成记录时三关也都可分别跳对应类型路由。
      await tester.tap(levelSquare('ch0_l01'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/demo/ch0_l01');

      // 回到主页再试实操关。
      router.go(RoutePaths.home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('第 0 章 · 测试'));
      await tester.pumpAndSettle();
      await tester.tap(levelSquare('ch0_l02'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/practice/ch0_l02');

      // 试炼关同理。
      router.go(RoutePaths.home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('第 0 章 · 测试'));
      await tester.pumpAndSettle();
      await tester.tap(levelSquare('ch0_l03'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/trial/ch0_l03');
    });
  });
}
