/// Shared project-path discovery for scripts under `app/tool`.
///
/// Tools may be launched from either the repository root or `app/`. An
/// explicit `PROJECT_ROOT` environment variable takes precedence; otherwise
/// the current directory and its parents are searched for the repository
/// markers used by this project.
library;

import 'dart:io';

/// Returns the absolute repository root without depending on a developer's
/// local checkout path.
String findProjectRoot() {
  final String? override = Platform.environment['PROJECT_ROOT'];
  if (override != null && override.trim().isNotEmpty) {
    final Directory root = Directory(override.trim()).absolute;
    _validateProjectRoot(root);
    return root.path;
  }

  Directory cursor = Directory.current.absolute;
  while (true) {
    if (_isProjectRoot(cursor)) {
      return cursor.path;
    }
    final Directory parent = cursor.parent;
    if (parent.path == cursor.path) {
      throw StateError(
        '无法定位项目根目录；请从仓库内运行，或设置 PROJECT_ROOT。',
      );
    }
    cursor = parent;
  }
}

bool _isProjectRoot(Directory directory) {
  final String separator = Platform.pathSeparator;
  return File('${directory.path}${separator}app${separator}pubspec.yaml')
          .existsSync() &&
      File(
        '${directory.path}${separator}packages${separator}sudoku_core'
        '${separator}pubspec.yaml',
      ).existsSync();
}

void _validateProjectRoot(Directory directory) {
  if (!_isProjectRoot(directory)) {
    throw StateError(
      'PROJECT_ROOT 不是有效的项目根目录：${directory.path}',
    );
  }
}
