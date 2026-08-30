/// 统计采集（T-DOM-06，P0-STO-03「练习统计原始数据 P0 只采集不展示」）。
///
/// 职责：把一局自由练习的原始数据**真实写入存档**（[PracticeStats]），
/// 供批次 H 的统计看板（P2-STAT-01）直接消费，P0 不做任何 UI 展示。
///
/// 采集口径（对接 `GameSessionController`）：
/// - **开局**：`gameSessionControllerProvider` 状态 `null → 非 null`，记录难度与起始时间；
/// - **提示/错误/用时**：每次状态发布时读取 `usedHints / wrongCount / elapsedMs` 并累计；
/// - **完成**：监听 [GameCompletedEvent] → 写入一条 `completed=true` 记录；
/// - **放弃/覆盖**：状态 `非 null → null`（放弃）或题面指纹变化（新局覆盖）→
///   写入一条 `completed=false` 记录；
/// - **断点续玩**：续玩继续沿用同一局（指纹不变），不重复开局、不重复写记录。
///
/// ⚠️ 写入策略：每局最多写一条 [PracticeRecord]（`_flushed` 防重）；新局重置标志。
/// 统计写入失败（如存档 IO 异常）静默吞掉，绝不干扰对局。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/game_session.dart';
import '../session/game_session_controller.dart';
import '../session/session_providers.dart';
import '../storage/models/practice_stats.dart';
import '../storage/progress_repository.dart';

/// 统计采集器（实例由 Provider 装配，生命周期与 Provider 一致）。
class StatsCollector {
  /// 构造采集器；[repository] 为存档仓储 Future（测试可注入内存实现）。
  StatsCollector({required Future<ProgressRepository> repository})
      : _repositoryFuture = repository;

  final Future<ProgressRepository> _repositoryFuture;

  // ---- 本局跟踪状态 ----
  String? _activeDifficultyId;
  int _startedAt = 0;
  int _hintCount = 0;
  int _errorCount = 0;
  int _durationMs = 0;
  bool _completed = false;
  bool _flushed = false;

  /// 是否正在采集一局。
  bool get isActive => _activeDifficultyId != null;

  // ------------------------------------------------------------ 事件/状态入口

  /// 对局状态变化回调（Provider 用 `ref.listen` 接入）。
  ///
  /// 返回是否发生了「本局终结并写入」。
  void onSessionChanged(GameSession? previous, GameSession? next) {
    final String? prevFp = previous?.puzzle.fingerprint;
    final String? nextFp = next?.puzzle.fingerprint;
    final bool isNewGame = prevFp != nextFp;
    if (isNewGame && prevFp != null) {
      // 旧局被新局覆盖：旧局未完成，写一条 completed=false。
      _flush(completed: false);
    }
    if (next == null) {
      // 会话结束（放弃/清空）：本局未完成。
      _flush(completed: false);
      return;
    }
    if (_activeDifficultyId == null || isNewGame) {
      _begin(next);
    } else {
      _track(next);
    }
  }

  /// 对局事件回调（Provider 订阅 `controller.events`）。
  void onEvent(GameSessionEvent event) {
    if (event is GameCompletedEvent) {
      _flush(completed: true);
    }
  }

  /// 立即结算并写入当前局（测试直接调用）。
  Future<void> flushNow({required bool completed}) =>
      _flush(completed: completed);

  /// 重置本局跟踪（新对局开始前调用）。
  void reset() {
    _activeDifficultyId = null;
    _flushed = true;
  }

  // ------------------------------------------------------------ 内部

  /// 开局：记录难度与起始时间。
  void _begin(GameSession session) {
    _activeDifficultyId = session.difficulty.id;
    _startedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    _hintCount = session.usedHints;
    _errorCount = session.wrongCount;
    _durationMs = session.elapsedMs;
    _completed = session.completed;
    _flushed = false;
  }

  /// 同局状态更新：累计提示/错误/用时。
  void _track(GameSession session) {
    _hintCount = session.usedHints;
    _errorCount = session.wrongCount;
    _durationMs = session.elapsedMs;
  }

  /// 把当前局写入存档；`_flushed` 防重写。
  Future<void> _flush({required bool completed}) async {
    final String? flushedDifficulty = _activeDifficultyId;
    if (flushedDifficulty == null || _flushed) {
      return;
    }
    _flushed = true;
    _completed = completed || _completed;
    final PracticeRecord record = PracticeRecord(
      difficultyId: flushedDifficulty,
      startedAt: _startedAt,
      durationMs: _durationMs,
      hintCount: _hintCount,
      errorCount: _errorCount,
      completed: _completed,
    );
    try {
      final ProgressRepository repo = await _repositoryFuture;
      final state = await repo.load();
      await repo.save(state.copyWith(stats: _append(state.stats, record)));
    } on Object {
      // 统计采集失败不影响对局（铁律）。
    }
    // 仅当当前 active 仍是本局时才清空：若落档期间已开新局
    // （`_begin` 覆盖了 `_activeDifficultyId`/`_flushed`），
    // 不得误清新局的采集状态（新局覆盖旧局的并发场景）。
    if (_activeDifficultyId == flushedDifficulty) {
      _activeDifficultyId = null;
    }
  }

  /// 追加一条记录并同步聚合字段。
  static PracticeStats _append(PracticeStats stats, PracticeRecord record) {
    final List<PracticeRecord> records = List<PracticeRecord>.of(stats.records)
      ..add(record);
    return PracticeStats(
      records: records,
      completedGames: stats.completedGames + (record.completed ? 1 : 0),
      totalGames: stats.totalGames + 1,
      totalDurationMs: stats.totalDurationMs + record.durationMs,
      totalHints: stats.totalHints + record.hintCount,
      totalErrors: stats.totalErrors + record.errorCount,
    );
  }
}

/// 统计采集器 Provider（app 级常驻，P0 只写不展示）。
final Provider<StatsCollector> statsCollectorProvider =
    Provider<StatsCollector>(
  (Ref ref) {
    final StatsCollector collector = StatsCollector(
      repository: ref.watch(progressRepositoryProvider.future),
    );
    // 对局状态变化 → 采集。
    ref.listen<GameSession?>(
      gameSessionControllerProvider,
      (GameSession? prev, GameSession? next) {
        collector.onSessionChanged(prev, next);
      },
    );
    // 订阅完成事件（GameCompletedEvent → completed=true 结算）。
    final GameSessionController controller =
        ref.read(gameSessionControllerProvider.notifier);
    final StreamSubscription<GameSessionEvent> sub =
        controller.events.listen(collector.onEvent);
    ref.onDispose(() {
      sub.cancel();
      collector.reset();
    });
    return collector;
  },
);
