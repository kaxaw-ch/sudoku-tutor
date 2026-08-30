/// 存档路径规划（架构文档 §7.7）。
///
/// 约定根目录：`getApplicationSupportDirectory()/sudoku_tutor/`，
/// 其下 `progress.json`（进度）、`session.json`（自由练习断点）、
/// `teaching_sessions.json`（各引导实操关轻量断点）、
/// `backups/`（迁移前备份）、`logs/`（崩溃日志）。
///
/// ⚠️ 本文件属 domain 层：`path_provider` 仅用于解析真实目录；
/// 测试通过 [StoragePaths.resolve] 的 [baseOverride] 参数注入临时目录，
/// 从而完全绕过插件通道（不依赖原生平台）。
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 存档目录与文件规划。
class StoragePaths {
  /// 应用数据根目录。
  final Directory appSupport;

  /// 构造路径规划（[appSupport] 为真实数据目录，测试用 [StoragePaths.resolve] 注入）。
  StoragePaths({required this.appSupport});

  /// 解析真实路径：优先 [baseOverride]（测试），否则走 `path_provider`。
  ///
  /// 生产环境要求先 `WidgetsFlutterBinding.ensureInitialized()`；
  /// `path_provider` 自身失败会抛出，本方法不额外包装。
  static Future<StoragePaths> resolve({Directory? baseOverride}) async {
    final Directory dir =
        baseOverride ?? await getApplicationSupportDirectory();
    return StoragePaths(appSupport: dir);
  }

  /// 应用数据根目录（`<appSupport>/sudoku_tutor`）。
  Directory get root => Directory(
        '${appSupport.path}${Platform.pathSeparator}sudoku_tutor',
      );

  /// 进度存档文件。
  File get progressFile =>
      File('${root.path}${Platform.pathSeparator}progress.json');

  /// 对局断点文件（自由练习断点续玩，T-DOM-04 消费）。
  File get sessionFile =>
      File('${root.path}${Platform.pathSeparator}session.json');

  /// 引导实操关轻量断点集合。
  File get teachingSessionsFile =>
      File('${root.path}${Platform.pathSeparator}teaching_sessions.json');

  /// 迁移前备份目录。
  Directory get backupsDir => Directory(
        '${root.path}${Platform.pathSeparator}backups',
      );

  /// 崩溃日志目录。
  Directory get logsDir =>
      Directory('${root.path}${Platform.pathSeparator}logs');

  /// 确保全部目录存在。
  Future<void> ensureDirectories() async {
    await root.create(recursive: true);
    await backupsDir.create(recursive: true);
    await logsDir.create(recursive: true);
  }
}
