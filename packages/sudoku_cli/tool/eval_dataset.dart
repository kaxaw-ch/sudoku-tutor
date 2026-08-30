/// T-QA-02 标注集精确率/召回率评测入口。
///
/// 用法:
/// ```
/// dart run tool/eval_dataset.dart [--dataset <dir>]
/// ```
/// 默认扫描 `dataset/annotated_v4`（T-QA-02 规范交付物；`dataset/annotated`
/// 目录为早期遗留，因沙箱写一次锁定无法清理）。
/// 退出码：0 = 全过（Precision 100% 且 Recall≥95% 且无异常）；1 = 未过。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sudoku_cli/sudoku_cli.dart';

Future<void> main(List<String> args) async {
  String dataset = 'dataset/annotated_v4';
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--dataset' && i + 1 < args.length) {
      dataset = args[i + 1];
      i++;
    } else if (!args[i].startsWith('-')) {
      dataset = args[i];
    }
  }
  dataset = _resolveDatasetDir(dataset);

  final DatasetEvaluation evaluation;
  try {
    evaluation = DatasetEvaluator().evaluate(dataset);
  } on DatasetEvalException catch (e) {
    stderr.writeln('评测失败：${e.message}');
    exit(2);
  }

  stdout.write(evaluation.renderReport());
  if (evaluation.verdicts.any((ExampleVerdict v) => !_ok(v))) {
    stdout.writeln('');
    stdout.writeln('---- 逐例问题清单 ----');
    stdout.write(evaluation.renderFailures());
  }
  stdout.writeln('');
  exit(evaluation.passes ? 0 : 1);
}

bool _ok(ExampleVerdict v) {
  if (v.isInvalid) {
    return false;
  }
  if (v.example.isPositive) {
    return v.outcome && v.conclusionOk;
  }
  return !v.outcome;
}

/// 解析数据集目录：绝对路径直接用；相对路径先在 CWD 下找，再沿父目录
/// 向上搜索（兼容「在 packages/sudoku_cli 目录运行」时定位项目根）。
String _resolveDatasetDir(String path) {
  if (Directory(path).existsSync()) {
    return path;
  }
  Directory? dir = Directory.current;
  for (int i = 0; i < 6 && dir != null; i++) {
    final String candidate =
        p.normalize(p.join(dir.path, path));
    if (Directory(candidate).existsSync()) {
      return candidate;
    }
    dir = dir.parent;
  }
  return path;
}
