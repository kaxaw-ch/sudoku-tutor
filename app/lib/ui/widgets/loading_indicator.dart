/// 加载指示（T-UI-04：>300ms 出现的加载态）。
///
/// 直接监听 [engineLoadingProvider]（由 `LoadingGate` 在超过
/// [kLoadingThreshold]（300ms）时置 true、任务结束置 false），
/// 因此本组件天然满足「加载指示 >300ms 出现」的验收点。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sudoku_tutor/domain/engine/engine_providers.dart';

/// 全局加载指示（订阅引擎 loading 状态）。
class LoadingIndicator extends ConsumerWidget {
  /// 构造加载指示。
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool loading = ref.watch(engineLoadingProvider);
    if (!loading) {
      return const SizedBox.shrink();
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            '正在计算，请稍候…',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
