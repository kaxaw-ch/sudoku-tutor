/// 关卡完成服务（T-EDU-01 / P0-EDU-09，星数 P2-ACH-02 预留）。
///
/// 关卡完成时把 `durationMs` / `errorCount` / `hintUsed` **从 P0 起真实写入**
/// [LevelProgress] 并计算星数（0..3）。
///
/// 星数规则（PRD C-25 未明示，采用任务给定的合理默认并注释）：
/// - 3 星：零提示 + 零错误；
/// - 2 星：提示 ≤ 配额一半（默认配额按 5 次计，一半取整 = 2）
///   且错误 ≤ 阈值（3 次）；
/// - 1 星：其余完成情况。
/// 阈值均为可调常量，主理人如需按最终 PRD 调整只改 [kTwoStarMaxHints]/
/// [kTwoStarMaxErrors]/[kDefaultHintQuota] 三处。
library;

import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';

/// 星数规则可调常量（注释见类头）。
const int kDefaultHintQuota = 5;

/// 2 星所需的提示上限：配额一半（`5 ~/ 2 = 2`）。
const int kTwoStarMaxHints = kDefaultHintQuota ~/ 2;

/// 2 星所需的错误上限。
const int kTwoStarMaxErrors = 3;

/// 关卡完成服务。
class LevelCompletionService {
  /// 构造服务；[repository] 为存档仓储 Future（测试可注入内存实现）。
  LevelCompletionService({required Future<ProgressRepository> repository})
      : _repositoryFuture = repository;

  final Future<ProgressRepository> _repositoryFuture;

  /// 计算星数（纯函数，测试直接断言）。
  ///
  /// - 零提示零错误 → 3 星；
  /// - 提示 ≤ 配额一半 且 错误 ≤ 阈值 → 2 星；
  /// - 其余完成 → 1 星。
  static int starsFor({required int hintUsed, required int errorCount}) {
    if (hintUsed <= 0 && errorCount <= 0) {
      return 3;
    }
    if (hintUsed <= kTwoStarMaxHints && errorCount <= kTwoStarMaxErrors) {
      return 2;
    }
    return 1;
  }

  /// 记录一次关卡完成（写入存档并返回进度对象）。
  ///
  /// - 三态置 `completed`，星数按本次 hint/error 计算；
  /// - `hintUsed`/`errorCount` 按**本关累计口径**与历史值合并
  ///   （`LevelProgress` 的字段语义是「累计」，对齐 T-DOM-01 模型注释）；
  /// - `durationMs` 取本次用时（教学关单次完成口径）；
  /// - `attempts` +1、`lastPlayedAt` 更新。
  Future<LevelProgress> recordCompletion({
    required String levelId,
    required int durationMs,
    required int hintUsed,
    required int errorCount,
  }) async {
    final ProgressRepository repository = await _repositoryFuture;
    final ProgressState state = await repository.load();
    final LevelProgress? prev = state.levels[levelId];
    final LevelProgress next = LevelProgress(
      levelId: levelId,
      status: LevelStatus.completed,
      stars: starsFor(hintUsed: hintUsed, errorCount: errorCount),
      hintUsed: (prev?.hintUsed ?? 0) + hintUsed,
      errorCount: (prev?.errorCount ?? 0) + errorCount,
      durationMs: durationMs,
      attempts: (prev?.attempts ?? 0) + 1,
      lastPlayedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await repository.updateLevel(next);
    return next;
  }

  /// 记录一次进入（`attempts` +1、`lastPlayedAt` 更新，状态不变）。
  ///
  /// 用于演示/实操关开局时记录「进入次数」；不改变三态与星数。
  Future<LevelProgress> recordEntry(String levelId) async {
    final ProgressRepository repository = await _repositoryFuture;
    final ProgressState state = await repository.load();
    final LevelProgress? prev = state.levels[levelId];
    final LevelProgress next = LevelProgress(
      levelId: levelId,
      status: prev?.status ?? LevelStatus.unlocked,
      stars: prev?.stars ?? 0,
      hintUsed: prev?.hintUsed ?? 0,
      errorCount: prev?.errorCount ?? 0,
      durationMs: prev?.durationMs ?? 0,
      attempts: (prev?.attempts ?? 0) + 1,
      lastPlayedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    await repository.updateLevel(next);
    return next;
  }
}
