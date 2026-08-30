/// P0-EDU-10 / S-12 · 开发者模式测试（T-UI-05）。
///
/// 覆盖：
/// - 版本号**连点 7 次**解锁（阈值常量校验、第 7 次触发）；
/// - 连点时间窗口：间隔超过 3 秒计数清零；
/// - `reset()` 复位；
/// - `DeveloperTools`：全解锁 / 重置进度 / 跳关 / 关卡元信息读档。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/settings/developer_mode.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  group('DeveloperMode 连点计数', () {
    test('阈值常量为 7', () {
      expect(kDeveloperTapThreshold, 7);
      expect(kDeveloperTapWindow, const Duration(seconds: 3));
    });

    test('连点 7 次解锁：前 6 次不触发，第 7 次返回 true', () {
      final DeveloperMode mode = DeveloperMode(
        now: () => DateTime(2026, 1, 1, 0, 0, 0),
      );
      for (int i = 1; i <= 6; i++) {
        expect(mode.registerTap(), isFalse, reason: '第 $i 次不触发');
        expect(mode.isUnlocked, isFalse);
      }
      expect(mode.registerTap(), isTrue, reason: '第 7 次达到阈值');
      expect(mode.isUnlocked, isTrue);
    });

    test('间隔超过时间窗口 → 计数清零重新累计', () {
      DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
      final DeveloperMode mode = DeveloperMode(now: () => now);
      for (int i = 0; i < 4; i++) {
        mode.registerTap();
      }
      // 超过 3 秒窗口 → 下次点击视为新一轮。
      now = now.add(const Duration(seconds: 4));
      expect(mode.registerTap(), isFalse, reason: '窗口已过期，计数从 1 重新累计');
      expect(mode.isUnlocked, isFalse);
    });

    test('窗口内慢速连点不打断累计', () {
      DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
      final DeveloperMode mode = DeveloperMode(now: () => now);
      for (int i = 0; i < 6; i++) {
        mode.registerTap();
        now = now.add(const Duration(seconds: 2)); // 未超 3s 窗口。
      }
      expect(mode.registerTap(), isTrue, reason: '窗口内慢速连点第 7 次仍触发');
    });

    test('reset 复位解锁状态与计数', () {
      final DeveloperMode mode = DeveloperMode(
        now: () => DateTime(2026, 1, 1),
      );
      for (int i = 0; i < 7; i++) {
        mode.registerTap();
      }
      expect(mode.isUnlocked, isTrue);

      mode.reset();
      expect(mode.isUnlocked, isFalse);
      expect(mode.registerTap(), isFalse, reason: '复位后需重新累计');
    });
  });

  group('DeveloperTools（对存档的读改写）', () {
    late FakeProgressRepository repo;
    late DeveloperTools tools;

    setUp(() {
      repo = FakeProgressRepository();
      tools =
          DeveloperTools(repository: Future<ProgressRepository>.value(repo));
    });

    test('unlockAll：把已存在关卡全部置为已完成', () async {
      await repo.updateLevel(const LevelProgress(levelId: 'ch0_l01'));
      await repo.updateLevel(
        const LevelProgress(levelId: 'ch0_l02', status: LevelStatus.unlocked),
      );
      await tools.unlockAll();

      expect(repo.current.levels['ch0_l01']!.status, LevelStatus.completed);
      expect(repo.current.levels['ch0_l02']!.status, LevelStatus.completed);
    });

    test('unlockLevel：未登记的关卡 ID 也可预注册为已解锁', () async {
      await tools.unlockLevel('ch3_l10');
      expect(repo.current.levels['ch3_l10']!.status, LevelStatus.unlocked);
    });

    test('resetProgress：清除断点与进度（resetAll 被调用）', () async {
      await repo.updateLevel(const LevelProgress(levelId: 'ch0_l01'));
      await tools.resetProgress();
      expect(repo.resetCount, 1);
      expect(repo.current.levels, isEmpty);
    });

    test('listLevels：按 levelId 排序返回', () async {
      await repo.updateLevel(const LevelProgress(levelId: 'ch2_l01'));
      await repo.updateLevel(const LevelProgress(levelId: 'ch0_l01'));
      await repo.updateLevel(const LevelProgress(levelId: 'ch1_l01'));
      final List<LevelProgress> levels = await tools.listLevels();
      expect(
        levels.map((LevelProgress p) => p.levelId).toList(),
        <String>['ch0_l01', 'ch1_l01', 'ch2_l01'],
      );
    });
  });
}
