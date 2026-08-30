/// 标注集独立一致性检查（T-QA-02 增强核验）：
/// 1. 全数据集指纹去重（同一题面不得在同一 技巧+标签 内重复出现）；
/// 2. 同一技巧下同一指纹不得同时出现在 positive 与 negative（正负冲突）；
/// 3. 例文件结构可解析。
///
/// 注：**跨技巧**复用同一题面（如 xyWing 正例同时作 xyzWing 负例）是
/// 「其它技巧伪装」负例的设计特性，**不算**冲突。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sudoku_core/sudoku_core.dart';
import 'package:sudoku_cli/sudoku_cli.dart';

/// 解析目录路径：绝对路径直接用；相对路径先在 CWD 下找，再沿父目录向上搜索
/// （兼容「在 packages/sudoku_cli 目录运行」时定位项目根）。
Directory _resolveDir(String path) {
  if (Directory(path).existsSync()) {
    return Directory(path);
  }
  Directory? dir = Directory.current;
  for (int i = 0; i < 6 && dir != null; i++) {
    final String candidate = p.normalize(p.join(dir.path, path));
    if (Directory(candidate).existsSync()) {
      return Directory(candidate);
    }
    dir = dir.parent;
  }
  return Directory(path);
}

void main(List<String> args) {
  final String dir = args.isNotEmpty ? args[0] : 'dataset/annotated_v4';
  final Directory root = _resolveDir(dir);
  if (!root.existsSync()) {
    stderr.writeln('目录不存在：$dir');
    exit(2);
  }
  final Map<String, Set<String>> fingerprintToLabels = <String, Set<String>>{};
  int total = 0;
  int invalid = 0;
  final List<String> issues = <String>[];

  for (final File file in root
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.json'))) {
    total++;
    final AnnotatedExample example;
    try {
      example = AnnotatedExample.load(file.path);
    } on FormatException catch (e) {
      invalid++;
      issues.add('[解析失败] ${file.path}：$e');
      continue;
    }
    final String fp =
        Fingerprint.ofValues(BoardCodec.decodeValues(example.puzzle81));
    final Set<String> labels =
        fingerprintToLabels[fp] ??= <String>{};
    final String label = '${example.techniqueId.id}/${example.label}';
    if (!labels.add(label)) {
      issues.add('[同格重复] $label：同一题面在同一 技巧+标签 内出现两次');
    }
  }

  // 同一技巧正负互斥。
  for (final MapEntry<String, Set<String>> e in fingerprintToLabels.entries) {
    for (final String tech in <String>{
      for (final String label in e.value) label.split('/').first,
    }) {
      if (e.value.contains('$tech/positive') &&
          e.value.contains('$tech/negative')) {
        issues.add('[正负冲突] $tech：同一题面既是 positive 又是 negative');
      }
    }
  }

  stdout.writeln('总例数=$total，唯一指纹=${fingerprintToLabels.length}，'
      '解析失败=$invalid，问题数=${issues.length}');
  if (issues.isNotEmpty) {
    for (final String issue in issues) {
      stdout.writeln('  $issue');
    }
  } else {
    stdout.writeln('全部一致 ✅（无同格重复、无正负冲突、无解析失败）');
  }
}
