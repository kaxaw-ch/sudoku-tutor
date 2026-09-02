/// 教学页面共用的“下一关”导航按钮。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

/// 跳转前回调；返回 false 时留在当前关卡。
typedef BeforeNextLevel = Future<bool> Function();

/// 跨页面共享的目标关卡锁，目标内容真正加载完成前禁止再次切关。
final StateProvider<String?> _nextLevelNavigationTargetProvider =
    StateProvider<String?>((Ref ref) => null);

/// 按课程索引顺序跳到下一关，自动处理演示/实操/试炼路由。
class NextLevelButton extends ConsumerStatefulWidget {
  /// 构造下一关按钮。
  const NextLevelButton({
    required this.currentLevelId,
    this.beforeNavigate,
    super.key,
  });

  /// 当前关卡 id。
  final String currentLevelId;

  /// 可选的跳转前保存或拦截逻辑。
  final BeforeNextLevel? beforeNavigate;

  @override
  ConsumerState<NextLevelButton> createState() => _NextLevelButtonState();

  /// 取全局课程顺序中的下一关。
  static LevelEntry? nextOf(LevelIndex index, String currentLevelId) {
    final List<LevelEntry> levels = index.allLevels;
    final int current =
        levels.indexWhere((LevelEntry entry) => entry.id == currentLevelId);
    if (current < 0 || current + 1 >= levels.length) {
      return null;
    }
    return levels[current + 1];
  }

  /// 关卡类型对应的具名路由。
  static String routeNameOf(LevelKind kind) => switch (kind) {
        LevelKind.demo => RouteNames.demo,
        LevelKind.guidedPractice => RouteNames.practiceLevel,
        LevelKind.trial => RouteNames.trial,
      };
}

class _NextLevelButtonState extends ConsumerState<NextLevelButton> {
  bool _navigating = false;
  String? _scheduledGuardRelease;

  @override
  void didUpdateWidget(covariant NextLevelButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLevelId != widget.currentLevelId) {
      // 防御：即使上层未来选择复用教学页面，新关卡也必须恢复按钮状态。
      _navigating = false;
    }
  }

  Future<void> _goNext(LevelEntry next) async {
    // 第一击同步置位；后续点击即使发生在下一帧 rebuild 前也直接返回。
    final StateController<String?> navigationTarget =
        ref.read(_nextLevelNavigationTargetProvider.notifier);
    if (_navigating || navigationTarget.state != null) {
      return;
    }
    navigationTarget.state = next.id;
    setState(() => _navigating = true);

    try {
      final BeforeNextLevel? before = widget.beforeNavigate;
      if (before != null && !await before()) {
        navigationTarget.state = null;
        if (mounted) {
          setState(() => _navigating = false);
        }
        return;
      }
      if (!mounted) {
        navigationTarget.state = null;
        return;
      }
      // 声明式替换当前教学路由，不向导航栈继续堆叠页面。
      GoRouter.of(context).goNamed(
        NextLevelButton.routeNameOf(next.kind),
        pathParameters: <String, String>{'levelId': next.id},
      );
      // 目标页加载完成并以 next.id 构建按钮后，再由 build 释放全局锁。
    } on Object {
      navigationTarget.state = null;
      if (!mounted) {
        return;
      }
      setState(() => _navigating = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.text('进入下一关失败，请重试'))),
        );
    }
  }

  void _releaseGuardAfterFrame(String targetLevelId) {
    if (_scheduledGuardRelease == targetLevelId) {
      return;
    }
    _scheduledGuardRelease = targetLevelId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final StateController<String?> navigationTarget =
          ref.read(_nextLevelNavigationTargetProvider.notifier);
      if (navigationTarget.state == targetLevelId &&
          widget.currentLevelId == targetLevelId) {
        navigationTarget.state = null;
        if (_navigating) {
          setState(() => _navigating = false);
        }
      }
      _scheduledGuardRelease = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? navigationTarget =
        ref.watch(_nextLevelNavigationTargetProvider);
    if (navigationTarget == widget.currentLevelId) {
      _releaseGuardAfterFrame(navigationTarget!);
    }
    final AsyncValue<LevelIndex> asyncIndex =
        ref.watch(curriculumIndexProvider);
    final LevelEntry? next = switch (asyncIndex) {
      AsyncData<LevelIndex>(:final value) =>
        NextLevelButton.nextOf(value, widget.currentLevelId),
      _ => null,
    };
    final bool navigationBusy = _navigating || navigationTarget != null;
    final String tooltip = navigationBusy
        ? context.l10n.text('正在进入下一关')
        : asyncIndex.isLoading
            ? context.l10n.text('正在加载下一关')
            : next == null
                ? context.l10n.text('已经是最后一关')
                : context.l10n.text(
                    '下一关：{title}',
                    <String, Object?>{
                      'title': context.l10n.lessonTitle(next.id, next.title),
                    },
                  );
    final bool showProgress = navigationBusy || asyncIndex.isLoading;

    return IconButton(
      key: const ValueKey<String>('next-level-button'),
      tooltip: tooltip,
      onPressed: next == null || navigationBusy ? null : () => _goNext(next),
      icon: showProgress
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.25),
            )
          : const Icon(Icons.skip_next_rounded),
    );
  }
}
