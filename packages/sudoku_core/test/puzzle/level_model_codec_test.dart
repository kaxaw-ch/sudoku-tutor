/// T-CORE-09：LevelPuzzle / LessonLevel / PuzzleBank 模型与 codec 测试。
///
/// 覆盖：
/// - LevelPuzzle（对齐 CLI AnnotatedPuzzle）encode/decode round-trip；
/// - 兼容解析 CLI 题库条目 JSON（`script` 数组 + `cellIndex` 键）；
/// - LessonLevel（对齐 doc 06 §4.3 关卡 JSON）encode/decode round-trip；
/// - 兼容解析 export-level 候选 JSON 形态（`script` 对象 + `cell` 键）；
/// - schemaVersion 过高抛 E_SCHEMA_001；kind 非法抛错；
/// - PuzzleBankCodec 题库集合 round-trip。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

/// 构造一关样本（演示关，带脚本）。
LessonLevel sampleLevel({String id = 'ch1_l03'}) => LessonLevel(
      id: id,
      chapter: 1,
      order: 3,
      kind: LevelKind.demo,
      title: 'X 翼：两行两列的锁定',
      intro: '本关讲解 X 翼的成立条件。',
      narration: const <String>['先看第 2 行与第 8 行。'],
      techniqueTags: <TechniqueId>{TechniqueId.xWing},
      puzzle81: '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      solution81: '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
      poolRef: null,
      script: SolutionScript(
        steps: <ScriptStep>[
          ScriptStep(
            order: 1,
            techniqueId: TechniqueId.xWing,
            eliminations: <Elimination>[Elimination(19, 5)],
            placements: const <Placement>[],
            involvedCells: const <int>[10, 16, 64, 70, 19],
            narration: 'r2 与 r8 行的候选 5 都只落在 c2/c8 两列，构成 X 翼。',
            visual: VisualHint(
              cells: <CellMark>[
                CellMark(index: 10, role: MarkRole.pattern),
              ],
              candidateMarks: <CandidateMark>[
                CandidateMark(
                  cellIndex: 19,
                  digit: 5,
                  kind: CandidateMarkKind.strike,
                ),
              ],
            ),
          ),
        ],
      ),
    );

void main() {
  group('LevelPuzzle · 题库条目形态', () {
    test('encodeItem → decodeItem 往返一致（含脚本数组形态）', () {
      final LevelPuzzle puzzle = LevelPuzzle(
        puzzle81: sampleLevel().puzzle81,
        solution81: sampleLevel().solution81,
        givenMask: null,
        seed: 42,
        fingerprint: 'fp-001',
        difficulty: Difficulty.medium,
        hardestTechnique: TechniqueId.xWing,
        stepCount: 12,
        techniques: <TechniqueId>{TechniqueId.nakedSingle, TechniqueId.xWing},
        usageCounts: <TechniqueId, int>{
          TechniqueId.nakedSingle: 9,
          TechniqueId.xWing: 3,
        },
        script: sampleLevel().script,
      );
      final Map<String, Object?> json = PuzzleCodec.encodeItem(puzzle);
      expect(json['difficulty'], equals('medium'));
      expect(json['hardestTechnique'], equals('xWing'));
      expect(json['script'], isA<List<Object?>>());

      final LevelPuzzle decoded = PuzzleCodec.decodeItem(json);
      expect(decoded.puzzle81, equals(puzzle.puzzle81));
      expect(decoded.solution81, equals(puzzle.solution81));
      expect(decoded.difficulty, equals(Difficulty.medium));
      expect(decoded.hardestTechnique, equals(TechniqueId.xWing));
      expect(decoded.stepCount, equals(12));
      expect(decoded.script, isNotNull);
      expect(decoded.script!.stepCount, equals(1));
      expect(decoded.script!.steps.single.eliminations.single.cellIndex, equals(19));
    });

    test('兼容解析 CLI 题库条目 JSON（script 数组 + cellIndex 键）', () {
      final Map<String, Object?> cliItem = <String, Object?>{
        'puzzle81': sampleLevel().puzzle81,
        'solution81': sampleLevel().solution81,
        'givenMask': null,
        'seed': 7,
        'fingerprint': 'f',
        'givenCount': 30,
        'difficulty': 'beginner',
        'hardestTechnique': 'nakedSingle',
        'stepCount': 55,
        'techniques': <String>['nakedSingle'],
        'usageCounts': <String, int>{'nakedSingle': 55},
        'script': <Map<String, Object?>>[
          <String, Object?>{
            'order': 1,
            'techniqueId': 'nakedSingle',
            'involvedCells': <int>[22],
            'eliminations': <Map<String, Object?>>[],
            'placements': <Map<String, Object?>>[
              <String, Object?>{'cellIndex': 22, 'digit': 1},
            ],
            'narration': '旁白',
            'visual': <String, Object?>{
              'cells': <Map<String, Object?>>[],
              'regions': <Map<String, Object?>>[],
              'links': <Map<String, Object?>>[],
              'candidateMarks': <Map<String, Object?>>[],
            },
          },
        ],
      };
      final LevelPuzzle decoded = PuzzleCodec.decodeItem(cliItem);
      expect(decoded.script, isNotNull);
      expect(decoded.script!.steps.single.placements.single.digit, equals(1));
    });

    test('toCore/fromCore 与引擎 Puzzle 互转', () {
      final LevelPuzzle level = LevelPuzzle(
        puzzle81: sampleLevel().puzzle81,
        solution81: sampleLevel().solution81,
      );
      final Puzzle core = level.toCore();
      // Puzzle.givenString 规范化输出 '.'，与输入 '0' 比较需按值对齐。
      expect(
        BoardCodec.decodeValues(core.givenString),
        equals(BoardCodec.decodeValues(level.puzzle81)),
      );
      expect(core.solutionString, equals(level.solution81));
      expect(core.givenCount, equals(30));

      final LevelPuzzle back = LevelPuzzle.fromCore(core);
      expect(
        BoardCodec.decodeValues(back.puzzle81),
        equals(BoardCodec.decodeValues(level.puzzle81)),
      );
    });
  });

  group('LessonLevel · 关卡 JSON 形态', () {
    test('encode → decode 往返一致', () {
      final LessonLevel level = sampleLevel();
      final LessonLevel decoded = LevelCodec.decode(LevelCodec.encode(level));
      expect(decoded.id, equals('ch1_l03'));
      expect(decoded.chapter, equals(1));
      expect(decoded.order, equals(3));
      expect(decoded.kind, equals(LevelKind.demo));
      expect(decoded.title, equals(level.title));
      expect(decoded.intro, equals(level.intro));
      expect(decoded.narration, equals(level.narration));
      expect(decoded.techniqueTags, equals(level.techniqueTags));
      expect(decoded.puzzle81, equals(level.puzzle81));
      expect(decoded.solution81, equals(level.solution81));
      expect(decoded.poolRef, isNull);
      expect(decoded.script, isNotNull);
      expect(decoded.script!.steps.single.order, equals(1));
    });

    test('encode 的 script 为对象形态、删数为 cell 键（对齐 doc 06 §4.3）', () {
      final LessonLevel level = sampleLevel();
      final Map<String, Object?> json = LevelCodec.encode(level);
      expect(json['script'], isA<Map<String, Object?>>());
      final Map<String, Object?> script = json['script']! as Map<String, Object?>;
      expect(script['steps'], isA<List<Object?>>());
      final Map<String, Object?> step0 =
          (script['steps']! as List<Object?>).first as Map<String, Object?>;
      final Map<String, Object?> elim0 =
          (step0['eliminations']! as List<Object?>).first as Map<String, Object?>;
      expect(elim0['cell'], equals(19));
      expect(elim0['cellIndex'], isNull);
      // 扩展字段非空才输出。
      expect(json['narration'], equals(level.narration));
    });

    test('兼容解析 export-level 候选 JSON 形态（script 对象 + cell 键）', () {
      final Map<String, Object?> candidateForm = LevelCodec.encode(sampleLevel());
      final LessonLevel decoded = LevelCodec.decode(candidateForm);
      expect(decoded.script!.steps.single.eliminations.single.cellIndex, equals(19));
    });

    test('schemaVersion 高于当前抛 E_SCHEMA_001', () {
      final Map<String, Object?> json = LevelCodec.encode(sampleLevel())
        ..['schemaVersion'] = kLevelSchemaVersion + 1;
      expect(
        () => LevelCodec.decode(json),
        throwsA(isA<CoreException>().having(
            (CoreException e) => e.errorCode, 'errorCode', CoreErrorCode.schemaTooNew)),
      );
    });

    test('kind 非法抛 CoreException', () {
      final Map<String, Object?> json = LevelCodec.encode(sampleLevel())
        ..['kind'] = 'bogus';
      expect(() => LevelCodec.decode(json), throwsA(isA<CoreException>()));
    });

    test('三种 kind 均合法', () {
      for (final LevelKind kind in LevelKind.values) {
        final LessonLevel level = LessonLevel(
          id: 'trial',
          chapter: 1,
          order: 1,
          kind: kind,
          title: 't',
          puzzle81: sampleLevel().puzzle81,
          solution81: sampleLevel().solution81,
        );
        expect(LevelCodec.decode(LevelCodec.encode(level)).kind, equals(kind));
      }
    });
  });

  group('PuzzleBankCodec · 题库集合', () {
    test('encodeBank → decodeBank 往返一致', () {
      final List<LevelPuzzle> puzzles = <LevelPuzzle>[
        LevelPuzzle(
          puzzle81: sampleLevel().puzzle81,
          solution81: sampleLevel().solution81,
          difficulty: Difficulty.beginner,
          techniques: <TechniqueId>{TechniqueId.nakedSingle},
        ),
        LevelPuzzle(
          puzzle81: '1....9......52.19.67...4......98..13.9.6....5......84.2...9...7..6...52.7...3....',
          solution81: '125369784483527196679814352547982613891643275362751849258196437936478521714235968',
          difficulty: Difficulty.beginner,
          techniques: <TechniqueId>{TechniqueId.nakedSingle},
        ),
      ];
      final Map<String, Object?> json = PuzzleCodec.encodeBank(
        difficulty: Difficulty.beginner,
        puzzles: puzzles,
        profile: 't2',
        seed: 1,
        concurrency: 2,
      );
      expect(json['schemaVersion'], equals(kPuzzleBankSchemaVersion));
      expect(json['count'], equals(2));

      final ParsedPuzzleBank decoded = PuzzleCodec.decodeBank(json);
      expect(decoded.difficulty, equals(Difficulty.beginner));
      expect(decoded.puzzles.length, equals(2));
      expect(decoded.puzzles[0].puzzle81, equals(puzzles[0].puzzle81));
    });

    test('兼容解析 CLI 题库 gz 解压后的 JSON（含 generatedAt 等冗余字段）', () {
      final Map<String, Object?> bankForm = PuzzleCodec.encodeBank(
        difficulty: Difficulty.beginner,
        puzzles: <LevelPuzzle>[
          LevelPuzzle(
            puzzle81: sampleLevel().puzzle81,
            solution81: sampleLevel().solution81,
          ),
        ],
      )..['generatedAt'] = '2026-08-07T05:44:19.659486Z';
      final ParsedPuzzleBank decoded = PuzzleCodec.decodeBank(bankForm);
      expect(decoded.puzzles, hasLength(1));
      expect(decoded.difficulty, equals(Difficulty.beginner));
    });
  });
}
