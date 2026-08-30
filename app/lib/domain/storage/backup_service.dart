/// 存档备份服务（P0-STO-04 的「升级前自动备份」落地）。
///
/// 备份策略：
/// - 每次「迁移前备份」生成 `backups/backup_<时间戳>_<原因>.json.gz`；
/// - 用 gzip 压缩减小磁盘占用（与题库压缩口径一致，架构 §7.7）；
/// - 保留最近 [kBackupRetention]（10）份，更早的自动清理，防磁盘膨胀。
library;

import 'dart:io';

/// 备份服务。
class BackupService {
  /// 构造备份服务。
  BackupService({required this.backupsDir});

  /// 备份目录（由 `StoragePaths.backupsDir` 提供）。
  final Directory backupsDir;

  /// 保留的备份份数上限。
  static const int kBackupRetention = 10;

  /// 为 [source] 创建一个备份，返回备份文件；源文件不存在返回 `null`。
  ///
  /// [reason] 写入文件名便于人工辨认（如 `before_migrate` / `before_import`）。
  Future<File?> createBackup(File source, {String reason = 'manual'}) async {
    if (!await source.exists()) {
      return null;
    }
    await backupsDir.create(recursive: true);

    final String stamp = _stamp();
    final String fileName = 'backup_${stamp}_$reason.json.gz';
    final File target = File(
      '${backupsDir.path}${Platform.pathSeparator}$fileName',
    );
    final List<int> bytes = gzip.encode(await source.readAsBytes());
    await target.writeAsBytes(bytes, flush: true);

    await _prune();
    return target;
  }

  /// 列出全部备份（按创建时间倒序，最新在前）。
  Future<List<File>> listBackups() async {
    if (!await backupsDir.exists()) {
      return <File>[];
    }
    final List<File> files = backupsDir
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.json.gz'))
        .toList()
      ..sort((File a, File b) => b.path.compareTo(a.path));
    return files;
  }

  /// 恢复最新一份备份到 [target]（测试与「导入失败回滚」用）。
  ///
  /// 返回恢复的备份文件；无备份返回 `null`。
  Future<File?> restoreLatest({required File target}) async {
    final List<File> backups = await listBackups();
    if (backups.isEmpty) {
      return null;
    }
    final File latest = backups.first;
    final List<int> bytes = gzip.decode(await latest.readAsBytes());
    await target.writeAsBytes(bytes, flush: true);
    return latest;
  }

  /// 清理超出保留上限的旧备份。
  Future<void> _prune() async {
    final List<File> files = await listBackups();
    if (files.length <= kBackupRetention) {
      return;
    }
    // listBackups 已按时间倒序，尾部即最旧。
    for (final File f in files.skip(kBackupRetention)) {
      try {
        await f.delete();
      } on FileSystemException {
        // 清理失败不阻断主流程。
      }
    }
  }

  /// 生成备份时间戳（`yyyyMMdd_HHmmss` 本地时区，便于人工辨认）。
  static String _stamp() {
    final DateTime now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
