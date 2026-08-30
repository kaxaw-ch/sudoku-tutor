/// T-DOM-01 · JSON 存档仓储集成测试（P0-STO-01/02/03/04/05/06）。
///
/// 覆盖：首启 deviceId 生成与稳定、save/load 往返、updateLevel、
/// 断点存取、**导出/导入往返一致**、**v1 自动迁移 + 迁移前自动备份**、
/// 重置全部进度。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';
import 'package:sudoku_tutor/domain/storage/atomic_file.dart';
import 'package:sudoku_tutor/domain/storage/backup_service.dart';
import 'package:sudoku_tutor/domain/storage/json_progress_repository.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/models/session_snapshot.dart';
import 'package:sudoku_tutor/domain/storage/models/teaching_session_snapshot.dart';
import 'package:sudoku_tutor/domain/storage/schema_migration.dart';
import 'package:sudoku_tutor/domain/storage/storage_paths.dart';

void main() {
  late Directory temp;
  late StoragePaths paths;
  late JsonProgressRepository repo;
  late BackupService backup;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('sudoku_repo_test_');
    paths = StoragePaths(appSupport: temp);
    backup = BackupService(backupsDir: paths.backupsDir);
    repo = JsonProgressRepository(
      paths: paths,
      io: const AtomicFile(),
      migration: SchemaMigration(),
      backupService: backup,
    );
  });

  tearDown(() {
    if (temp.existsSync()) {
      temp.deleteSync(recursive: true);
    }
  });

  test('首启生成 deviceId 并落盘；再次 load 拿到同一标识', () async {
    final ProgressState first = await repo.load();
    expect(first.deviceId, isNotEmpty);
    expect(first.schemaVersion, kProgressSchemaVersion);
    // 首次 load 应立即落盘。
    expect(await paths.progressFile.exists(), isTrue);

    final ProgressState second = await repo.load();
    expect(second.deviceId, first.deviceId, reason: '设备标识必须跨会话稳定');
  });

  test('save → load 往返一致', () async {
    final ProgressState state = (await repo.load()).copyWith(
      onboardingDone: true,
      levels: <String, LevelProgress>{
        'ch0_l01': const LevelProgress(
          levelId: 'ch0_l01',
          status: LevelStatus.completed,
          stars: 3,
          durationMs: 12345,
          attempts: 2,
          lastPlayedAt: 111,
        ),
      },
    );
    await repo.save(state);

    final ProgressState loaded = await repo.load();
    expect(loaded.onboardingDone, isTrue);
    expect(loaded.levels['ch0_l01']!.status, LevelStatus.completed);
    expect(loaded.levels['ch0_l01']!.stars, 3);
    expect(loaded.deviceId, state.deviceId);
  });

  test('updateLevel 便捷 upsert', () async {
    await repo.updateLevel(
      const LevelProgress(
        levelId: 'ch1_l02',
        status: LevelStatus.unlocked,
        hintUsed: 2,
      ),
    );
    final ProgressState loaded = await repo.load();
    expect(loaded.levels['ch1_l02']!.hintUsed, 2);

    await repo.updateLevel(
      const LevelProgress(
        levelId: 'ch1_l02',
        status: LevelStatus.completed,
      ),
    );
    final ProgressState after = await repo.load();
    expect(after.levels['ch1_l02']!.status, LevelStatus.completed);
    expect(after.levels, hasLength(1));
  });

  test('对局断点 save/load/clear', () async {
    expect(await repo.loadSession(), isNull);

    const SessionSnapshot snapshot = SessionSnapshot(
      puzzle81: '53..7....',
      board81: '53..7....',
      elapsedMs: 60000,
      difficultyId: 'medium',
      savedAt: 999,
    );
    await repo.saveSession(snapshot);
    final SessionSnapshot? loaded = await repo.loadSession();
    expect(loaded, isNotNull);
    expect(loaded!.elapsedMs, 60000);
    expect(loaded.difficultyId, 'medium');

    await repo.clearSession();
    expect(await repo.loadSession(), isNull);
  });

  test('教学关断点按关卡独立保存，且文件不含操作历史', () async {
    const TeachingSessionSnapshot first = TeachingSessionSnapshot(
      levelId: 'ch0_l02',
      puzzle81: 'puzzle-a',
      board81: 'board-a',
      elapsedMs: 1234,
      noteMasks: <int>[1, 2, 4],
      hintUsed: 2,
      errorCount: 1,
    );
    const TeachingSessionSnapshot second = TeachingSessionSnapshot(
      levelId: 'ch1_l03',
      puzzle81: 'puzzle-b',
      board81: 'board-b',
      elapsedMs: 5678,
    );

    await repo.saveTeachingSession(first);
    await repo.saveTeachingSession(second);
    expect((await repo.loadTeachingSession('ch0_l02'))!.board81, 'board-a');
    expect((await repo.loadTeachingSession('ch1_l03'))!.board81, 'board-b');

    final String raw = await paths.teachingSessionsFile.readAsString();
    expect(raw, isNot(contains('undoStack')));
    expect(raw, isNot(contains('redoStack')));

    await repo.clearTeachingSession('ch0_l02');
    expect(await repo.loadTeachingSession('ch0_l02'), isNull);
    expect(await repo.loadTeachingSession('ch1_l03'), isNotNull);
  });

  test('导出 → 导入 往返一致（含 settings/levels/stats）', () async {
    final ProgressState state = (await repo.load()).copyWith(
      onboardingDone: true,
      levels: <String, LevelProgress>{
        'ch0_l01': const LevelProgress(
          levelId: 'ch0_l01',
          status: LevelStatus.completed,
          stars: 2,
        ),
      },
    );
    await repo.save(state);

    final String exported = await repo.exportArchive();
    // 先清空再导入，模拟「换设备恢复」。
    await repo.resetAll();
    await repo.importArchive(exported);

    final ProgressState reloaded = await repo.load();
    expect(reloaded.onboardingDone, isTrue);
    expect(reloaded.levels['ch0_l01']!.stars, 2);
    expect(reloaded.deviceId, state.deviceId, reason: '导入档 deviceId 应保留');
  });

  test('v1 老档 load 时自动迁移到当前版本，且迁移前自动备份', () async {
    await paths.ensureDirectories();
    // 直接写入一份 v1 老档（模拟旧版本 App 遗留数据）。
    await paths.progressFile.writeAsString(
      '{"schemaVersion":1,"deviceId":"legacy-dev",'
      '"levels":{"ch0_l01":{"levelId":"ch0_l01"}}}',
      flush: true,
    );

    final ProgressState loaded = await repo.load();
    expect(loaded.deviceId, 'legacy-dev');
    expect(loaded.schemaVersion, kProgressSchemaVersion);

    // 迁移前自动备份应已生成（gzip 文件存在于 backups/）。
    final List<File> backups = await backup.listBackups();
    expect(backups, hasLength(1));
    expect(backups.first.path, contains('before_migrate'));

    // 迁移结果已原子写回。
    final File onDisk = paths.progressFile;
    final String raw = await onDisk.readAsString();
    expect(raw, contains('"schemaVersion": 2'));
    expect(raw, contains('"mistakeBook"'));
  });

  test('导入版本高于当前 → E_SCHEMA_001 拒绝', () async {
    await expectLater(
      repo.importArchive('{"schemaVersion":99,"deviceId":"future"}'),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_SCHEMA_001'),
      ),
    );
  });

  test('导入非法 JSON → E_IMPORT_001', () async {
    await expectLater(
      repo.importArchive('{ 不是 JSON'),
      throwsA(
        isA<AppError>().having((AppError e) => e.code, 'code', 'E_IMPORT_001'),
      ),
    );
  });

  test('resetAll 删除进度档、自由练习断点与教学断点', () async {
    await repo.save((await repo.load()).copyWith(onboardingDone: true));
    await repo.saveSession(
      const SessionSnapshot(puzzle81: 'x', board81: 'y', elapsedMs: 1),
    );
    await repo.saveTeachingSession(
      const TeachingSessionSnapshot(
        levelId: 'ch0_l02',
        puzzle81: 'x',
        board81: 'y',
        elapsedMs: 1,
      ),
    );
    await repo.resetAll();

    expect(await paths.progressFile.exists(), isFalse);
    expect(await paths.sessionFile.exists(), isFalse);
    expect(await paths.teachingSessionsFile.exists(), isFalse);
  });
}
