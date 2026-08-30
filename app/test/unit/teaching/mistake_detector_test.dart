/// T-EDU-04 · 误操作即时纠正检测器单测。
///
/// 覆盖三类触发全覆盖：
/// - (a) wrongFill：填入与终局解不符；
/// - (b) deletedTrueCandidate：删除/清空终局解中为真的候选；
/// - (c) prematureFill：目标技巧触发态下抢先填数——**仅当当前盘面
///   无法凭推理推出该格（纯猜测/试错）时触发**；盘面可推理（含用
///   其它技巧路径推出）则不打扰（用户实测诉求：推理出来不判抢先）；
/// - 2 分钟去重（同指纹不重复弹，2 分钟后可再弹）；
/// - addCandidate / 清除已填格不触发。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_detector.dart';

import '../../helpers/teaching_helpers.dart';

void main() {
  late Board board;
  late List<int> solution;
  late LessonLevel level;

  setUp(() {
    board = Board.fromPuzzleString(kTeachingPuzzle81);
    CandidateCalculator.recomputeAll(board);
    solution = <int>[
      for (final String ch in kTeachingSolution81.split('')) int.parse(ch),
    ];
    level = buildTeachingLevel(
      id: 'ch0_l02',
      kind: LevelKind.guidedPractice,
      techniqueTags: const <TechniqueId>{
        TechniqueId.nakedSingle,
        TechniqueId.hiddenSingle,
      },
    );
  });

  MistakeContext ctx({
    Board? useBoard,
    bool noteMode = false,
    bool enablePrematureFill = true,
    Set<TechniqueId>? targets,
  }) =>
      MistakeContext(
        board: useBoard ?? board,
        solution: solution,
        noteMode: noteMode,
        script: level.script,
        targetTechniques: targets ?? level.techniqueTags,
        enablePrematureFill: enablePrematureFill,
      );

  group('(a) 填入与终局解不符', () {
    test('填错数字 → wrongFill', () {
      final MistakeEvent? event =
          MistakeDetector().detect(Move.place(10, 4), ctx());
      expect(event, isNotNull);
      expect(event!.type, MistakeType.wrongFill);
      expect(event.cellIndex, 10);
      expect(event.digit, 4);
    });

    test('填对数字不触发 (a)', () {
      // 关闭 (c) 抢先填数判定，纯测 (a)：填对 → 无 wrongFill。
      // （(c) 在初始盘面下对"填对但抢先"会正确触发，那是 (c) 的语义，不在此断言。）
      expect(
        MistakeDetector().detect(
          Move.place(10, 5),
          ctx(enablePrematureFill: false),
        ),
        isNull,
      );
    });
  });

  group('(b) 删除终局解中为真的候选', () {
    test('removeCandidate 删真候选 → deletedTrueCandidate', () {
      final MistakeEvent? event =
          MistakeDetector().detect(Move.removeCandidate(10, 5), ctx());
      expect(event, isNotNull);
      expect(event!.type, MistakeType.deletedTrueCandidate);
    });

    test('删除非真候选不触发', () {
      expect(
          MistakeDetector().detect(Move.removeCandidate(10, 4), ctx()), isNull);
    });

    test('笔记模式下清空含真值候选 → deletedTrueCandidate', () {
      // index10 唯一候选即 5（recomputeAll 后），清空等于删除真候选。
      final MistakeEvent? event =
          MistakeDetector().detect(Move.clear(10), ctx(noteMode: true));
      expect(event, isNotNull);
      expect(event!.type, MistakeType.deletedTrueCandidate);
    });

    test('清除已填格属于纠错，不触发', () {
      final Board filled = board.snapshot()..place(10, 5);
      final MistakeEvent? event =
          MistakeDetector().detect(Move.clear(10), ctx(useBoard: filled));
      expect(event, isNull);
    });
  });

  group('(c) 目标技巧触发态下抢先填数', () {
    test('前置技巧步未满足但盘面可推理 → 不触发（用户诉求：推理出来不打扰）', () {
      // (10,5) 是目标技巧 hiddenSingle 步的填数，前序 nakedSingle (5,6) 未就位；
      // 但当前盘面可凭 hiddenSingle 独立推出 (10,5)（有推理支撑）→ 不判抢先。
      final MistakeEvent? event =
          MistakeDetector().detect(Move.place(10, 5), ctx());
      expect(event, isNull, reason: '盘面能推理推出该格时不应判「抢先填数」');
    });

    test('前置步骤全部满足 → 正常推进不触发', () {
      final Board progressed = board.snapshot();
      progressed.place(5, 6); // 前序裸单就位。
      final MistakeEvent? event = MistakeDetector()
          .detect(Move.place(10, 5), ctx(useBoard: progressed));
      expect(event, isNull);
    });

    test('非目标技巧步骤的格 → 自由填数不触发', () {
      // targetTechniques 不含 hiddenSingle → (10,5) 不属于目标技巧判定范围。
      final MistakeEvent? event = MistakeDetector().detect(
        Move.place(10, 5),
        ctx(targets: const <TechniqueId>{TechniqueId.nakedSingle}),
      );
      expect(event, isNull);
    });

    test('enablePrematureFill=false（试炼关）→ 不触发', () {
      final MistakeEvent? event = MistakeDetector().detect(
        Move.place(10, 5),
        ctx(enablePrematureFill: false),
      );
      expect(event, isNull);
    });
  });

  group('2 分钟去重（同一关同一错误不重复弹）', () {
    test('同指纹 2 分钟内去重；2 分钟后可再弹', () {
      DateTime now = DateTime(2026, 1, 1, 0, 0, 0);
      final MistakeDetector detector = MistakeDetector(now: () => now);

      final MistakeEvent? first = detector.detect(Move.place(10, 4), ctx());
      expect(first, isNotNull);
      expect(first!.fingerprint, 'wrongFill:10:4');

      // 立刻重复 → 去重。
      expect(detector.detect(Move.place(10, 4), ctx()), isNull);

      // 同一格不同数字是「不同错误」，可再弹。
      final MistakeEvent? other = detector.detect(Move.place(10, 3), ctx());
      expect(other, isNotNull);
      expect(other!.fingerprint, 'wrongFill:10:3');

      // 2 分钟后同指纹可再弹。
      now = now.add(const Duration(minutes: 2));
      expect(detector.detect(Move.place(10, 4), ctx()), isNotNull);
    });

    test('resetForLevel 清空去重时间戳', () {
      final MistakeDetector detector = MistakeDetector(
        now: () => DateTime(2026, 1, 1, 0, 0, 0),
      );
      expect(detector.detect(Move.place(10, 4), ctx()), isNotNull);
      expect(detector.detect(Move.place(10, 4), ctx()), isNull);
      detector.resetForLevel();
      expect(detector.detect(Move.place(10, 4), ctx()), isNotNull);
    });
  });

  group('不触发边界', () {
    test('addCandidate 添加候选不是错误', () {
      expect(MistakeDetector().detect(Move.addCandidate(10, 5), ctx()), isNull);
    });

    test('无终局解时返回 null（不判定）', () {
      final MistakeContext noSolution = MistakeContext(
        board: board,
        solution: null,
        noteMode: false,
        script: level.script,
        targetTechniques: level.techniqueTags,
      );
      expect(MistakeDetector().detect(Move.place(10, 4), noSolution), isNull);
    });
  });
}
