/// 开发者模式页（S-12，P0-EDU-10，T-UI-05）。
///
/// 功能：全解锁 / 重置进度 / 跳关（解锁指定关）/ 查看关卡元信息
/// （用已存的 `LevelProgress` 数据展示）。隐藏入口，不对外宣传。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/domain/settings/developer_mode.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 开发者模式页。
class DeveloperPage extends ConsumerStatefulWidget {
  /// 构造页面。
  const DeveloperPage({super.key});

  @override
  ConsumerState<DeveloperPage> createState() => _DeveloperPageState();
}

class _DeveloperPageState extends ConsumerState<DeveloperPage> {
  final TextEditingController _levelId = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _levelId.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _unlockAll() async {
    await _run(() async {
      final DeveloperTools tools = ref.read(developerToolsProvider);
      await tools.unlockAll();
      _toast('已全解锁全部已有关卡');
    });
  }

  Future<void> _resetProgress() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('重置全部进度？'),
        content: const Text('将删除全部进度与设置，此操作不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('重置'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await _run(() async {
      final DeveloperTools tools = ref.read(developerToolsProvider);
      await tools.resetProgress();
      _toast('已重置全部进度');
    });
  }

  Future<void> _unlockLevel() async {
    final String levelId = _levelId.text.trim();
    if (levelId.isEmpty) {
      _toast('请输入关卡 ID');
      return;
    }
    await _run(() async {
      final DeveloperTools tools = ref.read(developerToolsProvider);
      await tools.unlockLevel(levelId);
      _toast('已解锁关卡 $levelId');
    });
  }

  void _toast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('开发者模式')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('开发者工具', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        onPressed: _busy ? null : _unlockAll,
                        icon: const Icon(Icons.lock_open),
                        label: const Text('全解锁'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _resetProgress,
                        icon: const Icon(Icons.delete_forever),
                        label: const Text('重置进度'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text('跳关（解锁指定关卡 ID）', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _levelId,
                              enabled: !_busy,
                              decoration: const InputDecoration(
                                hintText: '如 ch0_l01',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          FilledButton.tonal(
                            onPressed: _busy ? null : _unlockLevel,
                            child: const Text('解锁'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('关卡元信息（读取已存进度）', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              _LevelList(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 关卡元信息列表（异步读取已存档 `LevelProgress`）。
class _LevelList extends ConsumerWidget {
  const _LevelList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<LevelProgress>> levels =
        ref.watch(developerLevelsProvider);
    return levels.when(
      loading: () => const Center(
          child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: CircularProgressIndicator(),
      )),
      error: (Object e, StackTrace st) => Text('加载失败：$e'),
      data: (List<LevelProgress> list) {
        if (list.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '暂无已存关卡进度（完成教学关或跳关后出现）',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          );
        }
        return Card(
          child: Column(
            children: <Widget>[
              for (final LevelProgress p in list) ...<Widget>[
                if (p != list.first) const Divider(height: 1),
                ListTile(
                  dense: true,
                  leading: _StatusIcon(status: p.status),
                  title: Text(p.levelId),
                  subtitle: Text(
                    '状态：${p.status.zhName} · 用时 ${_ms(p.durationMs)} · '
                    '提示 ${p.hintUsed} · 错误 ${p.errorCount} · '
                    '尝试 ${p.attempts} 次',
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _ms(int ms) {
    final int seconds = ms ~/ 1000;
    return '${seconds ~/ 60}分${seconds % 60}秒';
  }
}

/// 关卡状态图标。
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final LevelStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Icon(
      switch (status) {
        LevelStatus.locked => Icons.lock_outline,
        LevelStatus.unlocked => Icons.play_circle_outline,
        LevelStatus.completed => Icons.check_circle,
      },
      color: switch (status) {
        LevelStatus.locked => theme.colorScheme.outline,
        LevelStatus.unlocked => theme.colorScheme.primary,
        LevelStatus.completed => Colors.green,
      },
    );
  }
}

/// 已存档关卡元信息 Provider（开发者页消费）。
final FutureProvider<List<LevelProgress>> developerLevelsProvider =
    FutureProvider<List<LevelProgress>>(
  (Ref ref) => ref.read(developerToolsProvider).listLevels(),
);
