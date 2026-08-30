/// T-CORE-09：用真实教学关候选 JSON（T-CNT-03 产物）验证 codec。
///
/// 数据来源：`dataset/level_candidates/ch0/`（CLI `export-level` 产物，
/// 已过 `verify --dataset` 回放校验）。
/// 本测试只读文件、只做解析断言，不依赖外部网络或 flutter。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

/// 候选 JSON 相对包根（packages/sudoku_core）的路径。
const String kCandidatesDir = '../../dataset/level_candidates/ch0';

/// 挑 3 个代表：裸单演示 / 隐单演示（含隐单技巧标签）/ 裸对演示（含删数步）。
const List<String> kCandidateFiles = <String>[
  'ch0_l01_candidate_1.json',
  'ch0_l02_candidate_1.json',
  'ch0_l05_candidate_1.json',
];

LessonLevel loadCandidate(String fileName) {
  final File file = File('$kCandidatesDir/$fileName');
  expect(file.existsSync(), isTrue,
      reason: '真实候选 JSON 不存在：${file.absolute.path}');
  final Map<String, Object?> json =
      jsonDecode(file.readAsStringSync(encoding: utf8)) as Map<String, Object?>;
  return LevelCodec.decode(json);
}

void main() {
  group('真实候选 JSON · LevelCodec 解析', () {
    for (final String file in kCandidateFiles) {
      test('$file 解析成功且字段完整', () {
        final LessonLevel level = loadCandidate(file);

        // 关卡元字段。
        expect(level.schemaVersion, equals(kLevelSchemaVersion));
        expect(level.id, startsWith('ch0_l'));
        expect(level.chapter, equals(0));
        expect(level.order, greaterThan(0));
        expect(LevelKind.values, contains(level.kind));
        expect(level.title, isNotEmpty);
        expect(level.intro, isNotEmpty);
        expect(level.poolRef, isNull);

        // 盘面字段。
        expect(level.puzzle81.length, equals(81));
        expect(level.solution81.length, equals(81));
        expect(level.givenCount, greaterThan(0));
        expect(level.givenCount, lessThan(81));

        // 技巧标签。
        expect(level.techniqueTags, isNotEmpty,
            reason: '候选 JSON 必须带目标技巧标签');
        for (final TechniqueId id in level.techniqueTags) {
          expect(TechniqueId.tryParse(id.id), isNotNull);
        }

        // 脚本：完整解题脚本。
        expect(level.hasScript, isTrue);
        final SolutionScript script = level.script!;
        expect(script.stepCount, greaterThan(0));
        final List<int> orders = <int>[
          for (final ScriptStep step in script.steps) step.order,
        ];
        expect(orders, equals(<int>[for (int i = 1; i <= orders.length; i++) i]),
            reason: '步骤 order 必须从 1 连续递增');

        for (final ScriptStep step in script.steps) {
          expect(step.techniqueId, isNotNull);
          // involvedCells 升序。
          expect(
            step.involvedCells,
            equals(<int>[...step.involvedCells]..sort()),
            reason: '第 ${step.order} 步 involvedCells 必须升序',
          );
          for (final Elimination e in step.eliminations) {
            expect(e.cellIndex, inInclusiveRange(0, 80));
            expect(e.digit, inInclusiveRange(1, 9));
          }
          for (final Placement p in step.placements) {
            expect(p.cellIndex, inInclusiveRange(0, 80));
            expect(p.digit, inInclusiveRange(1, 9));
          }
        }
      });
    }

    test('解析后重新编码 → 再解析 → 字段相等（真实数据 round-trip）', () {
      final LessonLevel level = loadCandidate(kCandidateFiles.first);
      final LessonLevel redecoded = LevelCodec.decode(LevelCodec.encode(level));
      expect(redecoded.id, equals(level.id));
      expect(redecoded.puzzle81, equals(level.puzzle81));
      expect(redecoded.solution81, equals(level.solution81));
      expect(redecoded.script!.stepCount, equals(level.script!.stepCount));
      expect(
        redecoded.script!.steps.first.techniqueId,
        equals(level.script!.steps.first.techniqueId),
      );
    });

    test('含删数的候选（ch0_l05）能解析出正确删数结论', () {
      final LessonLevel level = loadCandidate('ch0_l05_candidate_1.json');
      final int elimSteps =
          level.script!.steps.where((ScriptStep s) => s.eliminations.isNotEmpty).length;
      expect(elimSteps, greaterThan(0), reason: '裸对关应含删数步骤');
      final ScriptStep firstElimStep = level.script!.steps
          .firstWhere((ScriptStep s) => s.eliminations.isNotEmpty);
      expect(firstElimStep.techniqueId, equals(TechniqueId.nakedPair));
      for (final Elimination e in firstElimStep.eliminations) {
        // 被删数字不能是该格终局解（SanityGuard 语义，抽查）。
        final int solutionDigit =
            int.parse(level.solution81[e.cellIndex]);
        expect(e.digit, isNot(equals(solutionDigit)),
            reason: '删数命中终局解是 P0 缺陷');
      }
    });
  });

  group('真实自由练习题库 · PuzzleCodec 解析', () {
    test('beginner.json.gz（CLI export-bank 产物）可完整解析且字段完整', () {
      final File file = File('../../app/assets/puzzles/beginner.json.gz');
      if (!file.existsSync()) {
        fail('自由练习题库不存在：${file.absolute.path}');
      }
      final String text =
          utf8.decode(gzip.decode(file.readAsBytesSync()));
      final Map<String, Object?> root =
          jsonDecode(text) as Map<String, Object?>;

      final ParsedPuzzleBank bank = PuzzleCodec.decodeBank(root);
      expect(bank.difficulty, equals(Difficulty.beginner));
      expect(bank.puzzles, isNotEmpty);
      for (final LevelPuzzle puzzle in bank.puzzles.take(5)) {
        expect(puzzle.puzzle81.length, equals(81));
        expect(puzzle.solution81.length, equals(81));
        expect(puzzle.difficulty, equals(Difficulty.beginner));
        expect(puzzle.givenCount, greaterThan(17));
        expect(puzzle.script, isNull,
            reason: '自由练习题库落盘不带脚本（体积优化）');
      }
    });
  });
}
