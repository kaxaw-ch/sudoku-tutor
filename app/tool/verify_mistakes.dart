/// 校验教学纠错文案的结构与条数。
///
/// 从仓库根目录运行：`dart run app/tool/verify_mistakes.dart`。
library;

import 'dart:convert';
import 'dart:io';

import 'project_paths.dart';

void main() {
  final String root = findProjectRoot();
  final File source = File('$root/app/assets/text/mistakes_zh.json');
  final Map<String, Object?> json =
      jsonDecode(source.readAsStringSync()) as Map<String, Object?>;
  final List<Object?> categories = json['categories']! as List<Object?>;
  int total = 0;

  for (final Object? value in categories) {
    final Map<String, Object?> category = value! as Map<String, Object?>;
    final String id = category['id']! as String;
    final Object? templates = category['templates'];
    if (templates is List<Object?>) {
      total += templates.length;
      stdout.writeln('$id: ${templates.length} 条');
      continue;
    }
    if (templates is Map<String, Object?>) {
      final Map<String, Object?> byTechnique =
          templates['byTechnique']! as Map<String, Object?>;
      final int count = byTechnique.values
          .cast<List<Object?>>()
          .fold(0, (int sum, List<Object?> items) => sum + items.length);
      total += count;
      stdout.writeln('$id: byTechnique ${byTechnique.length} 组，共 $count 条');
      continue;
    }
    stderr.writeln('$id: templates 结构无效');
    exitCode = 1;
    return;
  }

  stdout.writeln('总计: $total 条');
  if (total < 20 || total > 30) {
    stderr.writeln('超出 20–30 条验收范围');
    exitCode = 1;
  } else {
    stdout.writeln('在 20–30 条验收范围内');
  }
}
