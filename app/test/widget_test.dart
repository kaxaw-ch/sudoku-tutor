/// 应用级冒烟测试（替代脚手架默认的 counter 测试）。
///
/// 验证 `SudokuTutorApp` 可正常挂载并渲染**学习地图主页**（T-EDU-06），
/// 且 MaterialApp 的 builder 链（字号钳制 + 响应式外壳）不破坏渲染；
/// 设置入口可点击进入设置页（S-08）。
///
/// ⚠️ 批次 E 收口：设置页的 `settingsStateProvider` 会异步加载存档
/// （`progressRepositoryProvider`），主页 `curriculumStateProvider` 会加载课程
/// 索引。测试环境没有 path_provider 插件通道，故注入内存假仓储与假课程
/// loader；用 `pump` 推进固定时长，保持「可启动 + 首页渲染 + 设置入口可点」
/// 语义，不使用 `pumpAndSettle`（避免 loading 动画导致的超时）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/app/app.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';

import 'helpers/fake_progress_repository.dart';
import 'helpers/teaching_helpers.dart';

void main() {
  testWidgets('应用可启动并渲染学习地图主页', (WidgetTester tester) async {
    // 注入内存假仓储与假课程 loader，避免 path_provider / rootBundle 依赖。
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith(
            (Ref ref) async => FakeProgressRepository(),
          ),
          curriculumRepositoryProvider.overrideWithValue(
            CurriculumRepository(
              loader: buildTeachingCurriculumLoader(
                levelJsonById: buildDefaultTeachingLevels(),
              ),
            ),
          ),
        ],
        child: const SudokuTutorApp(),
      ),
    );
    // 推进课程状态异步加载。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // 学习地图主页出现（章节卡片 + 自由练习入口）。
    expect(find.text('学习地图'), findsOneWidget);
    expect(find.text('第 0 章 · 测试'), findsOneWidget);
    expect(find.text('自由练习'), findsOneWidget);

    // 设置入口可点击进入设置页（路由过渡用 pump 推进，不依赖 settle）。
    await tester.tap(find.byTooltip('设置'));
    await tester.pump(); // 路由入栈。
    await tester.pump(const Duration(seconds: 1)); // 过渡动画 + 存档加载。
    expect(find.text('设置'), findsWidgets);
    // 设置页数据落地：外观分组标题可见（说明加载完成而非 loading 卡死）。
    expect(find.text('外观'), findsOneWidget);
  });
}
