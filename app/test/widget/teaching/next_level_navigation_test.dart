/// 教学“下一关”导航回归测试。
///
/// 覆盖：
/// - 同类型演示关连续跳转时，路由参数变化会重建页面并加载新关卡；
/// - 保存/清理尚未结束时快速连点，导航前回调只执行一次。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/app/router.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/teaching/teaching_providers.dart';
import 'package:sudoku_tutor/ui/features/demo/demo_page.dart';
import 'package:sudoku_tutor/ui/features/teaching/next_level_button.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';
import '../../helpers/teaching_helpers.dart';

void main() {
  testWidgets('生产路由：连续演示关每次点击都加载新的 levelId', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith(
          (Ref ref) async => FakeProgressRepository(),
        ),
      ],
    );
    final GoRouter router = buildRouter(initialLocation: '/demo/ch0_l01');
    addTearDown(container.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );

    await _waitForDemoLevel(tester, container, 'ch0_l01');
    await _waitForEnabledButton(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('next-level-button')).hitTestable(),
    );
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/demo/ch0_l02');
    await _waitForDemoLevel(tester, container, 'ch0_l02');
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is DemoPage && widget.levelId == 'ch0_l02',
      ),
      findsOneWidget,
    );

    expect(router.routeInformationProvider.value.uri.path, '/demo/ch0_l02');
    expect(tester.takeException(), isNull);

    await _waitForEnabledButton(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('next-level-button')).hitTestable(),
    );
    await _waitForDemoLevel(tester, container, 'ch0_l03');

    expect(router.routeInformationProvider.value.uri.path, '/demo/ch0_l03');
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速连点：导航前保存回调只执行一次', (WidgetTester tester) async {
    final Completer<bool> navigationGate = Completer<bool>();
    int beforeNavigateCalls = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        curriculumRepositoryProvider.overrideWithValue(
          CurriculumRepository(
            loader: buildTeachingCurriculumLoader(
              levelJsonById: buildDefaultTeachingLevels(),
            ),
          ),
        ),
      ],
    );
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            appBar: AppBar(
              actions: <Widget>[
                NextLevelButton(
                  currentLevelId: 'ch0_l01',
                  beforeNavigate: () {
                    beforeNavigateCalls++;
                    return navigationGate.future;
                  },
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.practiceLevel,
          name: RouteNames.practiceLevel,
          builder: (_, __) => const Scaffold(body: Text('next-page')),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await _waitForEnabledButton(tester);

    final Finder button =
        find.byKey(const ValueKey<String>('next-level-button')).hitTestable();
    for (int i = 0; i < 8; i++) {
      await tester.tap(button);
    }
    await tester.pump();

    expect(beforeNavigateCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    navigationGate.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('next-page'), findsOneWidget);
    expect(beforeNavigateCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _waitForDemoLevel(
  WidgetTester tester,
  ProviderContainer container,
  String levelId,
) async {
  for (int i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (container.read(demoControllerProvider)?.level.id == levelId) {
      return;
    }
  }
  fail(
    '等待演示关 $levelId 加载超时；当前控制器关卡：'
    '${container.read(demoControllerProvider)?.level.id ?? 'null'}；'
    '页面关卡：${tester.widgetList<DemoPage>(find.byType(DemoPage)).map((DemoPage page) => page.levelId).toList()}',
  );
}

Future<void> _waitForEnabledButton(WidgetTester tester) async {
  final Finder finder =
      find.byKey(const ValueKey<String>('next-level-button')).hitTestable();
  for (int i = 0; i < 80; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (tester
        .widgetList<IconButton>(finder)
        .any((IconButton button) => button.onPressed != null)) {
      return;
    }
  }
  fail('等待下一关按钮可用超时');
}
