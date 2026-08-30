/// `ProgressRepository` 的 JSON 文件实现（P0-STO-01，零数据库依赖）。
///
/// 依赖图（架构 §4.3 类图）：`StoragePaths` + `AtomicFile` + `SchemaMigration`，
/// 另注入 `BackupService` 承接「迁移前自动备份」（PRD C-26）。
///
/// 读取链路：
///   1. 读 `progress.json`；无档 → 生成初始档（新 `deviceId`）并落盘；
///   2. 版本低于当前 → **先备份旧档** → 链式迁移 → 原子写回；
///   3. 版本高于当前 → 抛 `E_SCHEMA_001`（提示升级 App）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sudoku_tutor/domain/domain_error.dart';

import 'atomic_file.dart';
import 'backup_service.dart';
import 'models/level_progress.dart';
import 'models/progress_state.dart';
import 'models/session_snapshot.dart';
import 'models/teaching_session_snapshot.dart';
import 'progress_repository.dart';
import 'schema_migration.dart';
import 'storage_paths.dart';

/// JSON 文件存档仓储。
class JsonProgressRepository implements ProgressRepository {
  /// 构造仓储。
  ///
  /// [backupService] 缺省时按 [paths] 自建（指向 `backups/` 目录）。
  JsonProgressRepository({
    required StoragePaths paths,
    required AtomicFile io,
    required SchemaMigration migration,
    BackupService? backupService,
  })  : _paths = paths,
        _io = io,
        _migration = migration,
        _backup = backupService ?? BackupService(backupsDir: paths.backupsDir);

  final StoragePaths _paths;
  final AtomicFile _io;
  final SchemaMigration _migration;
  final BackupService _backup;

  @override
  Future<ProgressState> load() async {
    await _paths.ensureDirectories();
    final Map<String, Object?>? raw = await _io.readJson(_paths.progressFile);
    if (raw == null) {
      // 首启：生成 deviceId 并立即落盘，保证后续会话拿到同一设备标识。
      final ProgressState initial = _freshState();
      await save(initial);
      return initial;
    }
    return _loadMigrated(raw);
  }

  /// 版本检查 + 迁移 + 备份的共用链路（load / import 复用）。
  Future<ProgressState> _loadMigrated(Map<String, Object?> raw) async {
    if (_migration.isTooNew(raw)) {
      throw AppError.schemaTooNew(
        SchemaMigration.versionOf(raw),
        _migration.currentVersion,
      );
    }
    if (_migration.needsMigration(raw)) {
      // PRD C-26：升级前自动备份旧档（备份失败不阻断升级）。
      try {
        await _backup.createBackup(_paths.progressFile,
            reason: 'before_migrate');
      } on Object {
        // 见上：备份尽力而为。
      }
      final Map<String, Object?> migrated = _migration.migrate(raw);
      await _io.writeJson(_paths.progressFile, migrated);
      raw = migrated;
    }

    ProgressState state = ProgressState.fromJson(raw);
    // 兜底：极老档缺 deviceId 时补一个并落盘。
    if (state.deviceId.isEmpty) {
      state = state.copyWith(deviceId: _uuidV4());
      await save(state);
    }
    return state;
  }

  @override
  Future<void> save(ProgressState state) async {
    await _paths.ensureDirectories();
    try {
      await _io.writeJson(_paths.progressFile, state.toJson());
    } on FileSystemException catch (e) {
      throw AppError.ioWrite(_paths.progressFile.path, e);
    }
  }

  @override
  Future<void> updateLevel(LevelProgress progress) async {
    final ProgressState current = await load();
    final Map<String, LevelProgress> levels =
        Map<String, LevelProgress>.of(current.levels)
          ..[progress.levelId] = progress;
    await save(current.copyWith(levels: levels));
  }

  @override
  Future<SessionSnapshot?> loadSession() async {
    await _paths.ensureDirectories();
    final Map<String, Object?>? raw = await _io.readJson(_paths.sessionFile);
    if (raw == null) {
      return null;
    }
    return SessionSnapshot.fromJson(raw);
  }

  @override
  Future<void> saveSession(SessionSnapshot snapshot) async {
    await _paths.ensureDirectories();
    try {
      await _io.writeJson(_paths.sessionFile, snapshot.toJson());
    } on FileSystemException catch (e) {
      throw AppError.ioWrite(_paths.sessionFile.path, e);
    }
  }

  @override
  Future<void> clearSession() async {
    await _io.deleteIfExists(_paths.sessionFile);
  }

  @override
  Future<TeachingSessionSnapshot?> loadTeachingSession(String levelId) async {
    await _paths.ensureDirectories();
    final Map<String, Object?>? raw =
        await _io.readJson(_paths.teachingSessionsFile);
    final Object? sessionsRaw = raw?['sessions'];
    if (sessionsRaw is! Map) {
      return null;
    }
    final Object? snapshotRaw = sessionsRaw[levelId];
    if (snapshotRaw is! Map) {
      return null;
    }
    return TeachingSessionSnapshot.fromJson(
      Map<String, Object?>.from(snapshotRaw),
    );
  }

  @override
  Future<void> saveTeachingSession(TeachingSessionSnapshot snapshot) async {
    await _paths.ensureDirectories();
    final Map<String, Object?>? raw =
        await _io.readJson(_paths.teachingSessionsFile);
    final Map<String, Object?> sessions = <String, Object?>{
      if (raw?['sessions'] is Map)
        ...Map<String, Object?>.from(raw!['sessions']! as Map),
      snapshot.levelId: snapshot.toJson(),
    };
    try {
      await _io.writeJson(
        _paths.teachingSessionsFile,
        <String, Object?>{'schemaVersion': 1, 'sessions': sessions},
      );
    } on FileSystemException catch (e) {
      throw AppError.ioWrite(_paths.teachingSessionsFile.path, e);
    }
  }

  @override
  Future<void> clearTeachingSession(String levelId) async {
    final Map<String, Object?>? raw =
        await _io.readJson(_paths.teachingSessionsFile);
    if (raw?['sessions'] is! Map) {
      return;
    }
    final Map<String, Object?> sessions =
        Map<String, Object?>.from(raw!['sessions']! as Map)..remove(levelId);
    if (sessions.isEmpty) {
      await _io.deleteIfExists(_paths.teachingSessionsFile);
      return;
    }
    await _io.writeJson(
      _paths.teachingSessionsFile,
      <String, Object?>{'schemaVersion': 1, 'sessions': sessions},
    );
  }

  @override
  Future<String> exportArchive() async {
    final Map<String, Object?>? raw = await _io.readJson(_paths.progressFile);
    final Map<String, Object?> data = raw ?? (await load()).toJson();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Future<void> importArchive(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw AppError.importFormat('不是合法的 JSON');
    }
    if (decoded is! Map) {
      throw AppError.importFormat('顶层必须是 JSON 对象');
    }
    final Map<String, Object?> raw = Map<String, Object?>.from(decoded);

    // 版本校验：高于当前 → 拒绝并提示升级。
    if (_migration.isTooNew(raw)) {
      throw AppError.schemaTooNew(
        SchemaMigration.versionOf(raw),
        _migration.currentVersion,
      );
    }

    // 迁移链校验 + 应用（缺链抛 E_SCHEMA_002）。
    Map<String, Object?> target = raw;
    if (_migration.needsMigration(raw)) {
      target = _migration.migrate(raw);
    }

    await _paths.ensureDirectories();
    // P0-STO-06：导入前自动备份当前档（UI 层负责二次确认）。
    try {
      await _backup.createBackup(_paths.progressFile, reason: 'before_import');
    } on Object {
      // 尽力而为。
    }
    try {
      await _io.writeJson(_paths.progressFile, target);
    } on FileSystemException catch (e) {
      throw AppError.ioWrite(_paths.progressFile.path, e);
    }
  }

  @override
  Future<void> resetAll() async {
    await _io.deleteIfExists(_paths.progressFile);
    await _io.deleteIfExists(_paths.sessionFile);
    await _io.deleteIfExists(_paths.teachingSessionsFile);
  }

  /// 构造一份全新的初始存档（新 `deviceId`）。
  ProgressState _freshState() => ProgressState(
        schemaVersion: _migration.currentVersion,
        deviceId: _uuidV4(),
      );

  /// 生成 UUIDv4（dart:math 实现，不依赖任何包；不采集硬件标识）。
  static String _uuidV4() {
    final Random rng = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // v4：版本位 4，变体位 8/9/10。
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final String hex =
        bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
