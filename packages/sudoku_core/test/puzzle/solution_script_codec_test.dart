/// T-CORE-09：解题脚本模型（ScriptStep/SolutionScript）JSON 编解码测试。
///
/// 覆盖：
/// - 关卡形态（对象 `{steps}` + `cell` 键）round-trip 一致；
/// - 题库形态（数组 + `cellIndex` 键）round-trip 一致；
/// - 读侧 `cell`/`cellIndex` 双兼容（人工构造两种键的 JSON 产出同一模型）；
/// - `VisualHint` 透传不丢字段。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

/// 构造一步裸单样本（含删数与填数、旁白、可视化）。
ScriptStep sampleStep({int order = 1, bool withElimination = true}) =>
    ScriptStep(
      order: order,
      techniqueId: TechniqueId.nakedSingle,
      eliminations: withElimination
          ? <Elimination>[Elimination(19, 5)]
          : const <Elimination>[],
      placements: <Placement>[Placement(22, 1)],
      involvedCells: <int>[19, 22],
      narration: 'r3c5 的候选只剩下 1 一个，因此这格只能填 1。',
      visual: VisualHint(
        cells: <CellMark>[
          CellMark(index: 22, role: MarkRole.target),
        ],
        candidateMarks: <CandidateMark>[
          CandidateMark(
            cellIndex: 22,
            digit: 1,
            kind: CandidateMarkKind.target,
          ),
        ],
      ),
    );

SolutionScript sampleScript({int count = 3}) =>
    SolutionScript(steps: <ScriptStep>[
      for (int i = 1; i <= count; i++) sampleStep(order: i),
    ]);

void main() {
  group('ScriptStep · 关卡形态（对象 + cell 键）', () {
    test('toJson → fromJson 往返一致', () {
      final ScriptStep step = sampleStep();
      final ScriptStep decoded = ScriptStep.fromJson(step.toJson());
      expect(decoded, equals(step));
    });

    test('toJson 输出的删数/填数用 cell 键（对齐 doc 06 §4.3 / 候选 JSON）', () {
      final Map<String, Object?> json = sampleStep().toJson();
      final List<Map<String, Object?>> elims =
          (json['eliminations']! as List<Object?>)
              .cast<Map<String, Object?>>();
      expect(elims[0]['cell'], equals(19));
      expect(elims[0]['cellIndex'], isNull);
      final List<Map<String, Object?>> places =
          (json['placements']! as List<Object?>)
              .cast<Map<String, Object?>>();
      expect(places[0]['cell'], equals(22));
    });

    test('读侧兼容 cellIndex 键（题库形态，CLI AnnotatedPuzzle）', () {
      final Map<String, Object?> json = sampleStep().toJson();
      // 把 cell 键改写为 cellIndex 键，模拟 CLI 题库条目形态。
      final Map<String, Object?> bankForm = <String, Object?>{
        ...json,
        'eliminations': <Map<String, Object?>>[
          <String, Object?>{'cellIndex': 19, 'digit': 5},
        ],
        'placements': <Map<String, Object?>>[
          <String, Object?>{'cellIndex': 22, 'digit': 1},
        ],
      };
      final ScriptStep decoded = ScriptStep.fromJson(bankForm);
      expect(decoded.eliminations.single.cellIndex, equals(19));
      expect(decoded.placements.single.cellIndex, equals(22));
    });

    test('visual 透传 VisualHint 不丢字段', () {
      final ScriptStep step = sampleStep();
      final ScriptStep decoded = ScriptStep.fromJson(step.toJson());
      expect(decoded.visual.cells.single.index, equals(22));
      expect(decoded.visual.cells.single.role, equals(MarkRole.target));
      expect(decoded.visual.candidateMarks.single.digit, equals(1));
      expect(
        decoded.visual.candidateMarks.single.kind,
        equals(CandidateMarkKind.target),
      );
    });
  });

  group('SolutionScript · 双形态 round-trip', () {
    test('关卡形态（toJson/fromJson）往返一致', () {
      final SolutionScript script = sampleScript(count: 5);
      final SolutionScript decoded = SolutionScript.fromJson(script.toJson());
      expect(decoded, equals(script));
      expect(decoded.stepCount, equals(5));
      expect(decoded.steps[3].order, equals(4));
    });

    test('题库形态（toStepJsonList/fromStepJsonList）往返一致', () {
      final SolutionScript script = sampleScript(count: 2);
      final SolutionScript decoded =
          SolutionScript.fromStepJsonList(script.toStepJsonList());
      expect(decoded, equals(script));
    });

    test('两种形态解析同一脚本得到同一模型', () {
      final SolutionScript script = sampleScript(count: 2);
      final SolutionScript fromObject = SolutionScript.fromJson(script.toJson());
      final SolutionScript fromArray =
          SolutionScript.fromStepJsonList(script.toStepJsonList());
      expect(fromObject, equals(fromArray));
    });

    test('空脚本与 usedTechniques 派生', () {
      final SolutionScript empty = SolutionScript();
      expect(empty.isEmpty, isTrue);
      expect(empty.stepCount, equals(0));
      final SolutionScript script = sampleScript(count: 3);
      expect(script.usedTechniques, contains(TechniqueId.nakedSingle));
    });
  });
}
