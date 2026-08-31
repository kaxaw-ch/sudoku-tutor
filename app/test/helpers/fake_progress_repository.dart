/// 测试共享假实现（T-QA-04）。
///
/// 为 unit / widget / integration 测试提供**确定性**的注入替身：
/// - [FakeProgressRepository]：内存存档仓储（无 path_provider / 磁盘 IO）；
/// - [buildTestPuzzle]：固定唯一解题（含可选技巧标注，供难度档 meta 断言）；
/// - [buildTestGameSession]：一局对局的构造助手；
/// - [FakePuzzleBankRepository]：固定题库（避开 rootBundle 读资产）。
///
/// 铁律：本文件**不触发真实 Isolate / path_provider / rootBundle**，
/// 全部为内存实现，保证 `flutter test` 可重复运行。
library;

import 'dart:typed_data';

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_bank_repository.dart';
import 'package:sudoku_tutor/domain/session/game_session.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/models/session_snapshot.dart';
import 'package:sudoku_tutor/domain/storage/models/teaching_session_snapshot.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';

/// 内存假仓储（可预置存档/断点，读改写全部在内存完成）。
class FakeProgressRepository implements ProgressRepository {
  /// 构造假仓储；[initial] 缺省为干净的初始存档。
  FakeProgressRepository({ProgressState? initial})
      : _state = initial ??
            const ProgressState(schemaVersion: 1, deviceId: 'fake-device');

  ProgressState _state;

  /// 当前存档（测试断言读改写结果）。
  ProgressState get current => _state;

  /// 当前断点（`null` = 无断点）。
  SessionSnapshot? snapshot;

  /// 各引导实操关的轻量断点。
  final Map<String, TeachingSessionSnapshot> teachingSnapshots =
      <String, TeachingSessionSnapshot>{};

  /// 若置 true，`load()` 抛异常（模拟存档 IO 损坏）。
  bool failOnLoad = false;

  /// 统计 `resetAll` 被调用的次数。
  int resetCount = 0;

  @override
  Future<ProgressState> load() async {
    if (failOnLoad) {
      throw StateError('模拟存档读取失败');
    }
    return _state;
  }

  @override
  Future<void> save(ProgressState state) async {
    _state = state;
  }

  @override
  Future<void> updateLevel(LevelProgress progress) async {
    final Map<String, LevelProgress> next = Map<String, LevelProgress>.of(
      _state.levels,
    )..[progress.levelId] = progress;
    _state = _state.copyWith(levels: next);
  }

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
    resetCount++;
    snapshot = null;
    teachingSnapshots.clear();
    _state = const ProgressState(schemaVersion: 1, deviceId: 'fake-device');
  }
}

/// 测试用唯一解题（取自题库 easy 档第 10 题，格 0 = 5）。
///
/// [techniques] 缺省为空；难度档 meta 测试可传入技巧标注。
Puzzle buildTestPuzzle({
  Difficulty? difficulty,
  Set<TechniqueId>? techniques,
}) =>
    Puzzle(
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
      difficulty: difficulty,
      techniques: techniques ?? const <TechniqueId>{},
    );

/// 用 [buildTestPuzzle] 构造一局对局（测试只读视图用）。
GameSession buildTestGameSession({
  Difficulty difficulty = Difficulty.medium,
  int elapsedMs = 0,
  bool paused = false,
  bool completed = false,
  int wrongCount = 0,
  int usedHints = 0,
  bool autoCandidates = true,
  bool markErrors = true,
  bool highlightSameDigit = true,
  bool recordStats = true,
  int? selectedIndex,
}) {
  final Puzzle puzzle = buildTestPuzzle(difficulty: difficulty);
  final Board board = puzzle.toGivenBoard();
  CandidateCalculator.recomputeAll(board);
  return GameSession(
    puzzle: puzzle,
    board: board.snapshot(),
    difficulty: difficulty,
    noteMasks: List<int>.of(board.candidateMasks),
    noteMode: false,
    autoCandidates: autoCandidates,
    selectedIndex: selectedIndex,
    errorCells: const <int>{},
    elapsedMs: elapsedMs,
    paused: paused,
    completed: completed,
    wrongCount: wrongCount,
    correctCount: 0,
    usedHints: usedHints,
    markErrors: markErrors,
    highlightSameDigit: highlightSameDigit,
    recordStats: recordStats,
  );
}

/// 固定题库假仓库（`loadBank` 返回预置题库，避开 rootBundle 读资产）。
///
/// [pool] 可注入章节试炼池（批次 F 教学试炼关测试用）；
/// 未注入时 `loadPool` 返回空池（不抛错，避免影响既有测试）。
class FakePuzzleBankRepository implements PuzzleBankRepository {
  /// 构造题库；[banks] 缺省为五档各含一道 [buildTestPuzzle]。
  FakePuzzleBankRepository({
    Map<Difficulty, DifficultyBank>? banks,
    TrialPool? pool,
  })  : banks = banks ??
            <Difficulty, DifficultyBank>{
              for (final Difficulty d in Difficulty.values)
                d: DifficultyBank(
                  difficulty: d,
                  puzzles: <Puzzle>[
                    buildTestPuzzle(
                      difficulty: d,
                      techniques: <TechniqueId>{
                        if (d == Difficulty.beginner) TechniqueId.nakedSingle,
                        if (d == Difficulty.easy) TechniqueId.nakedSingle,
                        if (d == Difficulty.medium) TechniqueId.nakedPair,
                        if (d == Difficulty.hard) TechniqueId.hiddenPair,
                        if (d == Difficulty.master) TechniqueId.xWing,
                      },
                    ),
                  ],
                ),
            },
        _pool = pool;

  /// 预置题库。
  final Map<Difficulty, DifficultyBank> banks;

  /// 预置试炼池（可为空）。
  final TrialPool? _pool;

  @override
  Future<DifficultyBank> loadBank(Difficulty difficulty) async =>
      banks[difficulty] ??
      DifficultyBank(difficulty: difficulty, puzzles: const <Puzzle>[]);

  @override
  Future<TrialPool> loadPool(int chapter) async =>
      _pool ??
      TrialPool(
        chapter: chapter,
        targetTechniques: const <TechniqueId>{},
        puzzles: const <Puzzle>[],
      );

  @override
  Future<String> loadGzText(String assetPath) async =>
      throw UnimplementedError('FakePuzzleBankRepository 不读取资产：$assetPath');

  @override
  Future<Uint8List> loadRaw(String assetPath) async =>
      throw UnimplementedError('FakePuzzleBankRepository 不读取资产：$assetPath');
}
