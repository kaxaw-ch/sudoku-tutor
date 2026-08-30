/// 数独技巧 Wiki 页面。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/curriculum/technique_wiki.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 展示全部已实现技巧的定义、使用方法与边界条件。
class TechniqueWikiPage extends StatefulWidget {
  /// 构造技巧 Wiki。
  const TechniqueWikiPage({super.key});

  @override
  State<TechniqueWikiPage> createState() => _TechniqueWikiPageState();
}

class _TechniqueWikiPageState extends State<TechniqueWikiPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String query = _query.trim().toLowerCase();
    final List<TechniqueWikiEntry> entries = techniqueWikiEntries
        .where(
          (TechniqueWikiEntry entry) =>
              query.isEmpty ||
              entry.id.zhName.toLowerCase().contains(query) ||
              entry.id.enName.toLowerCase().contains(query) ||
              entry.definition.toLowerCase().contains(query),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回学习地图',
          onPressed: () => context.goNamed(RouteNames.home),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('技巧 Wiki'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.menu_book_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '从定义到落子依据',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '收录引擎支持的 ${techniqueWikiEntries.length} 种技巧。点击条目查看识别方法、用法和易错点。',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SearchBar(
                      controller: _searchController,
                      hintText: '搜索中文名、英文名或定义',
                      leading: const Icon(Icons.search),
                      trailing: <Widget>[
                        if (_query.isNotEmpty)
                          IconButton(
                            tooltip: '清除搜索',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                      ],
                      onChanged: (String value) =>
                          setState(() => _query = value),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      query.isEmpty ? '全部技巧' : '找到 ${entries.length} 项',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('没有找到相关技巧')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xl,
                ),
                sliver: SliverList.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) =>
                      _TechniqueCard(
                    entry: entries[index],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  const _TechniqueCard({required this.entry});

  final TechniqueWikiEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: ValueKey<String>('wiki-${entry.id.id}'),
        leading: CircleAvatar(
          child: Text('${entry.rank}'),
        ),
        title: Text(
          entry.id.zhName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text('${entry.id.enName} · ${entry.difficulty.zhName}'),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _WikiSection(title: '定义', text: entry.definition),
          const SizedBox(height: AppSpacing.sm),
          _WikiSection(title: '怎么使用', text: entry.usage),
          const SizedBox(height: AppSpacing.sm),
          _WikiSection(title: '注意', text: entry.tip, emphasized: true),
        ],
      ),
    );
  }
}

class _WikiSection extends StatelessWidget {
  const _WikiSection({
    required this.title,
    required this.text,
    this.emphasized = false,
  });

  final String title;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
