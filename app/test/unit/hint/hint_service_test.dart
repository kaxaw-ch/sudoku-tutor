/// T-DOM-05 · 提示服务测试（P0-PRA-04 / P0-EDU-04）。
///
/// 覆盖：
/// - 逐级解锁不可跳级（自由练习两级 / 教学三级）；
/// - 配额 `关闭/3/5/不限`，默认不限；
/// - **任何级别都不告知某格填几**（专项测试：断言结果无 Placement 直出
///   —— 类型层面无 placements 字段；裁剪后无 target 角色、无填数句式）；
/// - 三级给出删数结论（仍是候选删除，不是填数）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

/// 测试盘面（含终局解，用于构造 TechniqueResult；取自题库 easy 档第 10 题）。
final Board testBoard = Board.fromPuzzleString(
  '59.43..8...3..97....6....4..649.7..82798....18.5..3..7..8.25...731.....5.5.......',
  markGivens: true,
);
final List<int> testSolution = <int>[
  for (final String ch
      in '597432186483169752126578349364917528279856431815243967948725613731684295652391874'
          .split(''))
    int.parse(ch),
];

/// 构造一个「填数型」技巧结果（nakedSingle：placements 直出数字）。
TechniqueResult placementResult() => TechniqueResult(
      techniqueId: TechniqueId.nakedSingle,
      placements: <Placement>[Placement(4, 6)],
      visual: VisualHint.assemble(
        placed: <MapEntry<int, int>>[const MapEntry<int, int>(4, 6)],
        patternCells: const <int>[4],
      ),
    );

/// 构造一个「删数型」技巧结果（nakedPair：仅 eliminations，无 placements）。
TechniqueResult eliminationResult() => TechniqueResult(
      techniqueId: TechniqueId.nakedPair,
      eliminations: <Elimination>[Elimination(10, 5)],
      visual: VisualHint.assemble(
        patternCells: const <int>[11, 12],
        eliminated: <MapEntry<int, int>>[const MapEntry<int, int>(10, 5)],
        emphasized: <MapEntry<int, int>>[const MapEntry<int, int>(11, 5)],
      ),
    );

void main() {
  group('逐级解锁（不可跳级）', () {
    test('自由练习两级：level1 → level2 → 达上限返回 null', () async {
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            eliminationResult(),
      );
      final HintState? first = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.unlimited,
      );
      expect(first, isNotNull);
      expect(first!.level, HintLevel.level1);

      final HintState? second = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.unlimited,
      );
      expect(second, isNotNull);
      expect(second!.level, HintLevel.level2);
      expect(second.isMaxLevel, isTrue, reason: '自由练习最高二级');
      expect(second.narration, contains('第 2 行第 2 列'));
      expect(second.narration, isNot(contains('r2c2')));

      final HintState? third = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.unlimited,
      );
      expect(third, isNull, reason: '已达上限，不可跳级到三级');
      expect(
        service.lastUnavailableReason,
        HintUnavailableReason.maxLevelReached,
      );
    });

    test('盘面推进到新结论后自动回到一级，不会整局锁死提示', () async {
      TechniqueResult current = eliminationResult();
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            current,
      );

      final HintState first = (await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.unlimited,
      ))!;
      final HintState second = (await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.unlimited,
      ))!;
      expect(first.sceneFingerprint, second.sceneFingerprint);
      expect(second.level, HintLevel.level2);

      current = TechniqueResult(
        techniqueId: TechniqueId.hiddenPair,
        eliminations: <Elimination>[Elimination(20, 7)],
        visual: VisualHint.assemble(
          patternCells: const <int>[19, 20],
          eliminated: const <MapEntry<int, int>>[
            MapEntry<int, int>(20, 7),
          ],
        ),
      );
      final HintState nextScene = (await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.unlimited,
      ))!;

      expect(nextScene.level, HintLevel.level1);
      expect(nextScene.sceneFingerprint, isNot(first.sceneFingerprint));
      expect(service.unlockedLevelOf(HintScope.freePlay), 1);
    });

    test('教学三级：level1 → level2 → level3 → 已解锁满', () async {
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            eliminationResult(),
      );
      final HintState? first = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(first!.level, HintLevel.level1);

      final HintState? second = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(second!.level, HintLevel.level2);

      final HintState? third = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(third!.level, HintLevel.level3);

      final HintState? fourth = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(fourth, isNull, reason: '教学三级已解锁满');
    });

    test('同一场景单独解锁到三级不可跨到别场景（解锁按场景隔离）', () async {
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            eliminationResult(),
      );
      // 教学解锁到二级后，自由练习仍从一级开始（各自逐级）。
      await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      final HintState? freeFirst = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.unlimited,
      );
      expect(freeFirst!.level, HintLevel.level1);
    });
  });

  group('配额（关闭/3/5/不限）', () {
    test('关闭：任何请求都拒绝', () async {
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            eliminationResult(),
      );
      final HintState? hint = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.freePlay,
        quota: HintQuota.off,
      );
      expect(hint, isNull);
      expect(service.lastUnavailableReason, HintUnavailableReason.quotaOff);
    });

    test('3 次配额：成功 3 次后第 4 次拒绝；默认不限则一直可用', () async {
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            eliminationResult(),
      );
      for (int i = 0; i < 3; i++) {
        final HintState? hint = await service.requestNext(
          board: testBoard,
          solution: testSolution,
          scope: HintScope.teaching,
          quota: HintQuota.three,
        );
        expect(hint, isNotNull, reason: '第 ${i + 1} 次应在配额内');
      }
      final HintState? fourth = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.three,
      );
      expect(fourth, isNull, reason: '配额 3 次已耗尽');
    });

    test('5 次配额边界', () async {
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            eliminationResult(),
      );
      for (int i = 0; i < 5; i++) {
        await service.requestNext(
          board: testBoard,
          solution: testSolution,
          scope: HintScope.teaching,
          quota: HintQuota.five,
        );
      }
      final HintState? sixth = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.five,
      );
      expect(sixth, isNull);
    });
  });

  group('无 Placement 直出（专项测试）', () {
    test('引擎给出「填几」结果时，各级提示都不泄漏填数结论', () async {
      // scan 返回 placements=[Placement(4,6)] 的 nakedSingle 结果。
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            placementResult(),
      );

      // 一级：只给技巧名与区域高亮，无删数、无目标格。
      final HintState? first = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(first, isNotNull);
      expect(first!.eliminations, isEmpty, reason: '一级不得给删数');
      expect(
        first.visual.cells.where((CellMark m) => m.role == MarkRole.target),
        isEmpty,
        reason: '一级不得高亮目标格（那等于告诉填几）',
      );
      expect(
        first.narration,
        isNot(contains('填')),
        reason: '一级文案不得出现填数结论',
      );

      // 二级：点明关键格，仍无删数与目标格。
      final HintState? second = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(second, isNotNull);
      expect(second!.eliminations, isEmpty);
      expect(
        second.visual.cells.where((CellMark m) => m.role == MarkRole.target),
        isEmpty,
      );

      // 三级：纯填数技巧无删数结论 → 返回 null（宁可无提示，不直出答案）。
      final HintState? third = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(third, isNull, reason: '纯填数技巧不应在三级直出答案');
    });

    test('HintState 类型层面不存在 placements 字段（编译期保证）', () async {
      // 通过反射不可行，这里用「结构约定」断言：构造结果里的一切
      // placements 都不得出现在 HintState 暴露的任何字段中。
      final TechniqueResult result = placementResult();
      expect(result.placements, isNotEmpty, reason: '引擎结果确实含填数');

      // 用假 scan 走三级裁剪，验证 HintState 无任何途径携带 Placement。
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            result,
      );
      // 先解锁到一级、二级。
      final HintState? level1 = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(level1, isNotNull);
      final HintState? level2 = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(level2, isNotNull);
      // 仅删数型结果才能走到三级；填数型结果三级返回 null —— 即
      // 「填几」的结论永远没有出口。
      final HintState? level3 = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(level3, isNull);
    });
  });

  group('三级删数结论', () {
    test('删数型技巧：三级给出候选删除结论，且仍不含填数', () async {
      final HintService service = HintService(
        scan: (Board board, {RuleSet? ruleSet, String? solution81}) async =>
            eliminationResult(),
      );
      await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      final HintState? third = await service.requestNext(
        board: testBoard,
        solution: testSolution,
        scope: HintScope.teaching,
        quota: HintQuota.unlimited,
      );
      expect(third, isNotNull);
      expect(third!.hasEliminations, isTrue);
      expect(third.eliminations.single.cellIndex, 10);
      expect(third.eliminations.single.digit, 5);
      // 仍无「填几」：检查裁剪后 visual 无 target 角色。
      expect(
        third.visual.cells.where((CellMark m) => m.role == MarkRole.target),
        isEmpty,
      );
      // 文案是删数句式而非填数句式。
      expect(third.narration, contains('候选 5'));
      expect(third.narration, contains('第 2 行第 2 列'));
      expect(third.narration, isNot(contains('r2c2')));
    });
  });
}
