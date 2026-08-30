/// T-DOM-03 · 题库仓库 + 选题测试（P0-PRA-01/10）。
///
/// 覆盖：
/// - gz 资产读取与 JSON 解析（fake loader 注入 gz 字节，验证 GZipCodec 链路）；
/// - schemaVersion 过高拒绝（E_SCHEMA_001）；
/// - 已玩去重选题（PuzzlePicker）与「全部玩过循环玩」；
/// - 运行时生成难度限制（困难/大师只用预置题库，返回 null）。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_bank_repository.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_picker.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/runtime_generator_service.dart';

/// 题库 JSON 文本 → gz 字节（fake loader 用）。
Uint8List gzEncode(String text) =>
    Uint8List.fromList(GZipCodec().encode(utf8.encode(text)));

/// 构造一档题库 JSON。
String bankJson(
    {int schemaVersion = 1, required List<Map<String, Object?>> puzzles}) {
  final StringBuffer buffer = StringBuffer();
  buffer.write('{"schemaVersion": $schemaVersion, "difficulty": "easy", '
      '"count": ${puzzles.length}, "puzzles": [');
  for (int i = 0; i < puzzles.length; i++) {
    if (i > 0) {
      buffer.write(',');
    }
    buffer.write(jsonEncode(puzzles[i]));
  }
  buffer.write(']}');
  return buffer.toString();
}

void main() {
  // 两道真实合法题（取自 app/assets/puzzles/easy.json.gz）。
  const String puzzle1 =
      '...157....2.983.....5264..82...15...183..6...5968..71...1....6..6....3....8....52';
  const String solution1 =
      '839157246624983175715264938247315689183796524596842713351429867462578391978631452';
  const String given1 =
      '000111000010111000001111001100011000111001000111100110001000010010000100001000011';
  const String puzzle2 =
      '.8.16.9...4.........2.7..18.162.....7..496.8.....3.5...78925.3..3.6.7..9..48..7..';
  const String solution2 =
      '387164952941582673562379418416258397753496281829731546678925134135647829294813765';

  late Map<String, Uint8List> assetMap;
  late int loadCount;

  PuzzleBankRepository repository() {
    loadCount = 0;
    assetMap = <String, Uint8List>{
      'assets/puzzles/easy.json.gz': gzEncode(
        bankJson(
          puzzles: <Map<String, Object?>>[
            <String, Object?>{
              'puzzle81': puzzle1,
              'solution81': solution1,
              'givenMask': given1,
              'difficulty': 'easy',
              'techniques': <String>['nakedSingle', 'hiddenSingle'],
            },
            <String, Object?>{
              'puzzle81': puzzle2,
              'solution81': solution2,
              'difficulty': 'easy',
            },
          ],
        ),
      ),
    };
    return PuzzleBankRepository(
      loader: (String path) async {
        loadCount++;
        return assetMap[path]!;
      },
    );
  }

  group('PuzzleBankRepository', () {
    test('gz 资产读取 + JSON 解析，字段齐全', () async {
      final PuzzleBankRepository repo = repository();
      final DifficultyBank bank = await repo.loadBank(Difficulty.easy);

      expect(bank.difficulty, Difficulty.easy);
      expect(bank.count, 2);
      expect(bank.puzzles[0].givenString, puzzle1);
      expect(bank.puzzles[0].solutionString, solution1);
      // givenMask 从资产固化掩码读取。
      expect(
        bank.puzzles[0].givenMask,
        <bool>[for (final String ch in given1.split('')) ch == '1'],
      );
      // 技巧标签解析。
      expect(
        bank.puzzles[0].techniques,
        containsAll(
            <TechniqueId>[TechniqueId.nakedSingle, TechniqueId.hiddenSingle]),
      );
      // 缺 givenMask/techniques 的条目按非空推断 + 空标签。
      expect(bank.puzzles[1].givenMask[0], isFalse); // puzzle2 首字符 '.' 非给定
      expect(bank.puzzles[1].givenMask[1], isTrue); // '8' 给定
      expect(bank.puzzles[1].techniques, isEmpty);
    });

    test('题库带缓存：二次加载不重新读资产', () async {
      final PuzzleBankRepository repo = repository();
      await repo.loadBank(Difficulty.easy);
      expect(loadCount, 1);
      await repo.loadBank(Difficulty.easy);
      expect(loadCount, 1, reason: '缓存后不应重复解压资产');
    });

    test('schemaVersion 高于当前 → E_SCHEMA_001', () async {
      final PuzzleBankRepository repo = PuzzleBankRepository(
        loader: (String path) async => gzEncode(bankJson(
            schemaVersion: 99, puzzles: const <Map<String, Object?>>[])),
      );
      await expectLater(
        repo.loadBank(Difficulty.easy),
        throwsA(
          isA<AppError>()
              .having((AppError e) => e.code, 'code', 'E_SCHEMA_001'),
        ),
      );
    });
  });

  group('PuzzlePicker', () {
    test('选题避开已玩指纹（已玩去重）', () async {
      final PuzzlePicker picker = PuzzlePicker(repository: repository());
      final Puzzle first = await picker.pick(Difficulty.easy);
      // 已玩 first → 应抽到另一题。
      final Puzzle second = await picker.pick(
        Difficulty.easy,
        seenFingerprints: <String>{first.fingerprint},
      );
      expect(second.fingerprint, isNot(first.fingerprint));
    });

    test('全部已玩 → 循环玩（不抛异常）', () async {
      final PuzzleBankRepository repo = repository();
      final DifficultyBank bank = await repo.loadBank(Difficulty.easy);
      final Set<String> all =
          bank.puzzles.map((Puzzle p) => p.fingerprint).toSet();
      final PuzzlePicker picker = PuzzlePicker(repository: repo);
      final Puzzle picked = await picker.pick(
        Difficulty.easy,
        seenFingerprints: all,
      );
      expect(all, contains(picked.fingerprint));
    });
  });

  group('RuntimeGeneratorService', () {
    test('困难/大师档只用预置题库：返回 null', () async {
      final RuntimeGeneratorService service = RuntimeGeneratorService(
        generate: (
            {required int seed,
            int targetGivens = 30,
            String symmetryId = 'none',
            bool requireExactTarget = false}) async {
          fail('困难/大师档不应调用生成器');
        },
      );
      expect(await service.generate(Difficulty.hard, seed: 1), isNull);
      expect(await service.generate(Difficulty.master, seed: 1), isNull);
    });

    test('入门/简单/中等档可补充生成，且产物标注为请求档位', () async {
      final RuntimeGeneratorService service = RuntimeGeneratorService(
        generate: (
            {required int seed,
            int targetGivens = 30,
            String symmetryId = 'none',
            bool requireExactTarget = false}) async {
          final Board given =
              Board.fromPuzzleString(puzzle1, markGivens: false);
          final List<int> solution = <int>[
            for (final String ch in solution1.split('')) int.parse(ch)
          ];
          return Puzzle(given: given.toValueList(), solution: solution);
        },
      );
      final Puzzle? puzzle =
          await service.generate(Difficulty.medium, seed: 42);
      expect(puzzle, isNotNull);
      expect(puzzle!.difficulty, Difficulty.medium, reason: '生成产物标注为请求档位');
    });

    test('canGenerate 判定：入门/简单/中等 true，困难/大师 false', () {
      expect(RuntimeGeneratorService.canGenerate(Difficulty.beginner), isTrue);
      expect(RuntimeGeneratorService.canGenerate(Difficulty.easy), isTrue);
      expect(RuntimeGeneratorService.canGenerate(Difficulty.medium), isTrue);
      expect(RuntimeGeneratorService.canGenerate(Difficulty.hard), isFalse);
      expect(RuntimeGeneratorService.canGenerate(Difficulty.master), isFalse);
    });
  });
}
