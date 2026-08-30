/// T-TEC-02 隐性唯一数（Hidden Single，rank 20）单测。
///
/// 说明：纯候选沙盘里「掩码为 0 的格」对扫描不可见，
/// 因此同一盘面往往会在列/宫方向额外产生若干隐性唯一数。
/// 正向用例一律采用**包含式断言**（断言目标结论在结果集中），
/// 反向用例采用**排除式断言**（断言禁止的结论绝不出现），二者都不受沙盘噪声影响。
library;

import 'package:sudoku_core/sudoku_core.dart';
import 'package:test/test.dart';

import 'support/technique_fixture.dart';

void main() {
  const HiddenSingleTechnique technique = HiddenSingleTechnique();

  group('HiddenSingle · 正向识别', () {
    test('行内数字 7 只剩一个候选位置 → 上报填数', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[1, 2],
        rc(0, 2): <int>[3, 4],
        rc(0, 3): <int>[3, 4, 7],
      });
      final List<TechniqueResult> results = scan(technique, ctx);

      expect(allPlacementKeys(results), contains(placeKey(rc(0, 3), 7)));
      expect(results.every(hasCompleteHintPayload), isTrue);
      expect(
        results.every((TechniqueResult r) => r.techniqueId == TechniqueId.hiddenSingle),
        isTrue,
      );
    });

    test('同一 (格, 数字) 被行/列/宫多次命中时只上报一次', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[6],
      });
      final List<TechniqueResult> results = scan(technique, ctx);
      // 行、列、宫三个单元都只有这一个 6 的候选位置，但去重后只有一条。
      expect(allPlacementKeys(results), <String>{placeKey(rc(0, 0), 6)});
      expect(results, hasLength(1));
    });

    test('rank / difficulty 由 TechniqueRank 单一事实源派生', () {
      expect(technique.rank, 20);
      expect(technique.difficulty, Difficulty.beginner);
    });
  });

  group('HiddenSingle · 反向「不得上报」', () {
    test('数字在单元内有 2 个候选位置 → 不上报', () {
      final SolveContext ctx = sandbox(<int, List<int>>{
        rc(0, 0): <int>[1, 2],
        rc(0, 1): <int>[1, 2],
        rc(1, 0): <int>[1, 2],
        rc(1, 1): <int>[1, 2],
      });
      // 行、列各 2 个位置，宫内 4 个位置 —— 任何单元都不成立。
      expect(scan(technique, ctx), isEmpty);
    });

    test('数字已在该单元落子 → 不再上报（unplacedDigitsIn 拦截）', () {
      // r1c5 的所属三个单元（第 1 行 / 第 5 列 / 第 2 宫）都已落子 7，
      // 即使人为把 r1c5 的候选写成「只剩 7」，也一律不得上报。
      final Board board = Board.fromPuzzleString(
        '7........'
        '.........'
        '...7.....'
        '.........'
        '.........'
        '....7....'
        '.........'
        '.........'
        '.........',
      );
      board.setCandidates(rc(0, 4), CandidateSet.fromDigits(<int>[7]));
      final SolveContext ctx = contextOf(board);
      final List<TechniqueResult> results = scan(technique, ctx);
      expect(allPlacementKeys(results), isNot(contains(placeKey(rc(0, 4), 7))));
      expect(results, isEmpty);
    });

    test('数字在单元内无任何候选位置 → 静默跳过', () {
      final SolveContext ctx = sandbox(<int, List<int>>{});
      expect(() => scan(technique, ctx), returnsNormally);
      expect(scan(technique, ctx), isEmpty);
    });

    test('规则集未启用该技巧 → 不上报', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{rc(0, 0): <int>[6]},
        ruleSet: RuleSet.none(),
      );
      expect(scan(technique, ctx), isEmpty);
    });

    test('E_TECH_001：填数与终局解冲突 → 该条结论被降级', () {
      final SolveContext ctx = sandbox(
        <int, List<int>>{
          rc(0, 0): <int>[1, 2],
          rc(0, 1): <int>[1, 2],
          rc(0, 2): <int>[3, 4],
          rc(0, 3): <int>[3, 4, 7],
        },
        // 终局解在 r1c4 是 3 而非 7 → 「r1c4 填 7」必须被拦下。
        solution: fakeSolutionWith(rc(0, 3), 3),
      );
      final List<TechniqueResult> results = scan(technique, ctx);
      expect(allPlacementKeys(results), isNot(contains(placeKey(rc(0, 3), 7))));
    });
  });
}
