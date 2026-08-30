/// 开发者模式（P0-EDU-10，S-12，T-UI-05）。
///
/// 职责分两半：
/// - [DeveloperMode]：**版本号连点 7 次**进入开发者模式的计数逻辑
///   （带时间窗口，防止误触）；
/// - [DeveloperTools]：开发者模式页的功能实现——全解锁 / 重置进度 /
///   跳关（解锁指定关） / 查看关卡元信息（用已存的 `LevelProgress` 数据）。
///
/// ⚠️ 关卡元信息展示**只读存档中已存在的 `levels`**（批次 F 课程内容落地后
/// 自然随存档填充），本期不读取 assets/curriculum，避免耦合未交付内容。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_providers.dart';
import '../storage/models/level_progress.dart';
import '../storage/models/progress_state.dart';
import '../storage/progress_repository.dart';

/// 连点进入开发者模式所需的次数（S-08：版本号连点 7 次）。
const int kDeveloperTapThreshold = 7;

/// 连点有效时间窗口（超过则计数清零）。
const Duration kDeveloperTapWindow = Duration(seconds: 3);

/// 开发者模式连点计数逻辑。
class DeveloperMode {
  /// 构造计数逻辑；[now] 可注入（测试控制时间）。
  DeveloperMode({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  int _tapCount = 0;
  DateTime? _lastTapAt;
  bool _unlocked = false;

  /// 是否已解锁开发者模式。
  bool get isUnlocked => _unlocked;

  /// 记录一次点击；返回是否**本次点击达到阈值**。
  ///
  /// 点击间隔超过 [kDeveloperTapWindow] 时计数清零重新累计。
  bool registerTap() {
    final DateTime now = _now();
    final DateTime? last = _lastTapAt;
    _lastTapAt = now;
    if (last == null || now.difference(last) > kDeveloperTapWindow) {
      _tapCount = 0;
    }
    _tapCount++;
    if (_tapCount >= kDeveloperTapThreshold) {
      _unlocked = true;
      _tapCount = 0;
      return true;
    }
    return false;
  }

  /// 重置（退出开发者模式 / 测试收尾）。
  void reset() {
    _tapCount = 0;
    _lastTapAt = null;
    _unlocked = false;
  }
}

/// 开发者模式 Provider（连点计数状态常驻）。
final Provider<DeveloperMode> developerModeProvider = Provider<DeveloperMode>(
  (Ref ref) => DeveloperMode(),
);

/// 开发者工具（对存档的读改写，供开发者页调用）。
class DeveloperTools {
  /// 构造工具；[repository] 为仓储（Provider 装配时传 Future，方法内 await）。
  DeveloperTools({required Future<ProgressRepository> repository})
      : _repositoryFuture = repository;

  final Future<ProgressRepository> _repositoryFuture;

  /// 全解锁：把存档中**已存在**的关卡全部置为「已完成」。
  Future<void> unlockAll() async {
    final ProgressRepository repo = await _repositoryFuture;
    final ProgressState state = await repo.load();
    final Map<String, LevelProgress> next = <String, LevelProgress>{};
    for (final MapEntry<String, LevelProgress> entry in state.levels.entries) {
      next[entry.key] = _withStatus(entry.value, LevelStatus.completed);
    }
    await repo.save(state.copyWith(levels: next));
  }

  /// 重置全部进度（删除进度档与断点，二次确认由 UI 层负责）。
  Future<void> resetProgress() async {
    final ProgressRepository repo = await _repositoryFuture;
    await repo.resetAll();
  }

  /// 跳关：解锁（或标记为可玩）指定关卡。
  ///
  /// 本期课程内容未交付，允许**任意关卡 ID 预注册为「已解锁」**
  /// （开发者模式的临时能力；批次 F 课程落地后自然与 index.json 对齐）。
  Future<void> unlockLevel(String levelId) async {
    final ProgressRepository repo = await _repositoryFuture;
    final ProgressState state = await repo.load();
    final LevelProgress? existing = state.levels[levelId];
    final LevelProgress next = _withStatus(
      existing ?? LevelProgress(levelId: levelId),
      LevelStatus.unlocked,
    );
    final Map<String, LevelProgress> levels = Map<String, LevelProgress>.of(
      state.levels,
    )..[levelId] = next;
    await repo.save(state.copyWith(levels: levels));
  }

  /// 查看关卡元信息（按 levelId 排序，读取已存档数据）。
  Future<List<LevelProgress>> listLevels() async {
    final ProgressRepository repo = await _repositoryFuture;
    final ProgressState state = await repo.load();
    final List<LevelProgress> levels = state.levels.values.toList()
      ..sort(
        (LevelProgress a, LevelProgress b) => a.levelId.compareTo(b.levelId),
      );
    return levels;
  }

  /// 构造「仅替换状态」的关卡进度副本（`LevelProgress` 无 `copyWith`，手动复制）。
  static LevelProgress _withStatus(LevelProgress p, LevelStatus status) =>
      LevelProgress(
        levelId: p.levelId,
        status: status,
        stars: p.stars,
        hintUsed: p.hintUsed,
        errorCount: p.errorCount,
        durationMs: p.durationMs,
        attempts: p.attempts,
        lastPlayedAt: p.lastPlayedAt,
      );
}

/// 开发者工具 Provider（懒装配仓储 Future，方法内 await）。
final Provider<DeveloperTools> developerToolsProvider =
    Provider<DeveloperTools>(
  (Ref ref) => DeveloperTools(
    repository: ref.watch(progressRepositoryProvider.future),
  ),
);
