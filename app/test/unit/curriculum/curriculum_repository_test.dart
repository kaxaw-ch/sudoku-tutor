/// T-EDU-01 · 课程数据管线单测（P0-EDU-01，PRD C-25）。
///
/// 覆盖：
/// - index.json 加载与 LevelIndex 解析（复用 core codec，零自研解析）；
/// - 单关 JSON 经 LevelCodec 解码；
/// - **新增一关 = 加文件 + 登记一行**：仅追加登记与资产即可加载新关；
/// - schemaVersion 过高 → E_SCHEMA_001；
/// - 资产缺失/未登记 → E_IO_003。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';

/// 最小 index.json 文本（ch0 一章一关 + ch1 一章一关）。
String indexJson() => jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'chapters': <Object?>[
        <String, Object?>{
          'chapter': 0,
          'title': '第 0 章',
          'techniqueTags': <String>['nakedSingle'],
          'levels': <Object?>[
            <String, Object?>{
              'id': 'ch0_l01',
              'chapter': 0,
              'order': 1,
              'kind': 'demo',
              'title': '唯一余数',
              'techniqueTags': <String>['nakedSingle'],
              'file': 'ch0_l01.json',
            },
          ],
        },
        <String, Object?>{
          'chapter': 1,
          'title': '第 1 章',
          'techniqueTags': <String>['xWing'],
          'levels': <Object?>[
            <String, Object?>{
              'id': 'ch1_l01',
              'chapter': 1,
              'order': 1,
              'kind': 'demo',
              'title': 'X 翼',
              'techniqueTags': <String>['xWing'],
              'file': 'ch1_l01.json',
            },
          ],
        },
      ],
    });

/// 最小单关 JSON 文本。
String levelJson(String id, String title, String techniqueId) =>
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'id': id,
      'chapter': int.parse(id.substring(2, 3)),
      'order': 1,
      'kind': 'demo',
      'title': title,
      'intro': '测试关。',
      'techniqueTags': <String>[techniqueId],
      'puzzle81':
          '...157....2.983.....5264..82...15...183..6...5968..71...1....6..6....3....8....52',
      'solution81':
          '839157246624983175715264938247315689183796524596842713351429867462578391978631452',
      'poolRef': null,
      'script': <String, Object?>{
        'steps': <Object?>[
          <String, Object?>{
            'order': 1,
            'techniqueId': techniqueId,
            'involvedCells': <int>[3],
            'eliminations': <Object?>[],
            'placements': <Object?>[
              <String, Object?>{'cell': 3, 'digit': 1},
            ],
            'narration': '测试旁白。',
            'visual': <String, Object?>{
              'cells': <Object?>[
                <String, Object?>{
                  'index': 3,
                  'role': 'target',
                  'shape': 'dashedBorderWithCornerDot',
                  'focusDigits': <int>[],
                },
              ],
              'regions': <Object?>[],
              'links': <Object?>[],
              'candidateMarks': <Object?>[
                <String, Object?>{'cellIndex': 3, 'digit': 1, 'kind': 'target'},
              ],
            },
          },
        ],
      },
    });

void main() {
  late Map<String, String> assetMap;

  CurriculumRepository repository() {
    assetMap = <String, String>{
      'assets/curriculum/index.json': indexJson(),
      'assets/curriculum/ch0_l01.json':
          levelJson('ch0_l01', '唯一余数', 'nakedSingle'),
      'assets/curriculum/ch1_l01.json': levelJson('ch1_l01', 'X 翼', 'xWing'),
    };
    return CurriculumRepository(
      loader: (String path) async => assetMap[path]!,
    );
  }

  group('CurriculumRepository', () {
    test('loadIndex 用 core LevelIndex 解析：章节/关卡登记完整', () async {
      final CurriculumRepository repo = repository();
      final LevelIndex index = await repo.loadIndex();

      expect(index.schemaVersion, kLevelIndexSchemaVersion);
      expect(index.chapters, hasLength(2));
      expect(index.allLevels, hasLength(2));
      expect(index.byId('ch0_l01'), isNotNull);
      expect(index.byId('ch0_l01')!.kind, LevelKind.demo);
      expect(index.byId('ch0_l01')!.file, 'ch0_l01.json');
    });

    test('loadLevel 用 core LevelCodec 解码：字段完整', () async {
      final CurriculumRepository repo = repository();
      final LessonLevel level = await repo.loadLevel('ch0_l01');

      expect(level.id, 'ch0_l01');
      expect(level.kind, LevelKind.demo);
      expect(level.techniqueTags, contains(TechniqueId.nakedSingle));
      expect(level.givenCount, greaterThan(0));
      expect(level.hasScript, isTrue);
      expect(level.script!.stepCount, 1);
      // 可视化数据透传（UI 零推断的坐标来源）。
      expect(level.script!.steps.first.visual.cells, hasLength(1));
      expect(
        level.script!.steps.first.visual.candidateMarks,
        hasLength(1),
      );
    });

    test('新增一关 = 加文件 + 登记一行，零逻辑代码改动', () async {
      // 模拟「新增 ch9_l01」：仅追加 assets 文本 + index 登记行。
      assetMap = <String, String>{
        'assets/curriculum/index.json': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'chapters': <Object?>[
            <String, Object?>{
              'chapter': 9,
              'title': '第 9 章',
              'techniqueTags': <String>['wWing'],
              'levels': <Object?>[
                <String, Object?>{
                  'id': 'ch9_l01',
                  'chapter': 9,
                  'order': 1,
                  'kind': 'guidedPractice',
                  'title': 'W 翼',
                  'techniqueTags': <String>['wWing'],
                  'file': 'ch9_l01.json',
                },
              ],
            },
          ],
        }),
        'assets/curriculum/ch9_l01.json': levelJson('ch9_l01', 'W 翼', 'wWing'),
      };
      final CurriculumRepository repo = CurriculumRepository(
        loader: (String path) async => assetMap[path]!,
      );

      // 不改任何逻辑代码即可加载新关。
      final LessonLevel level = await repo.loadLevel('ch9_l01');
      expect(level.id, 'ch9_l01');
      expect(level.techniqueTags, contains(TechniqueId.wWing));
      expect(await repo.loadIndex().then((LevelIndex i) => i.byId('ch9_l01')),
          isNotNull);
    });

    test('index schemaVersion 过高 → E_SCHEMA_001', () async {
      final CurriculumRepository repo = CurriculumRepository(
        loader: (String path) async =>
            jsonEncode(<String, Object?>{'schemaVersion': 99}),
      );
      await expectLater(
        repo.loadIndex(),
        throwsA(
          isA<AppError>()
              .having((AppError e) => e.code, 'code', 'E_SCHEMA_001'),
        ),
      );
    });

    test('单关 schemaVersion 过高 → E_SCHEMA_001', () async {
      final CurriculumRepository repo = CurriculumRepository(
        loader: (String path) async => switch (path) {
          'assets/curriculum/index.json' => indexJson(),
          _ => jsonEncode(<String, Object?>{'schemaVersion': 99}),
        },
      );
      await expectLater(
        repo.loadLevel('ch0_l01'),
        throwsA(
          isA<AppError>()
              .having((AppError e) => e.code, 'code', 'E_SCHEMA_001'),
        ),
      );
    });

    test('未登记关卡 → E_IO_003', () async {
      final CurriculumRepository repo = repository();
      await expectLater(
        repo.loadLevel('nope'),
        throwsA(
          isA<AppError>().having((AppError e) => e.code, 'code', 'E_IO_003'),
        ),
      );
    });

    test('资产缺失 → E_IO_003', () async {
      final CurriculumRepository repo = CurriculumRepository(
        loader: (String path) async => throw StateError('missing: $path'),
      );
      await expectLater(
        repo.loadIndex(),
        throwsA(
          isA<AppError>().having((AppError e) => e.code, 'code', 'E_IO_003'),
        ),
      );
    });

    test('loadChapter 加载该章全部单关', () async {
      final CurriculumRepository repo = repository();
      final List<LessonLevel> chapter0 = await repo.loadChapter(0);
      expect(chapter0, hasLength(1));
      expect(chapter0.first.id, 'ch0_l01');
    });
  });
}
