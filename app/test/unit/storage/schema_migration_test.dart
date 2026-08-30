/// T-DOM-01 · 存档链式迁移测试（P0-STO-04 / PRD C-26）。
///
/// 覆盖：v1→当前迁移链真实执行、迁移补全字段、版本高于当前拒绝
/// （`E_SCHEMA_001`）、迁移链缺失报错（`E_SCHEMA_002`）、路径描述。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';
import 'package:sudoku_tutor/domain/storage/schema_migration.dart';

void main() {
  group('SchemaMigration（默认链 v1→v2，当前版本 2）', () {
    final SchemaMigration migration = SchemaMigration();

    test('当前版本常量与默认链一致', () {
      expect(kProgressSchemaVersion, 2);
      expect(migration.currentVersion, 2);
      expect(migration.chain, hasLength(1));
    });

    test('v1 存档可经迁移链升到当前版本，且缺失字段被补全', () {
      // 构造一份「老版 v1」：故意缺 stats / mistakeBook / onboardingDone。
      final Map<String, Object?> v1 = <String, Object?>{
        'schemaVersion': 1,
        'deviceId': 'dev-1',
        'levels': <String, Object?>{
          'ch0_l01': <String, Object?>{'levelId': 'ch0_l01'},
        },
        'settings': <String, Object?>{'theme': 'white'},
      };

      expect(migration.needsMigration(v1), isTrue);
      final Map<String, Object?> v2 = migration.migrate(v1);

      expect(v2['schemaVersion'], 2);
      expect(v2['stats'], isA<Map<String, Object?>>());
      expect(v2['mistakeBook'], isA<Map<String, Object?>>());
      expect(v2['onboardingDone'], false);
      // 迁移不得丢已有数据。
      expect(v2['deviceId'], 'dev-1');
      expect(migration.needsMigration(v2), isFalse);
    });

    test('当前版本存档无需迁移', () {
      final Map<String, Object?> current = <String, Object?>{
        'schemaVersion': 2,
        'deviceId': 'dev-2',
      };
      expect(migration.needsMigration(current), isFalse);
    });

    test('版本高于当前 → E_SCHEMA_001（提示升级 App）', () {
      final Map<String, Object?> future = <String, Object?>{
        'schemaVersion': 99,
        'deviceId': 'x',
      };
      expect(migration.isTooNew(future), isTrue);
      expect(
        () => migration.migrate(future),
        throwsA(
          isA<AppError>()
              .having((AppError e) => e.code, 'code', 'E_SCHEMA_001'),
        ),
      );
    });

    test('迁移路径描述正确', () {
      expect(migration.describePath(1), 'v1 → v2');
    });
  });

  group('迁移链缺失（E_SCHEMA_002）', () {
    test('缺少 v2→v3 步骤时报错', () {
      // 只有 v1→v2，却要求当前版本 3。
      final SchemaMigration broken = SchemaMigration(
        currentVersion: 3,
        chain: const <ProgressMigration>[MigrateV1ToV2()],
      );
      final Map<String, Object?> v2 = <String, Object?>{
        'schemaVersion': 2,
        'deviceId': 'dev',
      };
      expect(
        () => broken.migrate(v2),
        throwsA(
          isA<AppError>()
              .having((AppError e) => e.code, 'code', 'E_SCHEMA_002'),
        ),
      );
    });

    test('版本号缺失按 v1 处理（最老档兼容）', () {
      final SchemaMigration migration = SchemaMigration();
      final Map<String, Object?> noVersion = <String, Object?>{'deviceId': 'd'};
      expect(SchemaMigration.versionOf(noVersion), 1);
      final Map<String, Object?> migrated = migration.migrate(noVersion);
      expect(migrated['schemaVersion'], 2);
    });
  });
}
