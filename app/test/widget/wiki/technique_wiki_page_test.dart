/// 技巧 Wiki 页面与内容完整性测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/technique_wiki.dart';
import 'package:sudoku_tutor/ui/features/wiki/technique_wiki_page.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

void main() {
  test('百科完整覆盖引擎全部技巧且无重复', () {
    final Set<TechniqueId> ids = techniqueWikiEntries
        .map((TechniqueWikiEntry entry) => entry.id)
        .toSet();
    expect(ids, TechniqueId.values.toSet());
    expect(techniqueWikiEntries, hasLength(TechniqueId.values.length));
    for (final TechniqueWikiEntry entry in techniqueWikiEntries) {
      expect(entry.definition, isNotEmpty);
      expect(entry.usage, isNotEmpty);
      expect(entry.tip, isNotEmpty);
    }
  });

  testWidgets('可搜索技巧并展开定义、用法和注意事项', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const TechniqueWikiPage(),
      ),
    );

    expect(find.text('技巧 Wiki'), findsOneWidget);
    expect(find.textContaining('16 种技巧'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), '唯一矩形 型二');
    await tester.pump();
    expect(find.text('找到 1 项'), findsOneWidget);
    final Finder wikiEntry = find.byKey(
      const ValueKey<String>('wiki-urType2'),
    );
    expect(
      find.descendant(of: wikiEntry, matching: find.text('唯一矩形 型二')),
      findsOneWidget,
    );

    await tester.tap(wikiEntry);
    await tester.pumpAndSettle();
    expect(find.text('定义'), findsOneWidget);
    expect(find.text('怎么使用'), findsOneWidget);
    expect(find.text('注意'), findsOneWidget);
    expect(find.textContaining('共同候选 AB'), findsOneWidget);
  });

  testWidgets('顶部返回按钮回到学习地图', (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/wiki',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const Scaffold(body: Text('learning-map')),
        ),
        GoRoute(
          path: '/wiki',
          name: 'wiki',
          builder: (_, __) => const TechniqueWikiPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
      ),
    );

    await tester.tap(find.byTooltip('返回学习地图'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.text('learning-map'), findsOneWidget);
  });
}
