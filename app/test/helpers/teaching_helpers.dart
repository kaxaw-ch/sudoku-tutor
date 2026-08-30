/// 教学关测试共享工具（批次 F：T-EDU-02/03/04/05）。
///
/// - 固定合法终局解（拉丁方带结构）+ 挖 2 格题面（空格 = index5/index10）；
/// - 构造标准两步脚本：step1 裸单（填 index5=6）→ step2 隐单
///   （目标技巧，填 index10=5、删 index10 候选 4）；
/// - 课程 loader：`index.json` 登记三关（demo/实操/trial），关卡 JSON 按需返回。
library;

import 'dart:convert';

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';

/// 固定的合法终局解（9 行周期轮转的带结构，行列宫均合法）。
const String kTeachingSolution81 =
    '123456789456789123789123456234567891567891234891234567345678912678912345912345678';

/// 题面：在 [kTeachingSolution81] 上挖掉 index5（=6）与 index10（=5）。
String get kTeachingPuzzle81 {
  final List<String> chars = kTeachingSolution81.split('');
  chars[5] = '.';
  chars[10] = '.';
  return chars.join();
}

/// 关卡 JSON 文本构造（对齐 doc 06 §4.3 schema；visual 省略 → 空可视化）。
String buildTeachingLevelJson({
  required String id,
  required String kind,
  int chapter = 0,
  int order = 1,
  String title = '测试关',
  Set<TechniqueId> techniqueTags = const <TechniqueId>{},
  List<Map<String, Object?>> steps = const <Map<String, Object?>>[],
}) =>
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'id': id,
      'chapter': chapter,
      'order': order,
      'kind': kind,
      'title': title,
      'intro': '测试用教学关',
      'techniqueTags': <String>[
        for (final TechniqueId t in techniqueTags) t.id
      ],
      'puzzle81': kTeachingPuzzle81,
      'solution81': kTeachingSolution81,
      'poolRef': null,
      'script': <String, Object?>{
        'steps': steps,
        'stepCount': steps.length,
      },
    });

/// 构造一步脚本。
Map<String, Object?> teachingStep(
  int order,
  TechniqueId techniqueId, {
  List<Map<String, Object?>> placements = const <Map<String, Object?>>[],
  List<Map<String, Object?>> eliminations = const <Map<String, Object?>>[],
}) =>
    <String, Object?>{
      'order': order,
      'techniqueId': techniqueId.id,
      'involvedCells': <int>[
        for (final Map<String, Object?> p in placements) p['cell']! as int,
      ],
      'eliminations': eliminations,
      'placements': placements,
      'narration': '测试旁白（第 $order 步）',
    };

/// 标准两步脚本：前置裸单 + 目标隐单（含删数）。
List<Map<String, Object?>> buildTwoStepScript() => <Map<String, Object?>>[
      teachingStep(
        1,
        TechniqueId.nakedSingle,
        placements: <Map<String, Object?>>[
          <String, Object?>{'cell': 5, 'digit': 6}
        ],
      ),
      teachingStep(
        2,
        TechniqueId.hiddenSingle,
        placements: <Map<String, Object?>>[
          <String, Object?>{'cell': 10, 'digit': 5}
        ],
        eliminations: <Map<String, Object?>>[
          <String, Object?>{'cell': 10, 'digit': 4}
        ],
      ),
    ];

/// 课程 loader：登记三关（demo ch0_l01 / 实操 ch0_l02 / 试炼 ch0_l03）。
CurriculumAssetLoader buildTeachingCurriculumLoader({
  Map<String, String>? levelJsonById,
}) {
  final Map<String, String> levels = levelJsonById ?? const <String, String>{};
  return (String path) async {
    if (path == 'assets/curriculum/index.json') {
      return jsonEncode(<String, Object?>{
        'schemaVersion': 1,
        'chapters': <Object?>[
          <String, Object?>{
            'chapter': 0,
            'title': '第 0 章 · 测试',
            'techniqueTags': <String>['nakedSingle', 'hiddenSingle'],
            'levels': <Object?>[
              <String, Object?>{
                'id': 'ch0_l01',
                'chapter': 0,
                'order': 1,
                'kind': 'demo',
                'title': '演示关',
                'techniqueTags': <String>['nakedSingle'],
                'file': 'ch0_l01.json',
              },
              <String, Object?>{
                'id': 'ch0_l02',
                'chapter': 0,
                'order': 2,
                'kind': 'guidedPractice',
                'title': '实操关',
                'techniqueTags': <String>['nakedSingle', 'hiddenSingle'],
                'file': 'ch0_l02.json',
              },
              <String, Object?>{
                'id': 'ch0_l03',
                'chapter': 0,
                'order': 3,
                'kind': 'trial',
                'title': '试炼关',
                'techniqueTags': <String>['hiddenSingle'],
                'file': 'ch0_l03.json',
              },
            ],
          },
        ],
      });
    }
    return levels[path] ?? '';
  };
}

/// 默认三关 JSON（demo/实操/试炼，全部两步脚本）。
Map<String, String> buildDefaultTeachingLevels() => <String, String>{
      'assets/curriculum/ch0_l01.json': buildTeachingLevelJson(
        id: 'ch0_l01',
        kind: 'demo',
        title: '演示关',
        techniqueTags: const <TechniqueId>{TechniqueId.nakedSingle},
        steps: buildTwoStepScript(),
      ),
      'assets/curriculum/ch0_l02.json': buildTeachingLevelJson(
        id: 'ch0_l02',
        kind: 'guidedPractice',
        order: 2,
        title: '实操关',
        techniqueTags: const <TechniqueId>{
          TechniqueId.nakedSingle,
          TechniqueId.hiddenSingle,
        },
        steps: buildTwoStepScript(),
      ),
      'assets/curriculum/ch0_l03.json': buildTeachingLevelJson(
        id: 'ch0_l03',
        kind: 'trial',
        order: 3,
        title: '试炼关',
        techniqueTags: const <TechniqueId>{TechniqueId.hiddenSingle},
        steps: buildTwoStepScript(),
      ),
    };

/// 直接构造 [LessonLevel] 对象（不经 JSON，unit 测试用）。
LessonLevel buildTeachingLevel({
  required String id,
  required LevelKind kind,
  int chapter = 0,
  int order = 1,
  String title = '测试关',
  Set<TechniqueId> techniqueTags = const <TechniqueId>{},
  SolutionScript? script,
}) =>
    LessonLevel(
      id: id,
      chapter: chapter,
      order: order,
      kind: kind,
      title: title,
      techniqueTags: techniqueTags,
      puzzle81: kTeachingPuzzle81,
      solution81: kTeachingSolution81,
      script: script ??
          SolutionScript(
            steps: <ScriptStep>[
              ScriptStep(
                order: 1,
                techniqueId: TechniqueId.nakedSingle,
                placements: <Placement>[Placement(5, 6)],
              ),
              ScriptStep(
                order: 2,
                techniqueId: TechniqueId.hiddenSingle,
                placements: <Placement>[Placement(10, 5)],
                eliminations: <Elimination>[Elimination(10, 4)],
              ),
            ],
          ),
    );
