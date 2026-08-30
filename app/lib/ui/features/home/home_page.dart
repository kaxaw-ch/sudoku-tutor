/// 学习地图主页（T-EDU-06 / S-02、P0-EDU-08）。
///
/// 结构（对齐 doc 06 §3 与 PRD S-02）：
/// - AppBar：页面标题 + 设置入口（齿轮）；
/// - 主体：章节纵向卡片列表（[ChapterCard]），点击展开该章关卡格栅
///   （[LevelGrid]，全部关卡均可自由选择，已通关关卡显示星级）；
/// - 底部常驻「自由练习」大按钮 → `/difficulty`（难度选择页）；
/// - P1 入口位预留：对战 / 每日一题 置灰占位卡（标注「即将推出」，不实现功能）。
///
/// **UI 零逻辑**：课程列表/各章进度/解锁状态/完成数全部来自
/// [curriculumStateProvider]（T-EDU-01 装配），本页不做任何解锁/进度计算，
/// 只做「数据 → 渲染」与「点击 → 按关类型跳路由」。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/chapter_model.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

import 'chapter_card.dart';

/// 学习地图主页。
class HomePage extends ConsumerWidget {
  /// 构造主页。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CurriculumState> asyncState =
        ref.watch(curriculumStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('学习地图'),
        actions: <Widget>[
          IconButton(
            tooltip: '技巧 Wiki',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.goNamed(RouteNames.wiki),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.goNamed(RouteNames.settings),
          ),
        ],
      ),
      // 底部常驻「自由练习」入口（独立于课程数据加载状态）。
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: FilledButton.icon(
            onPressed: () => context.goNamed(RouteNames.difficulty),
            icon: const Icon(Icons.grid_view_rounded),
            label: const Text('自由练习'),
          ),
        ),
      ),
      body: switch (asyncState) {
        AsyncData<CurriculumState>(:final value) =>
          _buildCurriculum(context, ref, value),
        AsyncError<CurriculumState>(:final error) =>
          _buildError(context, ref, error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// 课程数据就绪：总进度 + 章节卡片 + P1 占位。
  Widget _buildCurriculum(
    BuildContext context,
    WidgetRef ref,
    CurriculumState state,
  ) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            theme.colorScheme.primaryContainer.withValues(alpha: 0.34),
            theme.scaffoldBackgroundColor,
          ],
          stops: const <double>[0, 0.34],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ProgressHero(
              completed: state.completedLevels,
              total: state.totalLevels,
            ),
            const SizedBox(height: AppSpacing.md),
            // 章节纵向卡片列表。
            for (final ChapterModel chapter in state.chapters)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ChapterCard(
                  chapter: chapter,
                  onLevelTap: (LevelTile tile) => _openLevel(context, tile),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            // P1 入口位预留（置灰占位，不实现功能）。
            Text('更多玩法', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            const Row(
              children: <Widget>[
                Expanded(
                  child: _P1PlaceholderCard(
                    icon: Icons.sports_esports_outlined,
                    label: '对战',
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _P1PlaceholderCard(
                    icon: Icons.calendar_month_outlined,
                    label: '每日一题',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  /// 课程加载失败：错误提示 + 重试。
  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    Object error,
  ) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('课程加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(curriculumStateProvider),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  /// 点击关卡：按关类型跳对应路由（演示/实操/试炼）。
  void _openLevel(BuildContext context, LevelTile tile) {
    final String template = switch (tile.entry.kind) {
      LevelKind.demo => RoutePaths.demo,
      LevelKind.guidedPractice => RoutePaths.practiceLevel,
      LevelKind.trial => RoutePaths.trial,
    };
    context.go(RoutePaths.withLevelId(template, tile.entry.id));
  }
}

/// 首页总进度概览：用动画进度条建立清晰的首屏视觉层级。
class _ProgressHero extends StatelessWidget {
  const _ProgressHero({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = total == 0 ? 0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '继续你的数独旅程',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '已完成 $completed/$total 关',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder:
                      (BuildContext context, double value, Widget? child) =>
                          LinearProgressIndicator(
                    value: value,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(99),
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${(progress * 100).round()}%',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// P1 占位卡片：置灰 + 「即将推出」，不可点击。
class _P1PlaceholderCard extends StatelessWidget {
  const _P1PlaceholderCard({required this.icon, required this.label});

  /// 占位图标。
  final IconData icon;

  /// 入口名（如 `对战`）。
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 24, color: scheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '即将推出',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
