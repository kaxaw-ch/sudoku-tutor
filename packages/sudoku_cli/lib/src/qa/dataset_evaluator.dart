/// T-QA-02 标注集评测器（doc 07 §4：标注盘面集 + 精确率/召回率评测）。
///
/// 评测对象：`dataset/annotated/<techniqueId>/{positive,negative}/*.json`。
///
/// ## 评测口径（与 doc 07 T-QA-02 对齐）
/// - 每例 JSON 携带 `puzzle81` / `solution81` / `label` / `techniqueId`；
///   可选 `expected`（positive 例的目标技巧结论，含删数/填数）；
///   可选 `checkMode`：
///   - `solve`（默认）：命中 = 目标技巧在 **t2 全量规则集逐级求解**中被触发
///     （usedTechniques 含目标，且 expected 结论被对应技巧步骤确认）；
///   - `initial`：命中 = 目标技巧识别器在**初始盘面状态**上直接触发
///     （用于 nakedSingle 边界负例：任何完整求解的收尾步必然出现唯一余数，
///     故「不含裸单」只能在初始盘面定义，见 README）；
/// - **positive**：按 `solve` 判定；未被触发 → FN；触发但结论不符 → 结论错误
///   （按 precision/recall 双失败计）；
/// - **negative**：按 `checkMode` 判定；被命中 → FP；
/// - Precision = TP / (TP + FP + 结论错误)，**零容忍必须 100%**；
///   Recall = TP / (TP + FN + 结论错误)，**必须 ≥ 95%**。
///
/// 不修改任何文件；`--dataset` 目录不存在/无可读例时抛 [DatasetEvalException]。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sudoku_core/sudoku_core.dart';

import '../io/json_writer.dart';
import '../model/annotated_puzzle.dart';
import '../pipeline/generation_pipeline.dart';

/// 评测期异常（目录缺失 / 例文件结构非法等）。
class DatasetEvalException implements Exception {
  /// 构造异常。
  DatasetEvalException(this.message);

  /// 可读信息。
  final String message;

  @override
  String toString() => 'DatasetEvalException($message)';
}

/// 一个标注例的判定结果。
class ExampleVerdict {
  /// 构造判定。
  ExampleVerdict({
    required this.example,
    required this.outcome,
    this.conclusionOk = true,
    this.invalidReason,
  });

  /// 对应的标注例。
  final AnnotatedExample example;

  /// 识别器是否在求解中触发了目标技巧。
  final bool outcome;

  /// `true` 时 expected 结论被确认（positive 例专用；无 expected 视为通过）。
  final bool conclusionOk;

  /// 例文件本身异常（结构/求解失败）时的说明；正常为 `null`。
  final String? invalidReason;

  /// 是否结构/求解异常。
  bool get isInvalid => invalidReason != null;
}

/// 单个标注例（`dataset/annotated/.../*.json` 的解析模型）。
class AnnotatedExample {
  /// 构造标注例。
  AnnotatedExample({
    required this.path,
    required this.id,
    required this.techniqueId,
    required this.label,
    required this.puzzle81,
    required this.solution81,
    this.seed,
    this.source,
    this.note,
    this.checkMode = kCheckModeSolve,
    this.expectedEliminations = const <Elimination>[],
    this.expectedPlacements = const <Placement>[],
  });

  /// 判定模式：`solve`（逐级求解全程）。
  static const String kCheckModeSolve = 'solve';

  /// 判定模式：`initial`（初始盘面状态直接扫描）。
  static const String kCheckModeInitial = 'initial';

  /// 文件绝对路径。
  final String path;

  /// 例标识（文件名去扩展）。
  final String id;

  /// 目标技巧。
  final TechniqueId techniqueId;

  /// 标注标签：`positive` / `negative`。
  final String label;

  /// 是否 positive 例。
  bool get isPositive => label == 'positive';

  /// 是否 negative 例。
  bool get isNegative => label == 'negative';

  /// 题面 81 字符串（空格用 `.`）。
  final String puzzle81;

  /// 终局解 81 字符串。
  final String solution81;

  /// 随机种子（可复现；来自来源题池）。
  final int? seed;

  /// 来源说明（如 `pool:app/assets/pools/ch1.json.gz#42`）。
  final String? source;

  /// 构造说明（人工可核验）。
  final String? note;

  /// 命中判定模式（`solve` / `initial`）。
  final String checkMode;

  /// 是否按初始盘面状态判定。
  bool get isInitialCheck => checkMode == kCheckModeInitial;

  /// 期望删数结论（positive 例；来自 t2 标注脚本首条目标技巧步骤）。
  final List<Elimination> expectedEliminations;

  /// 期望填数结论（positive 例）。
  final List<Placement> expectedPlacements;

  /// 由 JSON map 解析；结构非法抛 [FormatException]。
  factory AnnotatedExample.fromJson(String path, Map<String, Object?> json) {
    final Object? rawTechnique = json['techniqueId'];
    final Object? rawLabel = json['label'];
    final Object? rawPuzzle = json['puzzle81'];
    final Object? rawSolution = json['solution81'];
    if (rawTechnique is! String ||
        rawLabel is! String ||
        rawPuzzle is! String ||
        rawSolution is! String) {
      throw const FormatException('缺少 techniqueId/label/puzzle81/solution81 字段');
    }
    final TechniqueId? technique = TechniqueId.tryParse(rawTechnique);
    if (technique == null) {
      throw FormatException('未知技巧 id「$rawTechnique」');
    }
    if (rawLabel != 'positive' && rawLabel != 'negative') {
      throw FormatException('label 必须为 positive/negative，实际「$rawLabel」');
    }

    final Map<String, Object?>? expected =
        json['expected'] as Map<String, Object?>?;
    final String checkMode = (json['checkMode'] as String?) ?? kCheckModeSolve;
    if (checkMode != kCheckModeSolve && checkMode != kCheckModeInitial) {
      throw FormatException('checkMode 必须为 solve/initial，实际「$checkMode」');
    }
    return AnnotatedExample(
      path: path,
      id: p.basenameWithoutExtension(path),
      techniqueId: technique,
      label: rawLabel,
      puzzle81: rawPuzzle,
      solution81: rawSolution,
      seed: json['seed'] as int?,
      source: json['source'] as String?,
      note: json['note'] as String?,
      checkMode: checkMode,
      expectedEliminations: <Elimination>[
        for (final Object? item
            in (expected?['eliminations'] as List<Object?>?) ?? const <Object?>[])
          Elimination.fromJson(item! as Map<String, Object?>),
      ],
      expectedPlacements: <Placement>[
        for (final Object? item
            in (expected?['placements'] as List<Object?>?) ?? const <Object?>[])
          Placement.fromJson(item! as Map<String, Object?>),
      ],
    );
  }

  /// 读取并解析一个例文件。
  static AnnotatedExample load(String path) {
    final Map<String, Object?> root;
    try {
      root = JsonWriter.readJsonMap(path);
    } on CliIoException catch (e) {
      throw FormatException('读取失败：${e.message}');
    }
    return AnnotatedExample.fromJson(path, root);
  }

  @override
  String toString() => '$id($label,${techniqueId.id})';
}

/// 单技巧评测指标（逐技巧累加）。
class TechniqueEvalMetrics {
  /// 构造指标。
  TechniqueEvalMetrics(this.techniqueId);

  /// 目标技巧。
  final TechniqueId techniqueId;

  /// positive 例数。
  int positiveCount = 0;

  /// negative 例数。
  int negativeCount = 0;

  /// 真阳（positive 命中且结论正确）。
  int truePositive = 0;

  /// 假阴（positive 未命中）。
  int falseNegative = 0;

  /// 假阳（negative 被命中）。
  int falsePositive = 0;

  /// 命中但结论错误（positive，识别器判定与 expected 不符）。
  int wrongConclusion = 0;

  /// 结构/求解异常数。
  int invalid = 0;

  /// 判定总数（识别器输出「命中」的例）。
  int get detections => truePositive + falsePositive + wrongConclusion;

  /// positive 总数。
  int get totalPositive => truePositive + falseNegative + wrongConclusion;

  /// 精确率：TP / 全部判定。无判定视为 100%（空集恒真）。
  double get precision =>
      detections == 0 ? 1.0 : truePositive / detections;

  /// 召回率：TP / 全部 positive。无 positive 视为 100%（空集恒真）。
  double get recall =>
      totalPositive == 0 ? 1.0 : truePositive / totalPositive;

  /// 精确率是否 100%（零容忍）。
  bool get precisionIsPerfect => precision == 1.0;

  /// 召回率是否 ≥95%。
  bool get recallSatisfied => recall >= 0.95;

  /// 是否通过（无异常 + precision 100% + recall ≥95%）。
  bool get passes =>
      invalid == 0 && precisionIsPerfect && recallSatisfied;
}

/// 全数据集评测结果。
class DatasetEvaluation {
  /// 构造结果。
  DatasetEvaluation({
    required this.totalExamples,
    required this.byTechnique,
    required List<ExampleVerdict> verdicts,
  }) : verdicts = List<ExampleVerdict>.unmodifiable(verdicts);

  /// 处理的例文件总数。
  final int totalExamples;

  /// 逐技巧指标（按 rank 升序）。
  final Map<TechniqueId, TechniqueEvalMetrics> byTechnique;

  /// 逐例判定（含异常例）。
  final List<ExampleVerdict> verdicts;

  /// 汇总指标。
  TechniqueEvalMetrics get overall {
    final TechniqueEvalMetrics m = TechniqueEvalMetrics(TechniqueId.nakedSingle);
    for (final TechniqueEvalMetrics t in byTechnique.values) {
      m.positiveCount += t.positiveCount;
      m.negativeCount += t.negativeCount;
      m.truePositive += t.truePositive;
      m.falseNegative += t.falseNegative;
      m.falsePositive += t.falsePositive;
      m.wrongConclusion += t.wrongConclusion;
      m.invalid += t.invalid;
    }
    return m;
  }

  /// 是否全部技巧通过（P0-QA-02/06 出口硬门槛）。
  bool get passes {
    if (byTechnique.isEmpty) {
      return false;
    }
    for (final TechniqueEvalMetrics m in byTechnique.values) {
      if (!m.passes) {
        return false;
      }
    }
    return true;
  }

  /// 输出人类可读报表。
  String renderReport() {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('==== T-QA-02 标注集精确率/召回率评测 ====');
    buffer.writeln('评测规则集：t2（16 项全量）· 例数：$totalExamples');
    buffer.writeln('');
    buffer.writeln('技巧           正例 负例  TP   FN   FP  结论错 异常  Precision  Recall  判定');
    for (final TechniqueEvalMetrics m in byTechnique.values) {
      buffer.writeln(
        _row(
          m.techniqueId.id.padRight(16),
          m.positiveCount,
          m.negativeCount,
          m.truePositive,
          m.falseNegative,
          m.falsePositive,
          m.wrongConclusion,
          m.invalid,
          m.precision,
          m.recall,
          m.passes ? '✅' : '❌',
        ),
      );
    }
    final TechniqueEvalMetrics all = overall;
    buffer.writeln(_row(
      '总体'.padRight(16),
      all.positiveCount,
      all.negativeCount,
      all.truePositive,
      all.falseNegative,
      all.falsePositive,
      all.wrongConclusion,
      all.invalid,
      all.precision,
      all.recall,
      passes ? '✅' : '❌',
    ));
    buffer.writeln('');
    buffer.writeln('门槛：Precision=100%（零容忍）· Recall≥95% · 异常=0');
    buffer.writeln('结论：${passes ? '通过 ✅' : '不通过 ❌（详见逐例清单）'}');
    return buffer.toString();
  }

  static String _row(
    String name,
    int pos,
    int neg,
    int tp,
    int fn,
    int fp,
    int wc,
    int invalid,
    double precision,
    double recall,
    String verdict,
  ) {
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    return '$name'
        '${pos.toString().padLeft(4)} ${neg.toString().padLeft(4)} '
        '${tp.toString().padLeft(3)} ${fn.toString().padLeft(3)} '
        '${fp.toString().padLeft(3)} ${wc.toString().padLeft(4)} '
        '${invalid.toString().padLeft(3)} '
        '${pct(precision).padLeft(10)} ${pct(recall).padLeft(8)}  $verdict';
  }

  /// 逐例问题清单（仅失败/异常例），供诊断。
  String renderFailures() {
    final StringBuffer buffer = StringBuffer();
    final List<ExampleVerdict> bad = <ExampleVerdict>[
      for (final ExampleVerdict v in verdicts)
        if (!_verdictOk(v)) v,
    ];
    if (bad.isEmpty) {
      buffer.writeln('（无失败/异常例）');
      return buffer.toString();
    }
    for (final ExampleVerdict v in bad) {
      if (v.isInvalid) {
        buffer.writeln('[异常] ${v.example.path}：${v.invalidReason}');
      } else if (v.example.isPositive) {
        if (!v.outcome) {
          buffer.writeln('[漏报] ${v.example.path}：positive 但目标技巧未触发');
        } else if (!v.conclusionOk) {
          buffer.writeln(
              '[结论错] ${v.example.path}：触发但 expected 结论未被确认');
        }
      } else if (v.outcome) {
        buffer.writeln('[误报] ${v.example.path}：negative 但目标技巧被触发');
      }
    }
    return buffer.toString();
  }

  static bool _verdictOk(ExampleVerdict v) {
    if (v.isInvalid) {
      return false;
    }
    if (v.example.isPositive) {
      return v.outcome && v.conclusionOk;
    }
    return !v.outcome;
  }
}

/// 标注集评测器。
class DatasetEvaluator {
  /// 构造评测器；[registry] 省略时用 16 项全量默认注册表。
  DatasetEvaluator({TechniqueRegistry? registry})
      : registry = registry ?? TechniqueRegistry.defaults();

  /// 评测用的识别器注册表。
  final TechniqueRegistry registry;

  /// 扫描 [dir]（递归）并评测全部标注例。
  ///
  /// 目录结构约定：`<dir>/<techniqueId>/positive|negative/*.json`；
  /// 若 `<dir>/manifest.json` 存在则只评测 manifest 列出的例文件
  /// （权威清单，免疫目录中无法清理的陈旧文件）；否则全量扫描。
  DatasetEvaluation evaluate(String dir) {
    final Directory root = Directory(dir);
    if (!root.existsSync()) {
      throw DatasetEvalException('评测目录不存在：$dir');
    }
    final List<File> files = _resolveExampleFiles(root);
    if (files.isEmpty) {
      throw DatasetEvalException('目录下没有 .json 例文件：$dir');
    }

    final Map<TechniqueId, TechniqueEvalMetrics> metrics = <TechniqueId, TechniqueEvalMetrics>{
      for (final TechniqueId id in TechniqueId.values) id: TechniqueEvalMetrics(id),
    };
    final List<ExampleVerdict> verdicts = <ExampleVerdict>[];

    for (final File file in files) {
      final AnnotatedExample example;
      try {
        example = AnnotatedExample.load(file.path);
      } on FormatException catch (e) {
        final TechniqueEvalMetrics m = _metricsForUnknown(metrics, file.path);
        m.invalid++;
        verdicts.add(ExampleVerdict(
          example: _placeholder(file.path),
          outcome: false,
          invalidReason: '解析失败：$e',
        ));
        continue;
      }
      final TechniqueEvalMetrics m = metrics[example.techniqueId]!;
      if (example.isPositive) {
        m.positiveCount++;
      } else {
        m.negativeCount++;
      }

      final ExampleVerdict verdict = _evaluateOne(example);
      verdicts.add(verdict);
      if (verdict.isInvalid) {
        m.invalid++;
        continue;
      }
      if (example.isPositive) {
        if (verdict.outcome && verdict.conclusionOk) {
          m.truePositive++;
        } else if (verdict.outcome && !verdict.conclusionOk) {
          m.wrongConclusion++;
        } else {
          m.falseNegative++;
        }
      } else {
        if (verdict.outcome) {
          m.falsePositive++;
        }
      }
    }

    return DatasetEvaluation(
      totalExamples: files.length,
      byTechnique: Map<TechniqueId, TechniqueEvalMetrics>.unmodifiable(metrics),
      verdicts: verdicts,
    );
  }

  /// 确定待评测的例文件清单：优先 manifest.json，否则全量递归扫描。
  List<File> _resolveExampleFiles(Directory root) {
    final File manifestFile = File(p.join(root.path, 'manifest.json'));
    if (manifestFile.existsSync()) {
      try {
        final Map<String, Object?> manifest = JsonWriter.readJsonMap(manifestFile.path);
        final Object? rawExamples = manifest['examples'];
        if (rawExamples is List<Object?>) {
          final List<File> listed = <File>[
            for (final Object? rel in rawExamples)
              if (rel is String && rel.isNotEmpty)
                File(p.join(root.path, p.normalize(rel))),
          ];
          final List<File> existing = <File>[
            for (final File f in listed)
              if (f.existsSync()) f,
          ];
          if (existing.isNotEmpty) {
            existing.sort((File a, File b) => a.path.compareTo(b.path));
            return existing;
          }
        }
      } on CliIoException {
        // manifest 损坏时回退到全量扫描。
      }
    }
    return root
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) =>
            f.path.toLowerCase().endsWith('.json') ||
            f.path.toLowerCase().endsWith('.gz'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));
  }

  /// 单个例的判定：按 checkMode 判定目标技巧是否命中 + expected 结论是否确认。
  ExampleVerdict _evaluateOne(AnnotatedExample example) {
    if (example.isInitialCheck) {
      final (bool ok, String? error, bool fired) = _initialScan(example);
      if (!ok) {
        return ExampleVerdict(
          example: example,
          outcome: false,
          invalidReason: error,
        );
      }
      // initial 模式不做 expected 结论核对（只有裸单边界负例使用）。
      return ExampleVerdict(example: example, outcome: fired);
    }

    final (bool ok, String? error, bool fired, List<AnnotatedScriptStep> steps) =
        _solve(example);
    if (!ok) {
      return ExampleVerdict(
        example: example,
        outcome: false,
        invalidReason: error,
      );
    }
    bool conclusionOk = true;
    if (example.isPositive &&
        (example.expectedEliminations.isNotEmpty ||
            example.expectedPlacements.isNotEmpty)) {
      conclusionOk = _conclusionConfirmed(
        example.techniqueId,
        steps,
        example.expectedEliminations,
        example.expectedPlacements,
      );
    }
    return ExampleVerdict(
      example: example,
      outcome: fired,
      conclusionOk: conclusionOk,
    );
  }

  /// 初始盘面状态直接扫描：目标识别器是否命中。
  (bool, String?, bool) _initialScan(AnnotatedExample example) {
    final List<int> given;
    final List<int> solution;
    try {
      given = BoardCodec.decodeValues(example.puzzle81);
      solution = BoardCodec.decodeValues(example.solution81);
      if (given.length != kCellCount || solution.length != kCellCount) {
        return (false, '81 字符串长度非法', false);
      }
      if (!Validator.isValidSolution(solution)) {
        return (false, '终局解非法（含冲突）', false);
      }
    } on Object catch (e) {
      return (false, '题面解析失败：$e', false);
    }
    final Board board = Board.fromValues(given, givenMask: <bool>[
      for (final int v in given) v != kEmptyValue,
    ]);
    CandidateCalculator.recomputeAll(board);
    final SolveContext ctx = SolveContext(
      board: board,
      ruleSet: RuleSet.t2(),
      uniqueSolutionGuaranteed: true,
      solution: solution,
    );
    final bool fired = registry
        .byId(example.techniqueId)
        .find(ctx, limit: 8)
        .any((TechniqueResult r) => r.isNotEmpty);
    return (true, null, fired);
  }

  /// 在 t2 规则集下重新逐级求解；返回 `(是否可解, 错误, 目标是否触发, 步骤)`。
  (bool, String?, bool, List<AnnotatedScriptStep>) _solve(
      AnnotatedExample example) {
    final List<int> given;
    final List<int> solution;
    try {
      given = BoardCodec.decodeValues(example.puzzle81);
      solution = BoardCodec.decodeValues(example.solution81);
      if (given.length != kCellCount || solution.length != kCellCount) {
        return (false, '81 字符串长度非法', false, const <AnnotatedScriptStep>[]);
      }
      if (!Validator.isValidSolution(solution)) {
        return (false, '终局解非法（含冲突）', false, const <AnnotatedScriptStep>[]);
      }
    } on Object catch (e) {
      return (false, '题面解析失败：$e', false, const <AnnotatedScriptStep>[]);
    }

    final AnnotatedPuzzle? annotated = annotateOne(
      puzzle: Puzzle(given: given, solution: solution),
      seed: example.seed ?? 0,
      ruleSet: RuleSet.t2(),
    );
    if (annotated == null) {
      return (false, 't2 规则集下不可解（纯逻辑失败）', false, const <AnnotatedScriptStep>[]);
    }
    final bool fired = annotated.techniques.contains(example.techniqueId);
    return (true, null, fired, annotated.script);
  }

  /// expected 结论是否被目标技巧的全部步骤确认（并集子集校验）。
  bool _conclusionConfirmed(
    TechniqueId techniqueId,
    List<AnnotatedScriptStep> steps,
    List<Elimination> expectedEliminations,
    List<Placement> expectedPlacements,
  ) {
    final Set<String> elims = <String>{};
    final Set<String> placements = <String>{};
    for (final AnnotatedScriptStep step in steps) {
      if (step.techniqueId != techniqueId) {
        continue;
      }
      for (final Elimination e in step.eliminations) {
        elims.add('${e.cellIndex}:${e.digit}');
      }
      for (final Placement pl in step.placements) {
        placements.add('${pl.cellIndex}=${pl.digit}');
      }
    }
    for (final Elimination e in expectedEliminations) {
      if (!elims.contains('${e.cellIndex}:${e.digit}')) {
        return false;
      }
    }
    for (final Placement pl in expectedPlacements) {
      if (!placements.contains('${pl.cellIndex}=${pl.digit}')) {
        return false;
      }
    }
    return true;
  }

  TechniqueEvalMetrics _metricsForUnknown(
    Map<TechniqueId, TechniqueEvalMetrics> metrics,
    String path,
  ) {
    // 无法解析技巧 id 的例，按路径中出现的技巧目录归集；否则归到 nakedSingle
    // 占位（只累计 invalid 计数，不影响 TP/FP）。
    final String? seg = _techniqueSegment(path);
    if (seg != null) {
      final TechniqueId? id = TechniqueId.tryParse(seg);
      if (id != null && metrics.containsKey(id)) {
        return metrics[id]!;
      }
    }
    return metrics[TechniqueId.nakedSingle]!;
  }

  static String? _techniqueSegment(String path) {
    final List<String> segments = p.split(p.normalize(path));
    // dataset/annotated/<tech>/positive|negative/<file> 形态下，
    // 倒数第二段是 positive/negative，倒数第三段是技巧 id。
    for (int i = 0; i + 2 < segments.length; i++) {
      final String maybe = segments[i + 1];
      if ((segments[i + 2] == 'positive' || segments[i + 2] == 'negative') &&
          TechniqueId.tryParse(maybe) != null) {
        return maybe;
      }
    }
    return null;
  }

  static AnnotatedExample _placeholder(String path) => AnnotatedExample(
        path: path,
        id: p.basenameWithoutExtension(path),
        techniqueId: TechniqueId.nakedSingle,
        label: 'unknown',
        puzzle81: '',
        solution81: '',
      );
}
