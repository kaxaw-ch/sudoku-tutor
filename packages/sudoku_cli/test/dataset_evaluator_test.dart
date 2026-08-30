/// `DatasetEvaluator` 单元测试：precision/recall 计算与错误标注检出。
///
/// 使用真实盘面（从既有数据集抽取）：
/// - `xWingPositive` = `dataset/level_candidates/ch1/ch1_l05_candidate_1`
///   （t2 求解使用 xWing）；
/// - `easyBoard` = `app/assets/puzzles/easy.json.gz` 第一题
///   （t2 求解仅用 nakedSingle/hiddenSingle/nakedPair，不含 xWing）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:sudoku_core/sudoku_core.dart';
import 'package:sudoku_cli/sudoku_cli.dart';

const String xWingPuzzle81 =
    '.167...48..7..6.....9..1.3..9..6.4....1.7.6...4......5...8.71.....45....2....3.5.';
const String xWingSolution81 =
    '516732948387946512429581736792365481851274693643198275935827164168459327274613859';

const String easyPuzzle81 =
    '...157....2.983.....5264..82...15...183..6...5968..71...1....6..6....3....8....52';
const String easySolution81 =
    '839157246624983175715264938247315689183796524596842713351429867462578391978631452';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('dataset_eval_test_');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  Map<String, Object?> exampleJson({
    required String techniqueId,
    required String label,
    required String puzzle81,
    required String solution81,
    Map<String, Object?>? expected,
  }) =>
      <String, Object?>{
        'schemaVersion': 1,
        'kind': 'annotation-example',
        'techniqueId': techniqueId,
        'label': label,
        'puzzle81': puzzle81,
        'solution81': solution81,
        'seed': 1,
        'source': 'unit-test',
        'note': '单元测试盘面',
        if (expected != null) 'expected': expected,
      };

  void writeExample(String relative, Map<String, Object?> json) {
    final File file = File('${dir.path}/$relative');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(json));
  }

  test('正例命中 + 负例静默 → TP/TN，Precision/Recall 均 100%', () {
    writeExample(
      'xWing/positive/x1.json',
      exampleJson(
        techniqueId: 'xWing',
        label: 'positive',
        puzzle81: xWingPuzzle81,
        solution81: xWingSolution81,
      ),
    );
    writeExample(
      'xWing/negative/x2.json',
      exampleJson(
        techniqueId: 'xWing',
        label: 'negative',
        puzzle81: easyPuzzle81,
        solution81: easySolution81,
      ),
    );

    final DatasetEvaluation eval = DatasetEvaluator().evaluate(dir.path);
    final TechniqueEvalMetrics m = eval.byTechnique[TechniqueId.xWing]!;
    expect(m.positiveCount, 1);
    expect(m.negativeCount, 1);
    expect(m.truePositive, 1);
    expect(m.falseNegative, 0);
    expect(m.falsePositive, 0);
    expect(m.wrongConclusion, 0);
    expect(m.precision, 1.0);
    expect(m.recall, 1.0);
    expect(eval.passes, isTrue);
  });

  test('正例 expected 结论被确认（含 expected 字段）', () {
    // 用 sudoku_core 重新标注取得 xWing 首步结论作为 expected。
    final AnnotatedPuzzle? annotated = annotateOne(
      puzzle: Puzzle(
        given: BoardCodec.decodeValues(xWingPuzzle81),
        solution: BoardCodec.decodeValues(xWingSolution81),
      ),
      seed: 1,
      ruleSet: RuleSet.t2(),
    );
    expect(annotated, isNotNull);
    final AnnotatedScriptStep xStep = annotated!.script
        .firstWhere((AnnotatedScriptStep s) => s.techniqueId == TechniqueId.xWing);
    expect(xStep.eliminations, isNotEmpty, reason: 'xWing 步应有删数结论');

    writeExample(
      'xWing/positive/x1.json',
      exampleJson(
        techniqueId: 'xWing',
        label: 'positive',
        puzzle81: xWingPuzzle81,
        solution81: xWingSolution81,
        expected: <String, Object?>{
          'stepOrder': xStep.order,
          'techniqueId': 'xWing',
          'eliminations': <Map<String, Object?>>[
            for (final Elimination e in xStep.eliminations) e.toJson(),
          ],
          'placements': <Map<String, Object?>>[
            for (final Placement p in xStep.placements) p.toJson(),
          ],
        },
      ),
    );

    final DatasetEvaluation eval = DatasetEvaluator().evaluate(dir.path);
    final TechniqueEvalMetrics m = eval.byTechnique[TechniqueId.xWing]!;
    expect(m.truePositive, 1);
    expect(m.wrongConclusion, 0);
    expect(m.passes, isTrue);
  });

  test('错误标注被检出：负例实含 xWing → FP，Precision 降档', () {
    writeExample(
      'xWing/negative/x1.json',
      exampleJson(
        techniqueId: 'xWing',
        label: 'negative',
        puzzle81: xWingPuzzle81, // 实含 xWing，但被标成负例
        solution81: xWingSolution81,
      ),
    );
    writeExample(
      'xWing/positive/x2.json',
      exampleJson(
        techniqueId: 'xWing',
        label: 'positive',
        puzzle81: easyPuzzle81, // 实不含 xWing，但被标成正例
        solution81: easySolution81,
      ),
    );

    final DatasetEvaluation eval = DatasetEvaluator().evaluate(dir.path);
    final TechniqueEvalMetrics m = eval.byTechnique[TechniqueId.xWing]!;
    expect(m.falsePositive, 1, reason: '负例被识别器触发 → FP');
    expect(m.falseNegative, 1, reason: '正例未被触发 → FN');
    expect(m.truePositive, 0);
    expect(m.precision, 0.0);
    expect(m.recall, 0.0);
    expect(eval.passes, isFalse);
    expect(eval.renderFailures(), contains('误报'));
    expect(eval.renderFailures(), contains('漏报'));
  });

  test('正例 expected 与识别器结论不符 → wrongConclusion（precision 失败）', () {
    writeExample(
      'xWing/positive/x1.json',
      exampleJson(
        techniqueId: 'xWing',
        label: 'positive',
        puzzle81: xWingPuzzle81,
        solution81: xWingSolution81,
        expected: <String, Object?>{
          'stepOrder': 1,
          'techniqueId': 'xWing',
          'eliminations': <Map<String, Object?>>[
            <String, Object?>{'cellIndex': 0, 'digit': 1}, // 伪造错误结论
          ],
          'placements': <Object?>[],
        },
      ),
    );

    final DatasetEvaluation eval = DatasetEvaluator().evaluate(dir.path);
    final TechniqueEvalMetrics m = eval.byTechnique[TechniqueId.xWing]!;
    expect(m.wrongConclusion, 1);
    expect(m.truePositive, 0);
    expect(m.precision, 0.0);
    expect(m.recall, 0.0);
    expect(eval.passes, isFalse);
    expect(eval.renderFailures(), contains('结论错'));
  });

  test('结构异常例 → invalid 计数并阻断通过', () {
    writeExample(
      'xWing/positive/bad.json',
      <String, Object?>{
        'schemaVersion': 1,
        'kind': 'annotation-example',
        'techniqueId': 'xWing',
        'label': 'positive',
        // 缺 puzzle81/solution81
      },
    );

    final DatasetEvaluation eval = DatasetEvaluator().evaluate(dir.path);
    expect(eval.totalExamples, 1);
    final TechniqueEvalMetrics m = eval.byTechnique[TechniqueId.xWing]!;
    expect(m.invalid, 1);
    expect(eval.passes, isFalse);
    expect(eval.renderFailures(), contains('异常'));
  });

  test('目录不存在抛 DatasetEvalException', () {
    expect(
      () => DatasetEvaluator().evaluate('${dir.path}/nope'),
      throwsA(isA<DatasetEvalException>()),
    );
  });
}
