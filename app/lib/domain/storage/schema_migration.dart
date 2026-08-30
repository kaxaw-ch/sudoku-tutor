/// 存档链式迁移（P0-STO-04 / 架构 §7.2）。
///
/// 设计（与 PRD C-26「从第一版就要有」对齐）：
/// - 存档携带 `schemaVersion`，逐版本链式迁移 `v1→v2→…`；
/// - 每个迁移只负责「上一个版本 → 下一版本」的一小步，绝不跨档；
/// - 迁移前由 `JsonProgressRepository` 调用 `BackupService` 自动备份；
/// - 版本高于当前 App → 拒绝并提示升级（`E_SCHEMA_001`）；
/// - 迁移链缺失 → 直接报错（`E_SCHEMA_002`），不猜、不静默。
///
/// 版本说明：架构 §7.2 将存档首版记为 1；**当前实现基线为 2**，
/// `v1→v2` 迁移真实存在（补全 v1 缺失的统计/错题本/引导字段），
/// 使「从 v1 升到当前 + 自动备份」成为可执行可验证的验收路径。
library;

import 'package:sudoku_tutor/domain/domain_error.dart';

/// 当前存档 schema 版本。
const int kProgressSchemaVersion = 2;

/// 单步迁移（一个版本 → 下一个版本）。
abstract class ProgressMigration {
  /// 迁移的起始版本。
  int get fromVersion;

  /// 迁移的目标版本。
  int get toVersion;

  /// 对原始 JSON 应用迁移，返回下一版本的 JSON（调用方保证版本号字段正确）。
  Map<String, Object?> apply(Map<String, Object?> raw);
}

/// v1 → v2 迁移：补全 v1 存档缺失的结构化字段。
///
/// v1 语义（批次 E 之前的原型）不保证存在 `stats` / `mistakeBook` /
/// `onboardingDone` / `settings` 完整字段；v2 统一补齐默认结构，
/// 让后续版本可以安心以「字段必存在」为前提做差量迁移。
class MigrateV1ToV2 implements ProgressMigration {
  /// 构造迁移。
  const MigrateV1ToV2();

  @override
  int get fromVersion => 1;

  @override
  int get toVersion => 2;

  @override
  Map<String, Object?> apply(Map<String, Object?> raw) {
    final Map<String, Object?> out = Map<String, Object?>.of(raw);

    // 统计：v1 缺省 → 空统计结构。
    final Object? stats = out['stats'];
    if (stats is! Map) {
      out['stats'] = <String, Object?>{
        'records': <Object?>[],
        'completedGames': 0,
        'totalGames': 0,
        'totalDurationMs': 0,
        'totalHints': 0,
        'totalErrors': 0,
      };
    }

    // 错题本：v1 缺省 → 空列表。
    final Object? mistakeBook = out['mistakeBook'];
    if (mistakeBook is! Map) {
      out['mistakeBook'] = <String, Object?>{'entries': <Object?>[]};
    }

    // 首启引导：v1 缺省 → 未完成。
    out['onboardingDone'] = out['onboardingDone'] as bool? ?? false;

    // 版本号推进。
    out['schemaVersion'] = toVersion;
    return out;
  }
}

/// 链式迁移引擎。
class SchemaMigration {
  /// 构造迁移引擎（缺省为当前版本 + 内置 v1→v2 链）。
  SchemaMigration({
    int? currentVersion,
    List<ProgressMigration>? chain,
  })  : currentVersion = currentVersion ?? kProgressSchemaVersion,
        chain = List<ProgressMigration>.unmodifiable(
          chain ?? const <ProgressMigration>[MigrateV1ToV2()],
        );

  /// 当前版本（迁移链目标）。
  final int currentVersion;

  /// 迁移链（按 fromVersion 升序）。
  final List<ProgressMigration> chain;

  /// 版本号读取（缺省按 v1 处理，与「无版本号即最老档」兼容）。
  static int versionOf(Map<String, Object?> raw) =>
      (raw['schemaVersion'] as int?) ?? 1;

  /// 是否需要迁移（低于当前版本即需要）。
  bool needsMigration(Map<String, Object?> raw) =>
      versionOf(raw) < currentVersion;

  /// 是否高于当前版本（导入/读取时先拦一道）。
  bool isTooNew(Map<String, Object?> raw) => versionOf(raw) > currentVersion;

  /// 链式迁移 [raw] 到当前版本。
  ///
  /// - 版本高于当前 → `E_SCHEMA_001`；
  /// - 缺少中间档迁移 → `E_SCHEMA_002`；
  /// - 正常返回迁移后的 map。
  Map<String, Object?> migrate(Map<String, Object?> raw) {
    int version = versionOf(raw);
    if (version > currentVersion) {
      throw AppError.schemaTooNew(version, currentVersion);
    }
    Map<String, Object?> out = Map<String, Object?>.of(raw);
    while (version < currentVersion) {
      final ProgressMigration? step = _stepFrom(version);
      if (step == null) {
        throw AppError.schemaMigrationMissing(version, currentVersion);
      }
      out = step.apply(out);
      version = step.toVersion;
    }
    return out;
  }

  /// 记录一次迁移经过的版本序列（供日志/测试展示）。
  String describePath(int fromVersion) {
    int v = fromVersion;
    final List<String> hops = <String>['v$v'];
    while (v < currentVersion) {
      final ProgressMigration? step = _stepFrom(v);
      if (step == null) {
        break;
      }
      v = step.toVersion;
      hops.add('v$v');
    }
    return hops.join(' → ');
  }

  ProgressMigration? _stepFrom(int version) {
    for (final ProgressMigration step in chain) {
      if (step.fromVersion == version) {
        return step;
      }
    }
    return null;
  }
}
