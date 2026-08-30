/// T-UI-08 · 启动初始路由决策单元测试。
///
/// 验证 [resolveInitialLocation]（bootstrap 启动时读档决定初始路由）：
/// - `onboardingDone == false`（首启）→ `/onboarding`；
/// - `onboardingDone == true` → `/home`（学习地图）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/app/bootstrap.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';

void main() {
  ProgressState state({required bool onboardingDone}) => ProgressState(
        schemaVersion: 1,
        deviceId: 'test',
        onboardingDone: onboardingDone,
      );

  test('首启未完成 → 初始路由为 /onboarding', () {
    expect(
      resolveInitialLocation(state(onboardingDone: false)),
      RoutePaths.onboarding,
    );
  });

  test('引导已完成 → 初始路由为 /home（学习地图），引导不再出现', () {
    expect(
      resolveInitialLocation(state(onboardingDone: true)),
      RoutePaths.home,
    );
  });
}
