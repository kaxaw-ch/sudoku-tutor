/// 教学页面共用的“下一关”导航按钮。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';

/// 跳转前回调；返回 false 时留在当前关卡。
typedef BeforeNextLevel = Future<bool> Function();

/// 按课程索引顺序跳到下一关，自动处理演示/实操/试炼路由。
class NextLevelButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LevelIndex> asyncIndex =
        ref.watch(curriculumIndexProvider);
    final LevelEntry? next = switch (asyncIndex) {
      AsyncData<LevelIndex>(:final value) => nextOf(value, currentLevelId),
      _ => null,
    };
    final String tooltip = asyncIndex.isLoading
        ? '正在加载下一关'
        : next == null
            ? '已经是最后一关'
            : '下一关：${next.title}';

    return IconButton(
      key: const ValueKey<String>('next-level-button'),
      tooltip: tooltip,
      onPressed: next == null
          ? null
          : () async {
              final GoRouter router = GoRouter.of(context);
              final BeforeNextLevel? before = beforeNavigate;
              if (before != null && !await before()) {
                return;
              }
              router.goNamed(
                routeNameOf(next.kind),
                pathParameters: <String, String>{'levelId': next.id},
              );
            },
      icon: const Icon(Icons.skip_next_rounded),
    );
  }

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
