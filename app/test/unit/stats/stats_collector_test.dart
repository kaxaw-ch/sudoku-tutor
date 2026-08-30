/// T-DOM-06 · 统计采集器测试（P0-STO-03「P0 只采集不展示」）。
///
/// 覆盖：
/// - 开局 → 同局追踪：提示/错误/用时**真实累计**进 [PracticeStats]；
/// - 完成事件 → 一条 `completed=true` 记录，聚合字段与完成率正确；
/// - 放弃 / 新局覆盖 → 一条 `completed=false` 记录；
/// - `_flushed` 防重（每局最多一条）；
/// - 写入失败静默（不抛异常，不影响对局）；
/// - `statsCollectorProvider` 装配：对局完成自动落档（Provider 链路）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/game_session_controller.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/stats/stats_collector.dart';
import 'package:sudoku_tutor/domain/storage/models/practice_stats.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';

import '../../helpers/fake_progress_repository.dart';

/// 等待 fire-and-forget 的 `_flush` 异步落档（内部多次 await + Stream 事件派发）。
/// `onSessionChanged`/`onEvent` 为 void，不 await `_flush`，测试须主动让出事件循环。
Future<void> settleFlush() async {
  for (int i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('StatsCollector 单测', () {
    late FakeProgressRepository repo;
    late StatsCollector collector;

    setUp(() {
      repo = FakeProgressRepository();
      collector =
          StatsCollector(repository: Future<ProgressRepository>.value(repo));
    });

    test('开局即激活，尚未结算不写记录', () async {
      final GameSession s1 = buildTestGameSession(elapsedMs: 500);
      collector.onSessionChanged(null, s1);
      expect(collector.isActive, isTrue);
      expect(repo.current.stats.totalGames, 0, reason: '未终结不写记录');
    });

    test('同局状态追踪：提示/错误/用时累计进聚合', () async {
      // 同一指纹（同一 puzzle）的新状态 = 同局追踪，不重复开局。
      final GameSession s1 = buildTestGameSession(elapsedMs: 500);
      final GameSession s2 = buildTestGameSession(
        elapsedMs: 1500,
        wrongCount: 2,
        usedHints: 3,
      );
      collector.onSessionChanged(null, s1);
      collector.onSessionChanged(s1, s2);

      await collector.flushNow(completed: false);
      final PracticeStats stats = repo.current.stats;
      expect(stats.totalGames, 1);
      expect(stats.completedGames, 0);
      expect(stats.totalDurationMs, 1500, reason: '取最新一次状态');
      expect(stats.totalErrors, 2);
      expect(stats.totalHints, 3);
      expect(stats.completionRate, 0);
    });

    test('完成事件 → 写入 completed=true 记录，完成率正确', () async {
      final GameSession s1 = buildTestGameSession(
        elapsedMs: 8000,
        wrongCount: 1,
        usedHints: 2,
      );
      collector.onSessionChanged(null, s1);
      collector.onEvent(const GameCompletedEvent());
      // onEvent 是 fire-and-forget（_flush 异步）：等待微任务完成写档。
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final PracticeStats stats = repo.current.stats;
      expect(stats.records, hasLength(1));
      final PracticeRecord record = stats.records.single;
      expect(record.completed, isTrue);
      expect(record.difficultyId, Difficulty.medium.id);
      expect(record.durationMs, 8000);
      expect(record.hintCount, 2);
      expect(record.errorCount, 1);
      expect(stats.totalGames, 1);
      expect(stats.completedGames, 1);
      expect(stats.completionRate, 1.0);
      expect(collector.isActive, isFalse, reason: '结算后清空本局跟踪');
    });

    test('放弃（会话结束）→ 写入 completed=false 记录', () async {
      final GameSession s1 = buildTestGameSession(elapsedMs: 300);
      collector.onSessionChanged(null, s1);
      collector.onSessionChanged(s1, null);
      await settleFlush(); // onSessionChanged 触发的 _flush 是 fire-and-forget。

      final PracticeStats stats = repo.current.stats;
      expect(stats.records.single.completed, isFalse);
      expect(stats.totalGames, 1);
      expect(stats.completedGames, 0);
    });

    test('新局覆盖旧局 → 旧局写一条未完成，新局重新开局', () async {
      final GameSession s1 = buildTestGameSession(elapsedMs: 300);
      // 另一道题（改一个给定数字）→ 指纹不同。
      final Puzzle p2 = Puzzle(
        given: <int>[
          for (int i = 0; i < 81; i++) i == 0 ? 5 : 0,
        ],
        solution: buildTestPuzzle().solution,
      );
      final GameSession s2 = GameSession(
        puzzle: p2,
        board: p2.toGivenBoard(),
        difficulty: Difficulty.easy,
        noteMasks: const <int>[],
        noteMode: false,
        autoCandidates: true,
        selectedIndex: null,
        errorCells: const <int>{},
        elapsedMs: 100,
        paused: false,
        completed: false,
        wrongCount: 0,
        correctCount: 0,
        usedHints: 0,
        markErrors: true,
        highlightSameDigit: true,
      );

      collector.onSessionChanged(null, s1);
      collector.onSessionChanged(s1, s2);
      await settleFlush(); // 旧局被覆盖触发的 _flush 异步落档。

      final PracticeStats stats = repo.current.stats;
      expect(stats.records, hasLength(1), reason: '旧局被覆盖写一条');
      expect(stats.records.single.completed, isFalse);
      expect(collector.isActive, isTrue, reason: '新局正在采集中');
    });

    test('_flushed 防重：一局最多一条记录', () async {
      final GameSession s1 = buildTestGameSession(elapsedMs: 500);
      collector.onSessionChanged(null, s1);
      await collector.flushNow(completed: false);
      await collector.flushNow(completed: true); // 重复结算应被忽略。

      final PracticeStats stats = repo.current.stats;
      expect(stats.records, hasLength(1));
      expect(stats.records.single.completed, isFalse, reason: '第二条被防重拦截');
    });

    test('写入失败静默吞掉，不抛异常', () async {
      repo.failOnLoad = true;
      final GameSession s1 = buildTestGameSession(elapsedMs: 500);
      collector.onSessionChanged(null, s1);
      // 不抛即为通过（铁律：统计采集失败不影响对局）。
      await collector.flushNow(completed: true);
      expect(repo.current.stats.totalGames, 0);
    });
  });

  group('statsCollectorProvider 装配（Provider 链路）', () {
    test('完成一局自动落档', () async {
      final FakeProgressRepository repo = FakeProgressRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
      );
      addTearDown(container.dispose);

      container.read(statsCollectorProvider); // 触发装配与监听。

      final GameSessionController controller =
          container.read(gameSessionControllerProvider.notifier);
      final Puzzle puzzle = buildTestPuzzle();
      await controller.startNew(
        difficulty: Difficulty.medium,
        puzzle: puzzle,
        settings: const SettingsState(
          autoCandidates: true,
          markErrors: true,
        ),
      );
      // 依次填入所有空格的正解 → 完成事件 → 自动结算。
      final GameSession s = container.read(gameSessionControllerProvider)!;
      for (int i = 0; i < 81; i++) {
        if (s.board.isBlank(i)) {
          controller.selectCell(i);
          controller.inputDigit(puzzle.solution[i]);
        }
      }
      expect(container.read(gameSessionControllerProvider)!.completed, isTrue);
      // 完成事件经 Stream 派发 → onEvent → _flush：让出事件循环等落档。
      await settleFlush();

      final ProgressState state = repo.current;
      expect(state.stats.totalGames, 1);
      expect(state.stats.completedGames, 1);
      expect(state.stats.records.single.completed, isTrue);
    });
  });
}
