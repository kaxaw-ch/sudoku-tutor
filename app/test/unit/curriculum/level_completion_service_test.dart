/// T-EDU-01 · 关卡完成服务单测（P0-EDU-09，星数 P2-ACH-02 预留）。
///
/// 覆盖：
/// - 星数规则纯函数（3/2/1 星阈值，默认规则注释见 level_completion_service）；
/// - `recordCompletion` 真实写入 `LevelProgress`（status/star/hintUsed/
///   errorCount/durationMs/attempts/lastPlayedAt）；
/// - 累计口径（再次完成时 hintUsed/errorCount 与历史合并）；
/// - `recordEntry` 记录进入次数不改变三态。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/curriculum/level_completion_service.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  late FakeProgressRepository repo;
  late LevelCompletionService service;

  setUp(() {
    repo = FakeProgressRepository();
    service = LevelCompletionService(
      repository: Future<ProgressRepository>.value(repo),
    );
  });

  group('星数规则（starsFor）', () {
    test('零提示零错误 → 3 星', () {
      expect(LevelCompletionService.starsFor(hintUsed: 0, errorCount: 0), 3);
    });

    test('提示 ≤ 配额一半 且 错误 ≤ 阈值 → 2 星', () {
      expect(LevelCompletionService.starsFor(hintUsed: 1, errorCount: 0), 2);
      expect(LevelCompletionService.starsFor(hintUsed: 2, errorCount: 3), 2);
    });

    test('提示超过配额一半 → 1 星', () {
      expect(LevelCompletionService.starsFor(hintUsed: 3, errorCount: 0), 1);
    });

    test('错误超过阈值 → 1 星', () {
      expect(LevelCompletionService.starsFor(hintUsed: 0, errorCount: 4), 1);
    });

    test('常量为合理默认（配额 5 一半 = 2，错误阈值 3）', () {
      expect(kDefaultHintQuota, 5);
      expect(kTwoStarMaxHints, 2);
      expect(kTwoStarMaxErrors, 3);
    });
  });

  group('recordCompletion', () {
    test('首次完成写入三态 completed + 星数 + 采集字段', () async {
      final LevelProgress progress = await service.recordCompletion(
        levelId: 'ch0_l01',
        durationMs: 60000,
        hintUsed: 0,
        errorCount: 0,
      );

      expect(progress.status, LevelStatus.completed);
      expect(progress.stars, 3);
      expect(progress.durationMs, 60000);
      expect(progress.hintUsed, 0);
      expect(progress.errorCount, 0);
      expect(progress.attempts, 1);
      expect(progress.lastPlayedAt, greaterThan(0));

      // 已真实写入存档。
      final ProgressState state = repo.current;
      expect(state.levels['ch0_l01']!.status, LevelStatus.completed);
      expect(state.levels['ch0_l01']!.stars, 3);
    });

    test('有提示有错误 → 2 星，且真实采集', () async {
      final LevelProgress progress = await service.recordCompletion(
        levelId: 'ch0_l01',
        durationMs: 90000,
        hintUsed: 1,
        errorCount: 2,
      );
      expect(progress.stars, 2);
      expect(progress.hintUsed, 1);
      expect(progress.errorCount, 2);
    });

    test('再次完成：hintUsed/errorCount 与历史累计，attempts +1', () async {
      await service.recordCompletion(
        levelId: 'ch0_l01',
        durationMs: 60000,
        hintUsed: 1,
        errorCount: 2,
      );
      final LevelProgress second = await service.recordCompletion(
        levelId: 'ch0_l01',
        durationMs: 30000,
        hintUsed: 0,
        errorCount: 0, // 本次零提示零错误 → 应按本次计 3 星（历史累计不影响星数）。
      );

      expect(second.attempts, 2);
      expect(second.hintUsed, 1, reason: '累计：历史 1 + 本次 0');
      expect(second.errorCount, 2, reason: '累计：历史 2 + 本次 0');
      expect(second.stars, 3, reason: '星数按本次（零提示零错误）计算');
    });
  });

  group('recordEntry', () {
    test('记录进入不改变三态与星数', () async {
      await service.recordEntry('ch0_l01');
      final ProgressState state = repo.current;
      final LevelProgress progress = state.levels['ch0_l01']!;
      expect(progress.attempts, 1);
      expect(progress.status, LevelStatus.unlocked, reason: '仅进入不完成');
      expect(progress.lastPlayedAt, greaterThan(0));

      await service.recordEntry('ch0_l01');
      expect(repo.current.levels['ch0_l01']!.attempts, 2);
    });
  });
}
