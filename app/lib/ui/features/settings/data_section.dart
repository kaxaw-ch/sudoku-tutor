/// 设置页 · 数据分组（S-08，P0-STO-06/07/08，T-UI-05）。
///
/// 数据项：
/// - 导出存档（桌面 `file_selector` 选路径；移动端 `share_plus` 分享 JSON）；
/// - 导入存档（导入前二次确认 + 自动备份，P0-STO-06）；
/// - 清空错题本（P0 只采集，提供清空入口）；
/// - 重置全部进度（二次确认，P0-STO-08）；
/// - 导出日志（P0-STO-07）。
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/settings/settings_controller.dart';
import 'package:sudoku_tutor/domain/storage/crash_log_service.dart';
import 'package:sudoku_tutor/domain/storage/import_export_service.dart';
import 'package:sudoku_tutor/domain/storage/models/mistake_book.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';
import 'package:sudoku_tutor/domain/storage/storage_paths.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 数据分组。
class DataSection extends ConsumerWidget {
  /// 构造分组。
  const DataSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Text(
            context.l10n.text('数据'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: Text(context.l10n.text('导出存档')),
                subtitle: Text(context.l10n.text('桌面选路径 / 移动端分享')),
                onTap: () => _export(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: Text(context.l10n.text('导入存档')),
                subtitle: Text(context.l10n.text('导入前自动备份当前进度')),
                onTap: () => _import(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(context.l10n.text('清空错题本')),
                subtitle: Text(context.l10n.text('删除全部错题记录')),
                onTap: () => _clearMistakes(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined),
                title: Text(context.l10n.text('重置全部进度')),
                subtitle: Text(context.l10n.text('删除所有进度与设置，不可恢复')),
                onTap: () => _resetAll(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(context.l10n.text('导出日志')),
                subtitle: Text(context.l10n.text('崩溃日志（最近 20 条）')),
                onTap: () => _exportLogs(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ 导出

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final ImportExportService service =
        await ref.read(importExportServiceProvider.future);
    final String json = await service.exportJson();
    // 桌面端（Windows）：file_selector 选路径落盘。
    if (!Platform.isAndroid && !Platform.isIOS) {
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: 'sudoku_save.json',
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: l10n.text('JSON 存档'),
            extensions: const <String>['json'],
          ),
        ],
      );
      if (location == null) {
        return; // 用户取消。
      }
      await File(location.path).writeAsString(json, flush: true);
      if (context.mounted) {
        _toast(context, l10n.text('已导出存档'));
      }
      return;
    }
    // 移动端：share_plus 分享文本。
    await Share.share(json, subject: l10n.text('数独教学存档'));
  }

  // ------------------------------------------------------------ 导入

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final ImportExportService service =
        await ref.read(importExportServiceProvider.future);
    if (!context.mounted) {
      return;
    }
    // 二次确认（P0-STO-06）。
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.text('导入存档？')),
        content: Text(
          l10n.text('导入将覆盖当前进度（导入前会自动备份当前存档）。'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.text('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.text('导入')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    // 桌面端：file_selector 选文件。
    if (!Platform.isAndroid && !Platform.isIOS) {
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: l10n.text('JSON 存档'),
            extensions: const <String>['json'],
          ),
        ],
      );
      if (file == null) {
        return;
      }
      final ImportResult result = await service.importFromFile(file.path);
      if (context.mounted) {
        _toast(
          context,
          result.ok
              ? l10n.text('导入成功')
              : l10n.text(
                  '导入失败：{message}',
                  <String, Object?>{
                    'message': l10n.errorMessage(result.message ?? '未知错误'),
                  },
                ),
        );
      }
      if (result.ok) {
        // 导入覆盖了进度 → 设置立即重载，课程状态同步重算。
        ref.invalidate(settingsControllerProvider);
        ref.invalidate(curriculumStateProvider);
      }
      return;
    }
    // 移动端：分享文本输入导入（share_plus 读回原始文本）。
    try {
      final ShareResult result = await Share.share(
        l10n.text('请将「数独教学存档 JSON」粘贴到对话框后确认导入'),
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
      final String raw = result.raw;
      if (raw.isNotEmpty && result.status == ShareResultStatus.success) {
        final ImportResult r = await service.importJsonString(raw);
        if (context.mounted) {
          _toast(
            context,
            r.ok
                ? l10n.text('导入成功')
                : l10n.text(
                    '导入失败：{message}',
                    <String, Object?>{
                      'message': l10n.errorMessage(r.message ?? '未知错误'),
                    },
                  ),
          );
        }
        if (r.ok) {
          // 导入覆盖了进度 → 设置立即重载，课程状态同步重算。
          ref.invalidate(settingsControllerProvider);
          ref.invalidate(curriculumStateProvider);
        }
      }
    } on Object catch (e) {
      if (context.mounted) {
        _toast(
          context,
          l10n.text(
            '移动端导入失败：{error}',
            <String, Object?>{'error': l10n.errorMessage(e)},
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------ 其它

  Future<void> _clearMistakes(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.text('清空错题本？')),
        content: Text(l10n.text('将删除全部错题记录。')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.text('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.text('清空')),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    final ProgressRepository repo =
        await ref.read(progressRepositoryProvider.future);
    final state = await repo.load();
    await repo.save(state.copyWith(mistakeBook: const MistakeBook()));
    if (context.mounted) {
      _toast(context, l10n.text('错题本已清空'));
    }
  }

  Future<void> _resetAll(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.text('重置全部进度？')),
        content: Text(
          l10n.text('将删除全部关卡进度、设置与对局断点，此操作不可恢复。'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.text('取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.text('重置')),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    final ProgressRepository repo =
        await ref.read(progressRepositoryProvider.future);
    await repo.resetAll();
    // 重置后设置恢复默认（刷新设置控制器），且课程进度全部重算（学习地图解锁刷新）。
    ref.invalidate(settingsControllerProvider);
    ref.invalidate(curriculumStateProvider);
    if (context.mounted) {
      _toast(context, l10n.text('已重置全部进度'));
    }
  }

  Future<void> _exportLogs(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    final StoragePaths paths = await StoragePaths.resolve();
    await paths.ensureDirectories();
    final CrashLogService service = CrashLogService(logsDir: paths.logsDir);
    final File logFile = await service.exportLogFile();
    final String text = await logFile.readAsString();
    if (!Platform.isAndroid && !Platform.isIOS) {
      final FileSaveLocation? location = await getSaveLocation(
        suggestedName: 'crash.log',
      );
      if (location == null) {
        return;
      }
      await File(location.path).writeAsString(text, flush: true);
      if (context.mounted) {
        _toast(context, l10n.text('已导出日志'));
      }
      return;
    }
    await Share.share(text, subject: l10n.text('崩溃日志'));
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// 导入导出服务 Provider（复用进度仓储；异步装配）。
final FutureProvider<ImportExportService> importExportServiceProvider =
    FutureProvider<ImportExportService>(
  (Ref ref) async {
    final ProgressRepository repo =
        await ref.watch(progressRepositoryProvider.future);
    return ImportExportService(repository: repo);
  },
);
