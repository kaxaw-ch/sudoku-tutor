/// T-UI-05 · 设置页测试（S-08，P0-STO-08 冻结清单逐项一致）。
///
/// 覆盖：
/// - 冻结清单项存在（外观/玩法/反馈/数据/关于 五个分组齐全）；
/// - 置灰项：粉色/蓝色主题、语言、隐私说明不可选（enabled=false）；
/// - 棋盘主题：经典蓝色/清新绿色可切换并写档；
/// - 开关写档：切换「音效」后存档真实变更；
/// - 提示次数下拉切换写档；
/// - 重置全部进度：取消不重置 / 确认后调用 resetAll（二次确认）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/ui/features/settings/settings_page.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  Future<FakeProgressRepository> pumpSettings(
    WidgetTester tester,
    FakeProgressRepository repo,
  ) async {
    // 设置页 ListView 项多（五组），默认 800×600 放不下 → 屏幕外分组不构建、
    // Dropdown 偏移不可点。放大窗口使全部项一屏可见（保留 scrollTo 作兜底）。
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsPage(),
        ),
      ),
    );
    // 等待设置异步加载完成（fake repo 立即返回）。
    for (int i = 0; i < 20 && find.text('外观').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('外观'), findsOneWidget, reason: '设置页加载完成');
    return repo;
  }

  /// 滚动到目标（设置页 ListView）。目标已可见则跳过——窗口已放大，
  /// 避免 `scrollUntilVisible` 在不可滚/错 Scrollable 上无效拖动甚至挂起。
  Future<void> scrollToIfNeeded(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('冻结清单项齐全（五个分组逐项断言）', (WidgetTester tester) async {
    await pumpSettings(tester, FakeProgressRepository());

    // 分组标题。
    for (final String group in <String>['外观', '玩法', '反馈', '数据', '关于']) {
      expect(find.text(group), findsWidgets, reason: '分组「$group」');
    }

    // 玩法与反馈项。
    expect(find.text('棋盘主题'), findsOneWidget);
    expect(find.text('经典蓝色'), findsOneWidget);
    expect(find.text('清新绿色'), findsOneWidget);
    expect(find.text('自动候选数'), findsOneWidget);
    expect(find.text('标记错误'), findsOneWidget);
    expect(find.text('显示计时'), findsOneWidget);
    expect(find.text('相同数字高亮'), findsOneWidget);
    expect(find.text('提示次数'), findsOneWidget);
    expect(find.text('音效'), findsOneWidget);
    expect(find.text('震动'), findsOneWidget);

    // 数据项（先滚动到底部确保构建）。
    await scrollToIfNeeded(tester, find.text('导出日志'));
    expect(find.text('导出存档'), findsOneWidget);
    expect(find.text('导入存档'), findsOneWidget);
    expect(find.text('清空错题本'), findsOneWidget);
    expect(find.text('重置全部进度'), findsOneWidget);
    expect(find.text('导出日志'), findsOneWidget);

    // 关于项（继续滚动到最底）。
    await scrollToIfNeeded(tester, find.text('隐私说明'));
    expect(find.text('数独教学'), findsOneWidget);
    expect(find.text('版本 0.1.0'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
    expect(find.text('隐私说明'), findsOneWidget);
  });

  testWidgets('置灰项：粉色/蓝色主题、语言、隐私说明不可选', (WidgetTester tester) async {
    await pumpSettings(tester, FakeProgressRepository());

    // 主题三插槽：白色可选，粉/蓝置灰。
    final ListTile pink =
        tester.widget<ListTile>(find.widgetWithText(ListTile, '粉色'));
    final ListTile blue =
        tester.widget<ListTile>(find.widgetWithText(ListTile, '蓝色'));
    final ListTile white =
        tester.widget<ListTile>(find.widgetWithText(ListTile, '白色'));
    expect(white.enabled, isTrue, reason: '白色为当前实现，可点');
    expect(pink.enabled, isFalse, reason: '粉色置灰预留');
    expect(blue.enabled, isFalse, reason: '蓝色置灰预留');

    // 语言 / 隐私说明置灰。
    await scrollToIfNeeded(tester, find.text('隐私说明'));
    final ListTile language =
        tester.widget<ListTile>(find.widgetWithText(ListTile, '语言'));
    final ListTile privacy =
        tester.widget<ListTile>(find.widgetWithText(ListTile, '隐私说明'));
    expect(language.enabled, isFalse);
    expect(privacy.enabled, isFalse);
  });

  testWidgets('切换「音效」开关 → 存档真实变更', (WidgetTester tester) async {
    final FakeProgressRepository repo =
        await pumpSettings(tester, FakeProgressRepository());
    expect(repo.current.settings.soundOn, isFalse);

    // 兜底滚动到目标再 tap（窗口已放大，正常一步到位）。
    await scrollToIfNeeded(tester, find.text('音效'));
    await tester.tap(find.text('音效'));
    await tester.pump();

    expect(repo.current.settings.soundOn, isTrue, reason: '开关写档');
  });

  testWidgets('棋盘主题可在绿色与蓝色间切换并写档', (WidgetTester tester) async {
    final FakeProgressRepository repo =
        await pumpSettings(tester, FakeProgressRepository());
    expect(repo.current.settings.boardTheme, BoardThemeStyle.green);

    await tester.tap(find.text('经典蓝色'));
    await tester.pump();
    expect(repo.current.settings.boardTheme, BoardThemeStyle.blue);
    expect(
      tester
          .widget<SegmentedButton<BoardThemeStyle>>(
            find.byKey(const ValueKey<String>('board-theme-selector')),
          )
          .selected,
      <BoardThemeStyle>{BoardThemeStyle.blue},
    );

    await tester.tap(find.text('清新绿色'));
    await tester.pump();
    expect(repo.current.settings.boardTheme, BoardThemeStyle.green);
  });

  testWidgets('提示次数下拉：切换为「3 次」写档', (WidgetTester tester) async {
    final FakeProgressRepository repo =
        await pumpSettings(tester, FakeProgressRepository());
    expect(repo.current.settings.hintQuota, HintQuota.unlimited);

    // 兜底滚动到下拉框（窗口已放大，正常一步到位）。
    await scrollToIfNeeded(tester, find.byType(DropdownButton<HintQuota>));
    await tester.tap(find.byType(DropdownButton<HintQuota>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // 菜单弹出后选项「3 次」出现（.last 取菜单项而非按钮当前值）。
    expect(find.text('3 次'), findsWidgets, reason: '下拉菜单包含「3 次」');
    await tester.tap(find.text('3 次').last);
    await tester.pump(const Duration(milliseconds: 300));

    expect(repo.current.settings.hintQuota, HintQuota.three);
  });

  testWidgets('重置全部进度：取消不重置，确认后调用 resetAll', (WidgetTester tester) async {
    final FakeProgressRepository repo =
        await pumpSettings(tester, FakeProgressRepository());

    // 第一次：取消。
    await scrollToIfNeeded(tester, find.text('重置全部进度'));
    await tester.tap(find.text('重置全部进度'));
    await tester.pump(); // dialog 弹出动画首帧。
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('重置全部进度？'), findsOneWidget, reason: '二次确认弹窗');
    // 按钮用 widgetWithText 精确定位（避免与页面其它文本误匹配）。
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // dialog 关闭动画完成。
    expect(find.text('重置全部进度？'), findsNothing, reason: '弹窗已完全关闭');
    expect(repo.resetCount, 0, reason: '取消不触发重置');

    // 第二次：确认（重置后 _toast 弹 SnackBar，末尾 pump 消化其自动关闭 timer）。
    await scrollToIfNeeded(tester, find.text('重置全部进度'));
    await tester.tap(find.text('重置全部进度'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('重置全部进度？'), findsOneWidget, reason: '二次确认弹窗再次出现');
    await tester.tap(find.widgetWithText(FilledButton, '重置'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.resetCount, 1, reason: '确认后调用 resetAll');
    // 消化 SnackBar（默认 4s 自动关闭）的 pending timer + 关闭动画。
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
  });
}
