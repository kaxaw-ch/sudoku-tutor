/// 难度选择/新局页（S-07，P0-PRA-01/09/10，T-UI-04）。
///
/// 结构：
/// - 若存在断点存档，顶部显示 `ResumeBanner`（继续上次 / 开始新局（将覆盖））；
/// - 五档难度卡片（入门/简单/中等/困难/大师），每张附一行
///   「最高需用到 XX 技巧」说明（读该档题库**代表题**的 `hardestTechnique`
///   技巧中文名，取自题库 techniques 标注）；
/// - 底部「从文本导入题目」入口（`ImportDialog`）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_bank_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/theme/color_tokens.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

import 'free_play_page.dart';
import 'import_dialog.dart';
import 'resume_banner.dart';

/// 难度选择页。
class DifficultyPage extends ConsumerWidget {
  /// 构造页面。
  const DifficultyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    // 断点存在性（异步加载，先给 false 骨架）。
    final bool hasSession = ref.watch(hasSessionProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.text('选择难度')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed('home'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              if (hasSession) ...<Widget>[
                ResumeBanner(
                  onResume: () => context.goNamed(
                    'freePlay',
                    extra: const FreePlayLaunchResume(),
                  ),
                  onStartNew: () => _confirmAndGo(context, Difficulty.medium),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              for (final Difficulty difficulty
                  in Difficulty.values) ...<Widget>[
                _DifficultyCard(
                  difficulty: difficulty,
                  description: _DescriptionText(difficulty: difficulty),
                  onTap: () {
                    if (hasSession) {
                      _confirmAndGo(context, difficulty);
                    } else {
                      _goNewGame(context, difficulty);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                onPressed: () async {
                  final Puzzle? puzzle = await ImportDialog.show(context);
                  if (puzzle == null || !context.mounted) {
                    return;
                  }
                  // 导入题直接进入对局（难度取题面标注）。
                  context.goNamed(
                    'freePlay',
                    extra: FreePlayLaunchImported(puzzle),
                  );
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(context.l10n.text('从文本导入题目')),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                context.l10n.text(
                  '困难 / 大师档仅使用预置题库；入门 / 简单 / 中等档可运行时生成补充。',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 有断点时开始新局 → 二次确认覆盖（P0-PRA-09），确认后进入 [difficulty]。
  void _confirmAndGo(BuildContext context, Difficulty difficulty) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(context.l10n.text('开始新局？')),
        content: Text(
          context.l10n.text('开始新局将覆盖上次未完成的对局，且不可恢复。'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.text('取消')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _goNewGame(context, difficulty);
            },
            child: Text(context.l10n.text('继续')),
          ),
        ],
      ),
    );
  }

  void _goNewGame(BuildContext context, Difficulty difficulty) {
    context.goNamed(
      'freePlay',
      extra: FreePlayLaunchNewGame(difficulty),
    );
  }
}

/// 单张难度卡片。
class _DifficultyCard extends StatelessWidget {
  const _DifficultyCard({
    required this.difficulty,
    required this.description,
    required this.onTap,
  });

  final Difficulty difficulty;
  final Widget description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          _iconOf(difficulty),
          color: AppColorTokens.white.seedColor,
        ),
        title: Text(context.l10n.difficultyName(difficulty)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: description,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  static IconData _iconOf(Difficulty difficulty) => switch (difficulty) {
        Difficulty.beginner => Icons.sentiment_very_satisfied_outlined,
        Difficulty.easy => Icons.sentiment_satisfied_alt_outlined,
        Difficulty.medium => Icons.timelapse_outlined,
        Difficulty.hard => Icons.local_fire_department_outlined,
        Difficulty.master => Icons.workspace_premium_outlined,
      };
}

/// 「最高需用到 XX 技巧」说明（读题库代表题）。
class _DescriptionText extends ConsumerWidget {
  const _DescriptionText({required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DifficultyMeta> meta =
        ref.watch(difficultyMetaProvider(difficulty));
    return meta.when(
      data: (DifficultyMeta m) => Text(
        context.l10n.text(
          '最高需用到：{technique}',
          <String, Object?>{
            'technique': m.hardestTechnique == null
                ? '—'
                : context.l10n.techniqueName(m.hardestTechnique!),
          },
        ),
      ),
      loading: () => Text(context.l10n.text('最高需用到：加载中…')),
      error: (Object e, StackTrace st) =>
          Text(context.l10n.text('最高需用到：—')),
    );
  }
}

/// 一档题库的代表元信息。
class DifficultyMeta {
  /// 构造元信息。
  const DifficultyMeta({required this.hardestTechnique});

  /// 代表题的最高技巧中文名。
  final TechniqueId? hardestTechnique;

  /// Backwards-compatible Chinese label used by older callers/tests.
  String get hardestTechniqueZh => hardestTechnique?.zhName ?? '—';
}

/// 读取一档题库代表题（第一题）的最高技巧中文名。
///
/// 题库 `puzzles[i].techniques` 为解题用到的全部技巧集合，取其 rank
/// 最高（枚举序最大）的一项作为「最高需用到」。
final AutoDisposeFutureProviderFamily<DifficultyMeta, Difficulty>
    difficultyMetaProvider =
    FutureProvider.autoDispose.family<DifficultyMeta, Difficulty>(
  (Ref ref, Difficulty difficulty) async {
    final PuzzleBankRepository repo = ref.watch(puzzleBankRepositoryProvider);
    final DifficultyBank bank = await repo.loadBank(difficulty);
    if (bank.puzzles.isEmpty) {
      return const DifficultyMeta(hardestTechnique: null);
    }
    final Puzzle representative = bank.puzzles.first;
    TechniqueId? hardest;
    for (final TechniqueId id in representative.techniques) {
      if (hardest == null || id.index > hardest.index) {
        hardest = id;
      }
    }
    return DifficultyMeta(hardestTechnique: hardest);
  },
);
