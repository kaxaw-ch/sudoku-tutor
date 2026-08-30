/// 首次启动引导页（T-UI-08 / P0-UI-08、S-01）。
///
/// - 3 页横滑（PageView）：① 产品定位 ② 教学体系 ③ 自由练习；
///   每页 = 图标插画占位（Icon 组合，不引入图片素材）+ 标题 + 副文案；
/// - 底部页码点（当前页高亮加宽）；
/// - 右上角常驻「跳过」；末页显示「开始学习」按钮（前两页为「下一步」）；
/// - **跳过 / 开始学习**共用 [_finish]：`onboardingDone` 置 true 落盘后
///   直达第 0 章第 1 关（按 `index.json` 中 ch0 首关的 `kind` 跳对应类型路由，
///   当前 ch0_l01 为 demo → `/demo/ch0_l01`；若索引变更首关类型，
///   以下路由映射自动跟随，无需改代码）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 首启引导页。
class OnboardingPage extends ConsumerStatefulWidget {
  /// 构造引导页。
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  /// 引导页总数。
  static const int _pageCount = 3;

  final PageController _controller = PageController();

  /// 当前页码（0 起）。
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) => setState(() => _current = index);

  /// 下一页（非末页时）。
  void _next() {
    if (_current < _pageCount - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  /// 完成引导（跳过 / 末页「开始学习」共用）。
  ///
  /// 1. `onboardingDone` 置 true 落盘（P0-UI-08：完成后不再出现）；
  /// 2. 直达第 0 章第 1 关：路由按索引实际 `kind` 决定
  ///    （demo→`/demo/:id`、guidedPractice→`/practice/:id`、trial→`/trial/:id`）。
  Future<void> _finish() async {
    final ProgressRepository repo =
        await ref.read(progressRepositoryProvider.future);
    final ProgressState state = await repo.load();
    await repo.save(state.copyWith(onboardingDone: true));
    if (!mounted) {
      return;
    }
    final String route = await _firstLevelRoute();
    if (!mounted) {
      return;
    }
    context.go(route);
  }

  /// 计算「第 0 章第 1 关」的路由；索引未登记时回退主页（防御）。
  Future<String> _firstLevelRoute() async {
    final LevelIndex index = await ref.read(curriculumIndexProvider.future);
    final List<ChapterEntry> chapters =
        index.chapters.where((ChapterEntry c) => c.chapter == 0).toList();
    if (chapters.isEmpty) {
      return RoutePaths.home;
    }
    final ChapterEntry ch0 = chapters.first.sorted();
    if (ch0.levels.isEmpty) {
      return RoutePaths.home;
    }
    final LevelEntry first = ch0.levels.first;
    final String template = switch (first.kind) {
      LevelKind.demo => RoutePaths.demo,
      LevelKind.guidedPractice => RoutePaths.practiceLevel,
      LevelKind.trial => RoutePaths.trial,
    };
    return RoutePaths.withLevelId(template, first.id);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLast = _current == _pageCount - 1;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: _onPageChanged,
                    children: const <Widget>[
                      _GuidePage(
                        icon: Icons.grid_4x4_rounded,
                        title: '零门槛入门数独',
                        subtitle: '从行、列、宫规则到候选数，'
                            '跟着分步动画一点点看懂数独，不需要任何基础。',
                      ),
                      _GuidePage(
                        icon: Icons.school_outlined,
                        title: '四章渐进学习',
                        subtitle: '基础 → 进阶技巧 → 实战，四章 34 关循序渐进，'
                            '演示 / 实操 / 试炼三种关卡层层递进。',
                      ),
                      _GuidePage(
                        icon: Icons.extension_outlined,
                        title: '海量题库 · 即时反馈',
                        subtitle: '五大难度题库离线内置，随时自由练习，'
                            '即时核对答案与分步提示陪你稳步进步。',
                      ),
                    ],
                  ),
                ),
                // 页码点。
                _buildDots(theme),
                const SizedBox(height: AppSpacing.md),
                // 主按钮：末页「开始学习」，其余「下一步」。
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLast ? _finish : _next,
                      child: Text(isLast ? '开始学习' : '下一步'),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
            // 右上角常驻「跳过」。
            Positioned(
              top: AppSpacing.xs,
              right: AppSpacing.xs,
              child: TextButton(
                onPressed: _finish,
                child: const Text('跳过'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 页码点：当前页加宽高亮，其余为小圆点。
  Widget _buildDots(ThemeData theme) {
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < _pageCount; i++)
          AnimatedContainer(
            key: ValueKey<String>('onboarding-dot-$i'),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            width: _current == i ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _current == i ? scheme.primary : scheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// 单页引导内容（图标占位 + 标题 + 副文案）。
class _GuidePage extends StatelessWidget {
  const _GuidePage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  /// 插画占位图标。
  final IconData icon;

  /// 页标题。
  final String title;

  /// 页副文案。
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // 图标插画占位（Icon 组合，不引入图片素材）。
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 56, color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
