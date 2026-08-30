/// 分层约束静态扫描（P0-QA-04 / P0-QA-07，doc 07 T-QA-01）⛔ CI 门禁
///
/// 校验的四条铁律（架构文档 §2.1 / §7.6）：
///   R1 `packages/sudoku_core/lib/**` 禁止 import `package:flutter`、`dart:ui`、
///      `dart:io`、`package:flutter_test`；
///   R2 `packages/sudoku_cli/lib|bin/**` 禁止 import `package:flutter`、`dart:ui`；
///   R3 `app/lib/core/**` 禁止 import `package:flutter`、`dart:ui`
///      （保证 core barrel 是纯算法出口）；
///   R4 `app/lib/domain/**` 禁止 import `package:flutter/material.dart`、
///      `package:flutter/widgets.dart`、`package:flutter/cupertino.dart`
///      与 `app/lib/ui/**`（业务层不得依赖展示层）。
///
/// 另附两条卫生规则：
///   R5 `packages/sudoku_core/lib/**` 禁止直接使用 `print(`（应抛异常或返回结果）；
///   R6 任何包内 `lib/` 下禁止相对路径跨包 import（`../../packages/`）。
///
/// 用法：
///   dart run tools/ci/check_layering.dart            # 在仓库根执行
///   dart run tools/ci/check_layering.dart --root D:\repo
///
/// 退出码：0 = 全部通过；1 = 发现违规（CI 阻断）；2 = 参数或环境错误。
library;

import 'dart:io';

/// 一条分层规则。
class LayerRule {
  /// 构造规则。
  const LayerRule({
    required this.id,
    required this.description,
    required this.includeDirs,
    required this.forbiddenPatterns,
  });

  /// 规则编号，如 `R1`。
  final String id;

  /// 规则说明（中文，用于报错信息）。
  final String description;

  /// 相对仓库根的受检目录列表。
  final List<String> includeDirs;

  /// 命中即违规的正则列表。
  final List<RegExp> forbiddenPatterns;
}

/// 一处违规。
class Violation {
  /// 构造违规记录。
  const Violation({
    required this.rule,
    required this.filePath,
    required this.lineNumber,
    required this.lineText,
  });

  /// 被违反的规则。
  final LayerRule rule;

  /// 文件路径（相对仓库根）。
  final String filePath;

  /// 行号（1 起）。
  final int lineNumber;

  /// 行内容（已 trim）。
  final String lineText;

  @override
  String toString() =>
      '[${rule.id}] $filePath:$lineNumber  $lineText\n        └─ ${rule.description}';
}

/// 全部规则定义。
final List<LayerRule> kRules = <LayerRule>[
  LayerRule(
    id: 'R1',
    description: 'sudoku_core 必须是纯 Dart：禁 flutter / dart:ui / dart:io',
    includeDirs: <String>['packages/sudoku_core/lib'],
    forbiddenPatterns: <RegExp>[
      RegExp(r'''^\s*import\s+['"]package:flutter[/'"]'''),
      RegExp(r'''^\s*import\s+['"]package:flutter_test'''),
      RegExp(r'''^\s*import\s+['"]dart:ui['"]'''),
      RegExp(r'''^\s*import\s+['"]dart:io['"]'''),
    ],
  ),
  LayerRule(
    id: 'R2',
    description: 'sudoku_cli 为纯 Dart CLI：禁 flutter / dart:ui',
    includeDirs: <String>['packages/sudoku_cli/lib', 'packages/sudoku_cli/bin'],
    forbiddenPatterns: <RegExp>[
      RegExp(r'''^\s*import\s+['"]package:flutter[/'"]'''),
      RegExp(r'''^\s*import\s+['"]dart:ui['"]'''),
    ],
  ),
  LayerRule(
    id: 'R3',
    description: 'app/lib/core 是算法层出口 barrel：禁 flutter / dart:ui',
    includeDirs: <String>['app/lib/core'],
    forbiddenPatterns: <RegExp>[
      RegExp(r'''^\s*import\s+['"]package:flutter[/'"]'''),
      RegExp(r'''^\s*import\s+['"]dart:ui['"]'''),
    ],
  ),
  LayerRule(
    id: 'R4',
    description: 'app/lib/domain 是业务层：禁 Flutter Widget 库与 ui 展示层',
    includeDirs: <String>['app/lib/domain'],
    forbiddenPatterns: <RegExp>[
      RegExp(r'''^\s*import\s+['"]package:flutter/material\.dart['"]'''),
      RegExp(r'''^\s*import\s+['"]package:flutter/widgets\.dart['"]'''),
      RegExp(r'''^\s*import\s+['"]package:flutter/cupertino\.dart['"]'''),
      RegExp(r'''^\s*import\s+['"](?:\.\./)+ui/'''),
      RegExp(r'''^\s*import\s+['"]package:sudoku_tutor/ui/'''),
    ],
  ),
  LayerRule(
    id: 'R5',
    description: 'sudoku_core 禁止直接 print（应抛异常或返回结果对象）',
    includeDirs: <String>['packages/sudoku_core/lib'],
    forbiddenPatterns: <RegExp>[RegExp(r'(^|[^\w.])print\s*\(')],
  ),
  LayerRule(
    id: 'R6',
    description: '禁止用相对路径跨包 import（必须走 package: 依赖）',
    includeDirs: <String>[
      'packages/sudoku_core/lib',
      'packages/sudoku_cli/lib',
      'packages/sudoku_cli/bin',
      'app/lib',
    ],
    forbiddenPatterns: <RegExp>[
      RegExp(r'''^\s*import\s+['"](?:\.\./)+packages/'''),
      RegExp(r'''^\s*import\s+['"](?:\.\./)+app/'''),
    ],
  ),
];

/// 入口。
void main(List<String> args) {
  final String root = _parseRoot(args);
  final Directory rootDir = Directory(root);
  if (!rootDir.existsSync()) {
    stderr.writeln('❌ 仓库根目录不存在：$root');
    exit(2);
  }

  final List<Violation> violations = <Violation>[];
  int scannedFiles = 0;
  int scannedDirs = 0;

  for (final LayerRule rule in kRules) {
    for (final String relativeDir in rule.includeDirs) {
      final Directory dir = Directory('$root/$relativeDir');
      if (!dir.existsSync()) {
        // 目录尚未创建（如批次 A 阶段的 app/lib/domain）视为通过，不报错。
        continue;
      }
      scannedDirs++;
      for (final FileSystemEntity entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        scannedFiles++;
        _checkFile(root, entity, rule, violations);
      }
    }
  }

  stdout.writeln('分层门禁扫描完成：$scannedDirs 个受检目录 / $scannedFiles 次文件检查');
  if (violations.isEmpty) {
    stdout.writeln('✅ 分层约束全部通过（R1–R6）');
    exit(0);
  }

  stderr.writeln('❌ 发现 ${violations.length} 处分层违规：');
  for (final Violation violation in violations) {
    stderr.writeln('  $violation');
  }
  exit(1);
}

/// 扫描单个文件。
void _checkFile(
  String root,
  File file,
  LayerRule rule,
  List<Violation> violations,
) {
  final List<String> lines = file.readAsLinesSync();
  final String relativePath =
      file.path.replaceAll('\\', '/').replaceFirst('${root.replaceAll('\\', '/')}/', '');

  for (int i = 0; i < lines.length; i++) {
    final String line = lines[i];
    final String trimmed = line.trimLeft();
    // 跳过注释行（文档里会出现示例 import，不应误判）。
    if (trimmed.startsWith('//') || trimmed.startsWith('///') ||
        trimmed.startsWith('*') || trimmed.startsWith('/*')) {
      continue;
    }
    for (final RegExp pattern in rule.forbiddenPatterns) {
      if (pattern.hasMatch(line)) {
        violations.add(
          Violation(
            rule: rule,
            filePath: relativePath,
            lineNumber: i + 1,
            lineText: line.trim(),
          ),
        );
        break;
      }
    }
  }
}

/// 解析 `--root` 参数，缺省为当前工作目录。
String _parseRoot(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) {
      return args[i + 1].replaceAll('\\', '/');
    }
    if (args[i].startsWith('--root=')) {
      return args[i].substring('--root='.length).replaceAll('\\', '/');
    }
  }
  return Directory.current.path.replaceAll('\\', '/');
}
