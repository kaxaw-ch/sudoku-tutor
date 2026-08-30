/// 设置控制器（P0-STO-08 冻结清单的读写入口，T-UI-05）。
///
/// 职责：把 `SettingsState` 与存档（[ProgressRepository]）桥接——
/// - **读**：从存档 `load()` 取出 `settings` 并发布为 Riverpod 状态；
/// - **写**：任一项更新都先 `load()` 完整进度，替换 `settings` 后 `save()`
///   （存档为不可变值对象，绝不小步写入导致丢字段）；
/// - 更新后同步发布新 `SettingsState`，设置页据此实时刷新。
///
/// 与 `GameSessionController` 的对接：自由练习开局时读取当前设置快照
/// （`autoCandidates / markErrors / highlightSameDigit` 作为本局开关）；
/// 对局中途改设置不影响本局（下一局生效），与现有设计一致。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_providers.dart';
import '../storage/models/settings_models.dart';
import '../storage/progress_repository.dart';

/// 设置控制器（`AsyncNotifier<SettingsState>`：初始加载完成后可用）。
class SettingsController extends AsyncNotifier<SettingsState> {
  /// 从存档加载设置。
  @override
  Future<SettingsState> build() async {
    final ProgressRepository repo =
        await ref.read(progressRepositoryProvider.future);
    final state = await repo.load();
    return state.settings;
  }

  // ------------------------------------------------------------ 更新入口

  /// 设置主题插槽（仅白色实现，粉/蓝置灰——UI 层不调用它们）。
  Future<void> setTheme(ThemeSlot slot) =>
      _update((SettingsState s) => s.copyWith(theme: slot));

  /// 棋盘配色主题（做题与所有教学棋盘即时共用）。
  Future<void> setBoardTheme(BoardThemeStyle style) =>
      _update((SettingsState s) => s.copyWith(boardTheme: style));

  /// 音效开关（默认关，P0-UI-09）。
  Future<void> setSoundOn(bool value) =>
      _update((SettingsState s) => s.copyWith(soundOn: value));

  /// 震动开关（移动端默认开）。
  Future<void> setHapticOn(bool value) =>
      _update((SettingsState s) => s.copyWith(hapticOn: value));

  /// 自动候选数（与手动笔记互斥）。
  Future<void> setAutoCandidates(bool value) =>
      _update((SettingsState s) => s.copyWith(autoCandidates: value));

  /// 错误标红。
  Future<void> setMarkErrors(bool value) =>
      _update((SettingsState s) => s.copyWith(markErrors: value));

  /// 计时显示。
  Future<void> setShowTimer(bool value) =>
      _update((SettingsState s) => s.copyWith(showTimer: value));

  /// 相同数字高亮。
  Future<void> setHighlightSameDigit(bool value) =>
      _update((SettingsState s) => s.copyWith(highlightSameDigit: value));

  /// 自由练习提示配额（关闭/3/5/不限）。
  Future<void> setHintQuota(HintQuota quota) =>
      _update((SettingsState s) => s.copyWith(hintQuota: quota));

  /// 开启开发者模式（版本号连点 7 次后调用；不提供关闭入口）。
  Future<void> enableDeveloperMode() =>
      _update((SettingsState s) => s.copyWith(developerMode: true));

  // ------------------------------------------------------------ 内部

  /// 读取存储仓储。
  Future<ProgressRepository> _repo() =>
      ref.read(progressRepositoryProvider.future);

  /// 应用变更：载入完整进度 → 替换设置 → 落盘 → 发布新状态。
  Future<void> _update(SettingsState Function(SettingsState) change) async {
    final ProgressRepository repo = await _repo();
    final progress = await repo.load();
    final SettingsState next = change(progress.settings);
    await repo.save(progress.copyWith(settings: next));
    state = AsyncData<SettingsState>(next);
  }
}

/// 设置控制器 Provider。
final AsyncNotifierProvider<SettingsController, SettingsState>
    settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);

/// 设置状态读取别名（UI 消费 `valueOrNull / future` 更直观）。
final Provider<AsyncValue<SettingsState>> settingsStateProvider =
    Provider<AsyncValue<SettingsState>>(
  (Ref ref) => ref.watch(settingsControllerProvider),
);
