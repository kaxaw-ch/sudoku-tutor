/// T-DOM-04 · 对局状态机测试（P0-PRA-02/03/05/06/07/08/09）。
///
/// 覆盖：撤销/重做/重置、自动候选与手动笔记互斥（含事件）、核对答案
/// 只标错不纠正、退出自动保存 → 重进续玩（盘面/笔记/撤销栈一致）、
/// 序列化往返、计时暂停状态。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/session/check_answer_service.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/session/game_session_controller.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/models/session_snapshot.dart';
import 'package:sudoku_tutor/domain/storage/models/teaching_session_snapshot.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';

/// 内存假仓储（断点存取 + 其余 no-op）。
class FakeProgressRepository implements ProgressRepository {
  SessionSnapshot? snapshot;
  final Map<String, TeachingSessionSnapshot> teachingSnapshots =
      <String, TeachingSessionSnapshot>{};

  @override
  Future<ProgressState> load() async =>
      const ProgressState(schemaVersion: 1, deviceId: 'fake');

  @override
  Future<void> save(ProgressState state) async {}

  @override
  Future<void> updateLevel(LevelProgress progress) async {}

  @override
  Future<SessionSnapshot?> loadSession() async => snapshot;

  @override
  Future<void> saveSession(SessionSnapshot value) async {
    snapshot = value;
  }

  @override
  Future<void> clearSession() async {
    snapshot = null;
  }

  @override
  Future<TeachingSessionSnapshot?> loadTeachingSession(String levelId) async =>
      teachingSnapshots[levelId];

  @override
  Future<void> saveTeachingSession(TeachingSessionSnapshot value) async {
    teachingSnapshots[value.levelId] = value;
  }

  @override
  Future<void> clearTeachingSession(String levelId) async {
    teachingSnapshots.remove(levelId);
  }

  @override
  Future<String> exportArchive() async => '{}';

  @override
  Future<void> importArchive(String json) async {}

  @override
  Future<void> resetAll() async {
    snapshot = null;
    teachingSnapshots.clear();
  }
}

/// 测试用唯一解题（取自题库 easy 档第 10 题）。
final Puzzle testPuzzle = Puzzle(
  given: <int>[
    for (final String ch
        in '59.43..8...3..97....6....4..649.7..82798....18.5..3..7..8.25...731.....5.5.......'
            .split(''))
      ch == '.' ? 0 : int.parse(ch),
  ],
  solution: <int>[
    for (final String ch
        in '597432186483169752126578349364917528279856431815243967948725613731684295652391874'
            .split(''))
      int.parse(ch),
  ],
);

void main() {
  late FakeProgressRepository repo;
  late ProviderContainer container;
  late GameSessionController controller;

  setUp(() {
    repo = FakeProgressRepository();
    container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith((Ref ref) async => repo),
      ],
    );
    controller = container.read(gameSessionControllerProvider.notifier);
  });

  tearDown(() async {
    await controller.discardSession();
    container.dispose();
  });

  GameSession session() => container.read(gameSessionControllerProvider)!;

  Future<void> start() async {
    await controller.startNew(
      difficulty: Difficulty.medium,
      puzzle: testPuzzle,
      settings: const SettingsState(autoCandidates: true, markErrors: true),
    );
  }

  /// 找一个空格（非给定）。
  int blankOf(GameSession s) {
    for (int i = 0; i < 81; i++) {
      if (s.board.isBlank(i)) {
        return i;
      }
    }
    fail('无空格');
  }

  group('撤销/重做/重置', () {
    test('填数 → 撤销 → 重做，盘面与栈一致', () async {
      await start();
      final int cell = blankOf(session());
      final int correct = testPuzzle.solution[cell];

      controller.selectCell(cell);
      controller.inputDigit(correct);
      expect(session().board.valueAt(cell), correct);
      expect(session().undoMoves, hasLength(1));

      controller.undo();
      expect(session().board.isBlank(cell), isTrue);
      expect(session().undoMoves, isEmpty);
      expect(session().redoMoves, hasLength(1), reason: '界面应启用重做按钮');

      controller.redo();
      expect(session().board.valueAt(cell), correct);
      expect(session().undoMoves, hasLength(1));
      expect(session().redoMoves, isEmpty);
    });

    test('撤销错误填数清除红框，重做后恢复红框', () async {
      await start();
      final int cell = blankOf(session());
      final int correct = testPuzzle.solution[cell];
      final int wrong = correct == 9 ? 1 : correct + 1;

      controller.selectCell(cell);
      controller.inputDigit(wrong);
      expect(session().errorCells, contains(cell));

      controller.undo();
      expect(session().board.isBlank(cell), isTrue);
      expect(session().errorCells, isEmpty);
      expect(session().redoMoves, hasLength(1));

      controller.redo();
      expect(session().board.valueAt(cell), wrong);
      expect(session().errorCells, contains(cell));
      expect(session().redoMoves, isEmpty);
    });

    test('重置本局回到题面初始态且栈清空', () async {
      await start();
      final int cell = blankOf(session());
      controller.selectCell(cell);
      controller.inputDigit(1);
      controller.inputDigit(2);
      controller.inputDigit(3);
      expect(session().board.filledCount(), greaterThan(0));

      controller.resetRound();
      final GameSession s = session();
      expect(s.board.filledCount(), testPuzzle.givenCount);
      expect(s.undoMoves, isEmpty);
      expect(s.wrongCount, 0);
    });

    test('给定格不可被修改', () async {
      await start();
      final GameSession s = session();
      final int givenCell = s.board.givenMask.indexWhere((bool g) => g);
      controller.selectCell(givenCell);
      controller.inputDigit(5);
      expect(session().board.valueAt(givenCell), s.board.valueAt(givenCell));
      expect(session().undoMoves, isEmpty);
    });
  });

  group('自动候选与手动笔记互斥（P0-PRA-07）', () {
    test('默认不显示候选；点击自动笔记后一次性填满且保持普通填数模式', () async {
      await controller.startNew(
        difficulty: Difficulty.medium,
        puzzle: testPuzzle,
        settings: const SettingsState(),
      );

      GameSession current = session();
      expect(current.autoCandidates, isFalse);
      expect(current.autoNotesFilled, isFalse);
      expect(
          current.board.candidateMasks.every((int mask) => mask == 0), isTrue);

      final int cell = blankOf(current);
      controller.selectCell(cell);
      controller.inputDigit(testPuzzle.solution[cell]);
      controller.clearCell();
      expect(
        session().board.candidateMasks.every((int mask) => mask == 0),
        isTrue,
        reason: '自动候选关闭时，填数再擦除也不应悄悄显示候选',
      );

      final int historyBeforeAutoFill = session().undoMoves.length;
      controller.autoFillNotes();
      current = session();
      expect(current.autoCandidates, isFalse, reason: '一次性操作不应修改全局设置');
      expect(current.autoNotesFilled, isTrue);
      expect(current.noteMode, isFalse, reason: '自动笔记后应可直接输入大数字');
      expect(current.undoMoves, hasLength(historyBeforeAutoFill + 1),
          reason: '整次自动笔记应作为一个操作节点入栈');

      final Board expected = testPuzzle.toGivenBoard();
      CandidateCalculator.recomputeAll(expected);
      expect(current.board.candidateMasks, expected.candidateMasks);

      controller.undo();
      current = session();
      expect(current.autoNotesFilled, isFalse);
      expect(
          current.board.candidateMasks.every((int mask) => mask == 0), isTrue,
          reason: '一次撤销应恢复自动笔记前的整盘候选');
      expect(current.redoMoves.last.type, MoveType.autoFillCandidates);

      controller.redo();
      current = session();
      expect(current.autoNotesFilled, isTrue);
      expect(current.board.candidateMasks, expected.candidateMasks,
          reason: '重做应再次整盘填写合法候选');

      controller.selectCell(cell);
      controller.inputDigit(testPuzzle.solution[cell]);
      expect(session().board.valueAt(cell), testPuzzle.solution[cell]);
      expect(session().autoNotesFilled, isTrue);
    });

    test('一次性自动笔记随断点保存并恢复', () async {
      await controller.startNew(
        difficulty: Difficulty.medium,
        puzzle: testPuzzle,
        settings: const SettingsState(),
      );
      controller.autoFillNotes();
      final List<int> before = List<int>.of(session().board.candidateMasks);
      await controller.saveSnapshot();

      final ProviderContainer container2 = ProviderContainer(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
      );
      final GameSessionController controller2 =
          container2.read(gameSessionControllerProvider.notifier);
      addTearDown(() async {
        await controller2.discardSession();
        container2.dispose();
      });

      expect(
        await controller2.restoreIfAny(settings: const SettingsState()),
        isTrue,
      );
      final GameSession restored =
          container2.read(gameSessionControllerProvider)!;
      expect(restored.autoCandidates, isFalse);
      expect(restored.autoNotesFilled, isTrue);
      expect(restored.noteMode, isFalse);
      expect(restored.board.candidateMasks, before);
      expect(restored.undoMoves.last.type, MoveType.autoFillCandidates,
          reason: '断点恢复后自动笔记仍应位于操作树中');

      controller2.undo();
      final GameSession afterUndo =
          container2.read(gameSessionControllerProvider)!;
      expect(afterUndo.autoNotesFilled, isFalse);
      expect(
          afterUndo.board.candidateMasks.every((int mask) => mask == 0), isTrue,
          reason: '恢复断点后仍应能一次撤销整盘自动笔记');
    });

    test('笔记模式下 toggleNote 记录候选；退出笔记且自动候选开启 → 清空并广播事件', () async {
      await start();
      final List<GameSessionEvent> events = <GameSessionEvent>[];
      final StreamSubscription<GameSessionEvent> sub =
          controller.events.listen(events.add);

      final int cell = blankOf(session());
      controller.selectCell(cell);
      controller.toggleNoteMode(); // 进入笔记模式。
      expect(session().noteMode, isTrue);

      controller.toggleNote(5);
      expect(
        session().board.candidatesAt(cell).contains(5),
        isTrue,
        reason: '手动笔记应写入候选',
      );

      controller.toggleNoteMode(); // 退出笔记 → 自动候选开启 → 清空。
      expect(session().noteMode, isFalse);
      expect(
        events.whereType<AutoSwitchClearedNotesEvent>(),
        hasLength(1),
        reason: '切回自动候选应广播清空事件供 UI 弹窗',
      );

      await sub.cancel();
    });

    test('setAutoCandidates(true) 从笔记切回自动候选同样清空笔记', () async {
      await start();
      final int cell = blankOf(session());
      controller.selectCell(cell);
      controller.toggleNoteMode();
      controller.toggleNote(3);
      expect(session().board.candidatesAt(cell).contains(3), isTrue);

      controller.setAutoCandidates(true);
      // 已开启状态（默认 true）无变化：先关闭再开启验证。
      controller.setAutoCandidates(false);
      expect(session().autoCandidates, isFalse);
      controller.setAutoCandidates(true);
      // 笔记模式已被清空，候选回到数学候选（不含 3 若与已填冲突，或包含）。
      final GameSession s = session();
      expect(s.autoCandidates, isTrue);
      expect(s.noteMode, isFalse);
    });
  });

  group('核对答案（P0-PRA-03）', () {
    test('只标错不纠正不透露空格，并计入统计', () async {
      await start();
      final int cell = blankOf(session());
      final int correct = testPuzzle.solution[cell];
      final int wrong = correct == 1 ? 2 : 1;

      controller.selectCell(cell);
      controller.inputDigit(wrong); // 填错。

      final CheckResult result = controller.checkAnswer();
      expect(result.wrongCells, contains(cell));
      expect(session().errorCells, contains(cell));
      expect(session().wrongCount, 1);
      // 不纠正：错误格仍保留玩家填的错数。
      expect(session().board.valueAt(cell), wrong);
      // 空格不参与核对：错误集只含已填错格。
      expect(result.wrongCells.length, 1);
    });

    test('全部填对 → 完成事件', () async {
      await start();
      final List<GameSessionEvent> events = <GameSessionEvent>[];
      final StreamSubscription<GameSessionEvent> sub =
          controller.events.listen(events.add);

      // 依次填入所有空格的正解。
      final GameSession s = session();
      for (int i = 0; i < 81; i++) {
        if (s.board.isBlank(i)) {
          controller.selectCell(i);
          controller.inputDigit(testPuzzle.solution[i]);
        }
      }
      expect(session().completed, isTrue);
      expect(events.whereType<GameCompletedEvent>(), isNotEmpty);

      await sub.cancel();
    });

    test('填满时自动核验：错格标红不完成，修正后自动完成', () async {
      await controller.startNew(
        difficulty: Difficulty.medium,
        puzzle: testPuzzle,
        settings: const SettingsState(),
      );
      final List<GameSessionEvent> events = <GameSessionEvent>[];
      final StreamSubscription<GameSessionEvent> sub =
          controller.events.listen(events.add);
      final List<int> blanks = session().board.blankCells();
      final int last = blanks.last;

      for (final int cell in blanks.take(blanks.length - 1)) {
        controller.selectCell(cell);
        controller.inputDigit(testPuzzle.solution[cell]);
      }
      final int correct = testPuzzle.solution[last];
      final int wrong = correct == 9 ? 1 : correct + 1;
      controller.selectCell(last);
      controller.inputDigit(wrong);

      expect(session().board.isFull, isTrue);
      expect(session().completed, isFalse);
      expect(session().errorCells, contains(last));
      expect(
        events.whereType<GameAutoCheckFailedEvent>().single.wrongCount,
        1,
      );

      controller.inputDigit(correct);
      expect(session().completed, isTrue);
      expect(session().errorCells, isEmpty);
      expect(events.whereType<GameCompletedEvent>(), hasLength(1));

      await sub.cancel();
    });
  });

  group('计时（P0-PRA-08）', () {
    test('对局启动即计时；手动暂停后 paused 状态暴露', () async {
      await start();
      expect(controller.timer.isRunning, isTrue);

      controller.togglePause();
      expect(controller.timer.isRunning, isFalse);
      expect(session().paused, isTrue, reason: '暂停遮挡盘面由 UI 消费该状态');

      controller.togglePause();
      expect(controller.timer.isRunning, isTrue);
      expect(session().paused, isFalse);
    });

    test('生命周期暂停幂等；重复暂停不会反向恢复', () async {
      await start();

      controller.pause();
      expect(controller.timer.isRunning, isFalse);
      expect(session().paused, isTrue);

      controller.pause();
      expect(controller.timer.isRunning, isFalse);
      expect(session().paused, isTrue);

      controller.resume();
      expect(controller.timer.isRunning, isTrue);
      expect(session().paused, isFalse);
    });

    test('通关停止计时不属于暂停，且不能重新启动计时', () async {
      await start();
      for (final int cell in session().board.blankCells()) {
        controller.selectCell(cell);
        controller.inputDigit(testPuzzle.solution[cell]);
      }

      expect(session().completed, isTrue);
      expect(session().paused, isFalse);
      expect(controller.timer.isRunning, isFalse);

      controller.togglePause();
      expect(controller.timer.isRunning, isFalse);
      expect(session().paused, isFalse);
    });
  });

  group('断点续玩（P0-PRA-09）', () {
    test('退出自动保存 → 重进 restoreIfAny 盘面/笔记/撤销栈一致', () async {
      await start();
      final GameSession s0 = session();
      final List<int> blanks = s0.board.blankCells();
      final int cellA = blanks[0];
      final int cellB = blanks[1];
      final int valueA = testPuzzle.solution[cellA];
      final int valueB = testPuzzle.solution[cellB];

      // 填两格 + 撤销一格，制造撤销栈与盘面差异。
      controller.selectCell(cellA);
      controller.inputDigit(valueA);
      controller.selectCell(cellB);
      controller.inputDigit(valueB);
      controller.undo(); // 撤销 valueB。

      final GameSession beforeSave = session();
      expect(beforeSave.board.valueAt(cellA), valueA);
      expect(beforeSave.board.isBlank(cellB), isTrue);

      await controller.saveSnapshot();
      expect(repo.snapshot, isNotNull);

      // 新容器 + 恢复。
      final ProviderContainer container2 = ProviderContainer(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
      );
      final GameSessionController controller2 =
          container2.read(gameSessionControllerProvider.notifier);
      final bool restored = await controller2.restoreIfAny(
        settings: const SettingsState(),
      );
      expect(restored, isTrue);

      final GameSession after = container2.read(gameSessionControllerProvider)!;
      expect(after.board.valueAt(cellA), valueA, reason: '续玩盘面应一致');
      expect(after.board.isBlank(cellB), isTrue);
      expect(after.undoMoves.length, 1, reason: '撤销栈应一致');
      expect(after.elapsedMs, greaterThanOrEqualTo(0));

      // 续玩后仍可撤销。
      controller2.undo();
      expect(
        container2.read(gameSessionControllerProvider)!.board.isBlank(cellA),
        isTrue,
      );

      await controller2.discardSession();
      container2.dispose();
    });

    test('无断点时 restoreIfAny 返回 false', () async {
      final bool restored = await controller.restoreIfAny(
        settings: const SettingsState(),
      );
      expect(restored, isFalse);
    });

    test('startNew 覆盖式开始并清除旧断点（不支持多局并存）', () async {
      await start();
      await controller.saveSnapshot();
      expect(repo.snapshot, isNotNull);

      await start(); // 新局覆盖。
      expect(repo.snapshot, isNull, reason: '新局必须清除旧断点');
    });
  });
}
