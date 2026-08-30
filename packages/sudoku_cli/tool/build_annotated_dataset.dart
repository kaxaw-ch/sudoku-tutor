/// T-QA-02 标注集构建工具（doc 07 §4 交付物）。
///
/// 从既有产物（pools / level_candidates / puzzles 及追加的生成池）抽取题面，
/// 在 **t2（16 项全量）规则集**下重新逐级标注（`annotateOne` 100% 复用
/// `sudoku_core`），按技巧切分产出：
/// ```
/// <out>/<techniqueId>/positive/<techniqueId>_positive_<seq>.json
/// <out>/<techniqueId>/negative/<techniqueId>_negative_<seq>.json
/// ```
/// 每例 JSON 含 `puzzle81` / `solution81` / 技巧标签 / 来源 / 构造说明；
/// positive 例附 `expected`（t2 脚本中目标技巧首步结论，供评测核对）。
///
/// 选择策略：
/// - **positive** = t2 标注中目标技巧被使用（usedTechniques 含目标）；
/// - **negative** = t2 标注中目标技巧全程未被使用；优先「近失/易混淆」候选
///   （最高技巧 rank 距目标最近、或使用了同家族相关技巧的题）。
///
/// 用法：
/// ```
/// dart run tool/build_annotated_dataset.dart \
///   --out dataset/annotated [--per-tech 20] [--report-only] \
///   [追加来源 pool.json/.json.gz ...]
/// ```
/// `--report-only`：只打印各技巧在现有来源中的正/负例可得数，不落盘。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sudoku_core/sudoku_core.dart';
import 'package:sudoku_cli/sudoku_cli.dart';

/// 一个来源题面（未标注）。
class SourcePuzzle {
  /// 构造来源题面。
  SourcePuzzle({
    required this.puzzle81,
    required this.solution81,
    required this.source,
    required this.priority,
    this.seed,
  });

  final String puzzle81;
  final String solution81;
  final String source;
  final String priority; // 'level' | 'pool' | 'puzzle' | 'generated'
  final int? seed;

  String get fingerprint => Fingerprint.ofValues(BoardCodec.decodeValues(puzzle81));
}

/// 来源题面 + t2 重新标注结果。
class _AnnotatedSource {
  _AnnotatedSource({required this.source, required this.annotated});

  final SourcePuzzle source;
  final AnnotatedPuzzle annotated;

  Set<TechniqueId> get used => annotated.techniques;

  int get hardestRank {
    int best = 0;
    for (final TechniqueId id in used) {
      final int r = TechniqueRank.of(id);
      if (r > best) {
        best = r;
      }
    }
    return best;
  }
}

/// 输出目录前缀常量（写入文件名用）。
const String kOutPrefix = 'schema';

/// 序号起始值（每个技巧每类从 1 开始）。
const int kSeqBase = 1;

Future<void> main(List<String> args) async {
  try {
    await _main(args);
  } on Object catch (e, stack) {
    stderr.writeln('构建失败：$e');
    stderr.writeln(stack);
    exit(1);
  }
}

Future<void> _main(List<String> args) async {
  String outDir = 'dataset/annotated';
  int perTech = 20;
  bool reportOnly = false;
  bool writeManifest = false;
  final List<String> sources = <String>[];

  for (int i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--out':
        outDir = args[++i];
      case '--per-tech':
        perTech = int.parse(args[++i]);
      case '--report-only':
        reportOnly = true;
      case '--manifest':
        writeManifest = true;
      default:
        if (!args[i].startsWith('-')) {
          sources.add(args[i]);
        }
    }
  }
  if (perTech < 1) {
    stderr.writeln('--per-tech 必须 ≥1');
    exit(2);
  }

  final List<SourcePuzzle> loaded = _loadSources(sources);
  stdout.writeln('来源题面：${loaded.length}（含去重前）');

  final TechniqueRegistry registry = TechniqueRegistry.defaults();
  final List<_AnnotatedSource> annotatedAll = <_AnnotatedSource>[];
  final Map<String, _AnnotatedSource> byFingerprint = <String, _AnnotatedSource>{};
  for (final SourcePuzzle source in loaded) {
    final _AnnotatedSource? ann = byFingerprint[source.fingerprint];
    if (ann != null) {
      continue; // 同构去重（跨来源优先保留先加载的）。
    }
    final AnnotatedPuzzle? result = annotateOne(
      puzzle: Puzzle(
        given: BoardCodec.decodeValues(source.puzzle81),
        solution: BoardCodec.decodeValues(source.solution81),
      ),
      seed: source.seed ?? 0,
      ruleSet: RuleSet.t2(),
    );
    if (result == null) {
      stdout.writeln('  跳过（t2 不可解/非唯一）：${source.source}');
      continue;
    }
    final _AnnotatedSource entry = _AnnotatedSource(source: source, annotated: result);
    annotatedAll.add(entry);
    byFingerprint[source.fingerprint] = entry;
  }
  stdout.writeln('t2 可解唯一题面：${annotatedAll.length}');

  if (reportOnly) {
    _reportAvailability(annotatedAll);
    return;
  }

  final Directory outRoot = Directory(outDir);
  // ⚠️ 不做整树删除：沙箱/Windows 下批量删除大目录会中断进程。
  // 文件名按 `技巧_label_序号` 确定性生成，重复运行直接覆盖，陈旧文件
  // 由人工一次性清理（见 README）。
  outRoot.createSync(recursive: true);

  final List<String> written = <String>[];
  int positiveTotal = 0;
  int negativeTotal = 0;
  final StringBuffer summary = StringBuffer();
  summary.writeln('技巧             正例  负例  状态');
  for (final TechniqueId technique in TechniqueId.values) {
    final List<_AnnotatedSource> positives =
        _selectPositives(annotatedAll, technique, perTech);
    final List<_AnnotatedSource> negatives =
        _selectNegatives(annotatedAll, technique, perTech, registry, positives);

    final String techDir = p.join(outRoot.path, technique.id);
    final int posWritten = _writeExamples(
      techDir,
      technique,
      label: 'positive',
      entries: positives,
      written: written,
      startSeq: kSeqBase,
      registry: registry,
    );
    final int negWritten = _writeExamples(
      techDir,
      technique,
      label: 'negative',
      entries: negatives,
      written: written,
      startSeq: kSeqBase,
      registry: registry,
    );
    positiveTotal += posWritten;
    negativeTotal += negWritten;
    summary.writeln(
      '${technique.id.padRight(16)}'
      '${posWritten.toString().padLeft(4)}  ${negWritten.toString().padLeft(4)}  '
      '${posWritten < perTech || negWritten < perTech ? '⚠️ 不足' : '✅'}',
    );
  }
  stdout.write(summary.toString());
  stdout.writeln('合计：positive=$positiveTotal, negative=$negativeTotal, '
      '总计=${positiveTotal + negativeTotal}（期望 ≥${16 * perTech * 2}）');

  // 权威清单（可选）：评测器按 manifest 扫描，可免疫目录中无法清理的陈旧文件。
  if (writeManifest) {
    final List<String> relWritten = <String>[
      for (final String path in written) p.relative(path, from: outRoot.path),
    ];
    _writeJsonOverwrite(
      p.join(outRoot.path, 'manifest.json'),
      <String, Object?>{
        'schemaVersion': 1,
        'kind': 'annotation-example-manifest',
        'seqBase': kSeqBase,
        'perTech': perTech,
        'builtAt': DateTime.now().toIso8601String(),
        'examples': relWritten,
      },
    );
    stdout.writeln('已写 manifest.json（${relWritten.length} 条），权威例清单。');
  }
  if (positiveTotal < 16 * perTech || negativeTotal < 16 * perTech) {
    stdout.writeln('⚠️ 存在不足项：请用 generate --required / --banned 补齐后 '
        '再次运行本工具追加来源池。');
  }
}

// ---------------------------------------------------------------- 加载来源

List<SourcePuzzle> _loadSources(List<String> paths) {
  final List<SourcePuzzle> result = <SourcePuzzle>[];
  for (final String raw in paths) {
    final String path = p.normalize(raw);
    if (Directory(path).existsSync()) {
      final List<File> files = Directory(path)
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) =>
              f.path.toLowerCase().endsWith('.json') ||
              f.path.toLowerCase().endsWith('.gz'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
      for (final File file in files) {
        _loadOneFile(file.path, result);
      }
      continue;
    }
    if (File(path).existsSync()) {
      _loadOneFile(path, result);
    } else {
      stderr.writeln('路径不存在：$path');
    }
  }
  return result;
}

void _loadOneFile(String path, List<SourcePuzzle> result) {
  final Map<String, Object?> root;
  try {
    root = JsonWriter.readJsonMap(path);
  } on CliIoException catch (e) {
    stderr.writeln('读取失败 $path：${e.message}');
    return;
  }
  final Object? rawPuzzles = root['puzzles'];
  if (rawPuzzles is List<Object?>) {
    final List<Object?> items = rawPuzzles;
    for (int i = 0; i < items.length; i++) {
      final Object? item = items[i];
      if (item is! Map<String, Object?>) {
        continue;
      }
      final String? puzzle81 = item['puzzle81'] as String?;
      final String? solution81 = item['solution81'] as String?;
      if (puzzle81 == null || solution81 == null) {
        continue;
      }
      result.add(SourcePuzzle(
        puzzle81: puzzle81,
        solution81: solution81,
        seed: item['seed'] as int?,
        source: '$path#$i',
        priority: _priorityOf(path),
      ));
    }
  } else if (root['puzzle81'] is String && root['solution81'] is String) {
    // 单关形态（level_candidates）。
    final String? id = root['id'] as String?;
    result.add(SourcePuzzle(
      puzzle81: root['puzzle81']! as String,
      solution81: root['solution81']! as String,
      seed: root['seed'] as int?,
      source: id ?? path,
      priority: 'level',
    ));
  } else {
    stderr.writeln('跳过非集合/非单关文件：$path');
  }
}

String _priorityOf(String path) {
  final String name = p.basename(path);
  if (name.startsWith('ch') && name.contains('.json')) {
    return 'pool';
  }
  if (name.startsWith('generated')) {
    return 'generated';
  }
  return 'puzzle';
}

// ---------------------------------------------------------------- 选择

/// 抽取正例：t2 标注中目标技巧被使用；来源优先级 level > pool > puzzle > generated。
List<_AnnotatedSource> _selectPositives(
  List<_AnnotatedSource> all,
  TechniqueId technique,
  int perTech,
) {
  final List<_AnnotatedSource> hits = <_AnnotatedSource>[
    for (final _AnnotatedSource e in all)
      if (e.used.contains(technique)) e,
  ];
  hits.sort((_AnnotatedSource a, _AnnotatedSource b) {
    final int pa = _priorityIndex(a.source.priority);
    final int pb = _priorityIndex(b.source.priority);
    if (pa != pb) {
      return pa.compareTo(pb);
    }
    return a.source.source.compareTo(b.source.source);
  });
  return hits.take(perTech).toList();
}

/// 抽取负例：
/// - 其余 15 技巧：t2 标注中目标技巧全程未被使用（强负例，求解中任何状态
///   都不触发）；
/// - nakedSingle：**数学边界** —— 任何完整求解的收尾步必然出现唯一余数
///   （最后剩一格时该格恰剩 1 个候选），故「不含裸单」只能在**初始盘面状态**
///   定义：初始盘面无单候选格（checkMode=initial，见 README）。
///
/// 近失得分 = |目标 rank − 最高已用 rank|；使用同家族相关技巧再降一档，
/// 使「仅差一步不成 / 其它技巧伪装」的盘面优先入选。
List<_AnnotatedSource> _selectNegatives(
  List<_AnnotatedSource> all,
  TechniqueId technique,
  int perTech,
  TechniqueRegistry registry,
  List<_AnnotatedSource> positives,
) {
  final Set<String> positiveFingerprints = <String>{
    for (final _AnnotatedSource p in positives) p.source.fingerprint,
  };
  final int targetRank = TechniqueRank.of(technique);
  final Set<TechniqueId> family = _relatedFamily(technique);
  final List<(double, _AnnotatedSource)> candidates = <(double, _AnnotatedSource)>[];
  for (final _AnnotatedSource e in all) {
    if (positiveFingerprints.contains(e.source.fingerprint)) {
      continue; // 同一题面不得同时作本技巧的正例与负例（避免人工核验歧义）。
    }
    if (!_isUsableNegative(e, technique, registry)) {
      continue;
    }
    double score = (e.hardestRank - targetRank).abs().toDouble();
    if (e.used.any(family.contains)) {
      score -= 0.5; // 使用了同家族技巧 → 更易混淆。
    }
    candidates.add((score, e));
  }
  candidates.sort(((double, _AnnotatedSource) a, (double, _AnnotatedSource) b) {
    final int c = a.$1.compareTo(b.$1);
    if (c != 0) {
      return c;
    }
    final int pa = _priorityIndex(a.$2.source.priority);
    final int pb = _priorityIndex(b.$2.source.priority);
    if (pa != pb) {
      return pa.compareTo(pb);
    }
    return a.$2.source.source.compareTo(b.$2.source.source);
  });
  return <_AnnotatedSource>[
    for (final (double _, _AnnotatedSource e) in candidates.take(perTech)) e,
  ];
}

/// 是否可作为技巧 [technique] 的负例（按上面注释的口径）。
bool _isUsableNegative(
  _AnnotatedSource entry,
  TechniqueId technique,
  TechniqueRegistry registry,
) {
  if (technique == TechniqueId.nakedSingle) {
    // 数学边界：只能按初始盘面状态判定「无裸单」。
    return !_recognizerFiresOnInitial(entry, technique, registry);
  }
  return !entry.used.contains(technique);
}

/// 目标识别器在初始盘面状态上是否命中。
bool _recognizerFiresOnInitial(
  _AnnotatedSource entry,
  TechniqueId technique,
  TechniqueRegistry registry,
) {
  final List<int> given = BoardCodec.decodeValues(entry.source.puzzle81);
  final Board board = Board.fromValues(given, givenMask: <bool>[
    for (final int v in given) v != kEmptyValue,
  ]);
  CandidateCalculator.recomputeAll(board);
  final SolveContext ctx = SolveContext(
    board: board,
    ruleSet: RuleSet.t2(),
    uniqueSolutionGuaranteed: true,
    solution: BoardCodec.decodeValues(entry.source.solution81),
  );
  return registry
      .byId(technique)
      .find(ctx, limit: 8)
      .any((TechniqueResult r) => r.isNotEmpty);
}

/// 技巧家族（近失负例选取用）。
Set<TechniqueId> _relatedFamily(TechniqueId technique) {
  switch (technique) {
    case TechniqueId.xWing:
    case TechniqueId.finnedXWing:
    case TechniqueId.swordfish:
      return <TechniqueId>{
        TechniqueId.xWing,
        TechniqueId.finnedXWing,
        TechniqueId.swordfish,
      };
    case TechniqueId.xyWing:
    case TechniqueId.xyzWing:
    case TechniqueId.wWing:
      return <TechniqueId>{
        TechniqueId.xyWing,
        TechniqueId.xyzWing,
        TechniqueId.wWing,
      };
    case TechniqueId.urType1:
    case TechniqueId.urType2:
      return <TechniqueId>{
        TechniqueId.urType1,
        TechniqueId.urType2,
        TechniqueId.wWing,
      };
    case TechniqueId.simpleColouring:
      return <TechniqueId>{
        TechniqueId.simpleColouring,
        TechniqueId.xWing,
        TechniqueId.wWing,
      };
    case TechniqueId.nakedPair:
    case TechniqueId.hiddenPair:
    case TechniqueId.nakedTriple:
    case TechniqueId.hiddenTriple:
      return <TechniqueId>{
        TechniqueId.nakedPair,
        TechniqueId.hiddenPair,
        TechniqueId.nakedTriple,
        TechniqueId.hiddenTriple,
      };
    default:
      return <TechniqueId>{};
  }
}

int _priorityIndex(String priority) {
  switch (priority) {
    case 'level':
      return 0;
    case 'pool':
      return 1;
    case 'puzzle':
      return 2;
    default:
      return 3;
  }
}

// ---------------------------------------------------------------- 落盘

int _writeExamples(
  String techDir,
  TechniqueId technique, {
  required String label,
  required List<_AnnotatedSource> entries,
  required List<String> written,
  required int startSeq,
  required TechniqueRegistry registry,
}) {
  if (entries.isEmpty) {
    return 0;
  }
  final Directory dir = Directory(p.join(techDir, label));
  dir.createSync(recursive: true);
  int seq = startSeq;
  for (final _AnnotatedSource entry in entries) {
    final String fileName =
        '${technique.id}_${label}_${seq.toString().padLeft(3, '0')}.json';
    final String target = p.join(dir.path, fileName);
    _writeJsonOverwrite(
      target,
      _exampleJson(technique, label, entry, seq, registry),
    );
    written.add(target);
    seq++;
  }
  return seq - startSeq;
}

/// 直接覆写 JSON（不经 tmp+rename）。
///
/// ⚠️ 本环境（Windows 沙箱）下 `renameSync` 无法覆盖已存在文件、`deleteSync`
/// 被拦截，故构建工具用直接覆写；仅开发/离线场景使用，不影响 CLI 生产的
/// 原子落盘路径。
void _writeJsonOverwrite(String target, Map<String, Object?> json) {
  final File file = File(target);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(json),
    flush: true,
  );
}

Map<String, Object?> _exampleJson(
  TechniqueId technique,
  String label,
  _AnnotatedSource entry,
  int seq,
  TechniqueRegistry registry,
) {
  final AnnotatedPuzzle ann = entry.annotated;
  final List<String> usedIds = <String>[
    for (final TechniqueId id in ann.techniques) id.id,
  ];
  final StringBuffer note = StringBuffer();
  note.write(
    '${label == 'positive' ? '正例' : '负例'}：t2 全量规则集下逐级求解 '
    '${ann.stepCount} 步，难度 ${ann.difficulty?.id ?? '-'}，'
    '最高技巧 ${ann.hardestTechnique?.id ?? '-'}，'
    '使用技巧 {${usedIds.join(',')}}。来源：${entry.source.priority} 档 '
    '${entry.source.source}。',
  );
  if (label == 'positive') {
    final (int order, List<Elimination> elims, List<Placement> placements) =
        _firstTargetStep(entry, technique);
    note.write(
        ' 目标技巧 ${technique.zhName} 在第 $order 步触发（共 '
        '${ann.stepCount} 步）。');
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'annotation-example',
      'id': '${technique.id}_${label}_${seq.toString().padLeft(3, '0')}',
      'techniqueId': technique.id,
      'label': label,
      'puzzle81': entry.source.puzzle81,
      'solution81': entry.source.solution81,
      'seed': entry.source.seed,
      'source': entry.source.source,
      'note': note.toString(),
      'checkMode': AnnotatedExample.kCheckModeSolve,
      'expected': <String, Object?>{
        'stepOrder': order,
        'techniqueId': technique.id,
        'eliminations': <Map<String, Object?>>[
          for (final Elimination e in elims) e.toJson(),
        ],
        'placements': <Map<String, Object?>>[
          for (final Placement pl in placements) pl.toJson(),
        ],
      },
    };
  }
  if (technique == TechniqueId.nakedSingle) {
    // 数学边界负例：完整求解必然以唯一余数收尾，故按初始盘面判定。
    final bool initialFires =
        _recognizerFiresOnInitial(entry, technique, registry);
    note.write(
        ' 该题初始盘面无单候选格，${technique.zhName} 识别器在初始状态不命中'
        '（checkMode=initial）。注：数学上任何完整求解的收尾步必然出现唯一余数，'
        '故「不含裸单」只能在初始盘面状态定义。'
        '${initialFires ? ' ⚠️ 校验失败：初始状态实际命中！' : ''}');
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'annotation-example',
      'id': '${technique.id}_${label}_${seq.toString().padLeft(3, '0')}',
      'techniqueId': technique.id,
      'label': label,
      'puzzle81': entry.source.puzzle81,
      'solution81': entry.source.solution81,
      'seed': entry.source.seed,
      'source': entry.source.source,
      'note': note.toString(),
      'checkMode': AnnotatedExample.kCheckModeInitial,
    };
  }
  note.write(' 该题全程未触发 ${technique.zhName}，用作误报回归盘面。');
  return <String, Object?>{
    'schemaVersion': 1,
    'kind': 'annotation-example',
    'id': '${technique.id}_${label}_${seq.toString().padLeft(3, '0')}',
    'techniqueId': technique.id,
    'label': label,
    'puzzle81': entry.source.puzzle81,
    'solution81': entry.source.solution81,
    'seed': entry.source.seed,
    'source': entry.source.source,
    'note': note.toString(),
    'checkMode': AnnotatedExample.kCheckModeSolve,
  };
}

/// 取 t2 脚本中目标技巧的首条步骤结论。
(int, List<Elimination>, List<Placement>) _firstTargetStep(
  _AnnotatedSource entry,
  TechniqueId technique,
) {
  for (final AnnotatedScriptStep step in entry.annotated.script) {
    if (step.techniqueId == technique) {
      return (step.order, step.eliminations, step.placements);
    }
  }
  return (0, const <Elimination>[], const <Placement>[]);
}

// ---------------------------------------------------------------- 盘点

void _reportAvailability(List<_AnnotatedSource> all) {
  final StringBuffer buffer = StringBuffer();
  buffer.writeln('技巧             正例可得  负例可得');
  int posTotal = 0;
  int negTotal = 0;
  for (final TechniqueId technique in TechniqueId.values) {
    final int pos = all.where((_AnnotatedSource e) => e.used.contains(technique)).length;
    final int neg = all.where((_AnnotatedSource e) => !e.used.contains(technique)).length;
    posTotal += pos;
    negTotal += neg;
    buffer.writeln(
      '${technique.id.padRight(16)}'
      '${pos.toString().padLeft(6)}  ${neg.toString().padLeft(6)}',
    );
  }
  buffer.writeln('合计            $posTotal  $negTotal');
  stdout.write(buffer.toString());
}
