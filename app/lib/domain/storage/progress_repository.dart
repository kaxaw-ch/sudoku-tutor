/// `ProgressRepository` 抽象接口（P0-STO-02）。
///
/// 单一存储抽象，实现可替换（当前为 JSON 文件实现 `JsonProgressRepository`，
/// 未来若需 DB 可无损换实现，UI 层只依赖本接口）。
library;

import 'models/level_progress.dart';
import 'models/progress_state.dart';
import 'models/session_snapshot.dart';
import 'models/teaching_session_snapshot.dart';

/// 存档仓储接口。
abstract class ProgressRepository {
  /// 加载存档；无档/首启返回初始状态（含新生成的 `deviceId`）。
  Future<ProgressState> load();

  /// 保存整份存档（原子写）。
  Future<void> save(ProgressState state);

  /// 更新一关的进度（便捷方法：载入 → upsert → 保存）。
  Future<void> updateLevel(LevelProgress progress);

  /// 加载对局断点；无断点返回 `null`。
  Future<SessionSnapshot?> loadSession();

  /// 保存对局断点（自由练习退出时，P0-PRA-09）。
  Future<void> saveSession(SessionSnapshot snapshot);

  /// 清除对局断点（新局开始时）。
  Future<void> clearSession();

  /// 加载指定引导实操关的轻量断点。
  Future<TeachingSessionSnapshot?> loadTeachingSession(String levelId);

  /// 保存引导实操关当前盘面（不含撤销/重做历史）。
  Future<void> saveTeachingSession(TeachingSessionSnapshot snapshot);

  /// 清除指定引导实操关断点（完成关卡或题面升级时）。
  Future<void> clearTeachingSession(String levelId);

  /// 导出存档为 JSON 字符串（桌面 file_selector / 移动 share_plus 用）。
  Future<String> exportArchive();

  /// 导入存档 JSON 字符串（含版本校验、迁移前自动备份）。
  ///
  /// 失败抛 `AppError`（`E_IMPORT_001` / `E_SCHEMA_001` 等），
  /// UI 层负责二次确认与结果提示。
  Future<void> importArchive(String json);

  /// 重置全部进度（二次确认由 UI 层负责）：删除进度档与对局断点。
  Future<void> resetAll();
}
