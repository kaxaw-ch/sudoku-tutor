/// T-CORE-09：课程索引（index.json 清单模型）编解码测试。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

LevelIndex sampleIndex() => LevelIndex(
      chapters: <ChapterEntry>[
        ChapterEntry(
          chapter: 0,
          title: '第 0 章 规则与基础',
          techniqueTags: <TechniqueId>{
            TechniqueId.nakedSingle,
            TechniqueId.hiddenSingle,
          },
          levels: <LevelEntry>[
            LevelEntry(
              id: 'ch0_l01',
              chapter: 0,
              order: 1,
              kind: LevelKind.demo,
              title: '唯一余数',
              techniqueTags: <TechniqueId>{TechniqueId.nakedSingle},
              file: 'ch0_l01.json',
            ),
            LevelEntry(
              id: 'ch0_l02',
              chapter: 0,
              order: 2,
              kind: LevelKind.demo,
              title: '隐性唯一数',
              techniqueTags: <TechniqueId>{TechniqueId.hiddenSingle},
              file: 'ch0_l02.json',
            ),
          ],
        ),
        ChapterEntry(
          chapter: 1,
          title: '第 1 章 进阶技巧',
          techniqueTags: <TechniqueId>{TechniqueId.xWing},
          levels: <LevelEntry>[
            LevelEntry(
              id: 'ch1_l07',
              chapter: 1,
              order: 7,
              kind: LevelKind.trial,
              title: 'X 翼试炼',
              techniqueTags: <TechniqueId>{TechniqueId.xWing},
              file: 'ch1_l07.json',
            ),
          ],
        ),
      ],
    );

void main() {
  group('LevelIndex · index.json 编解码', () {
    test('toJson → fromJson 往返一致', () {
      final LevelIndex index = sampleIndex();
      final LevelIndex decoded = LevelIndex.fromJson(index.toJson());
      expect(decoded.schemaVersion, equals(kLevelIndexSchemaVersion));
      expect(decoded.chapters, hasLength(2));
      expect(decoded.chapters[0].levels, hasLength(2));
      expect(decoded.chapters[1].levels.single.id, equals('ch1_l07'));
      expect(decoded.chapters[1].levels.single.kind, equals(LevelKind.trial));
    });

    test('索引条目字段对齐 doc 06 §4.3（id/chapter/order/kind/title/techniqueTags/file）', () {
      final Map<String, Object?> json = sampleIndex().toJson();
      final Map<String, Object?> chapter0 =
          (json['chapters']! as List<Object?>).first as Map<String, Object?>;
      final Map<String, Object?> entry =
          (chapter0['levels']! as List<Object?>).first as Map<String, Object?>;
      expect(entry['id'], equals('ch0_l01'));
      expect(entry['chapter'], equals(0));
      expect(entry['order'], equals(1));
      expect(entry['kind'], equals('demo'));
      expect(entry['title'], equals('唯一余数'));
      expect(entry['techniqueTags'], isA<List<Object?>>());
      expect(entry['file'], equals('ch0_l01.json'));
    });

    test('allLevels 展开 + byId 查询', () {
      final LevelIndex index = sampleIndex();
      expect(index.allLevels, hasLength(3));
      final LevelEntry? found = index.byId('ch1_l07');
      expect(found, isNotNull);
      expect(found!.kind, equals(LevelKind.trial));
      expect(index.byId('ch0_l99'), isNull);
    });

    test('schemaVersion 高于当前抛 E_SCHEMA_001', () {
      final Map<String, Object?> json = sampleIndex().toJson()
        ..['schemaVersion'] = kLevelIndexSchemaVersion + 1;
      expect(
        () => LevelIndex.fromJson(json),
        throwsA(isA<CoreException>().having(
            (CoreException e) => e.errorCode, 'errorCode', CoreErrorCode.schemaTooNew)),
      );
    });
  });
}
