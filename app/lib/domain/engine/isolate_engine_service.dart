/// 常驻 Isolate 引擎服务（P0-ENG-12，架构 §7.5）。
///
/// 设计：
/// - **常驻 worker**（`Isolate.spawn` + 双 ReceivePort），评级/生成/提示扫描
///   三类任务都投递给同一 worker 串行执行，避免每次 spawn 的启动开销；
/// - 消息走 `EngineTask/EngineResult` **纯数据协议**（`engine_task.dart`），
///   worker 内重建 core 对象并调用 `sudoku_core`（算法唯一来源），
///   本层只做调度，**不含任何算法实现**；
/// - 取消：`cancelAll()` 使全局代次 `generation` 自增；在途任务结果回来时
///   代次不匹配 → 直接丢弃（Dart Isolate 无法强杀正在执行的运算，
///   但结果永远不会污染新代次）；未决的调用方收到 `E_ENGINE_001`；
/// - 超时策略（架构 §7.5）：提示扫描 5s / 单次生成 10s 由调用方
///   `EngineFacade` 用 `Future.timeout` 包裹后降级 `E_SOLVE_003` 语义。
library;

import 'dart:async';
import 'dart:isolate';

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';

import 'engine_task.dart';

// ================================================================ worker 侧

/// worker 入口（`Isolate.spawn` 要求顶层函数，禁止闭包）。
///
/// 启动即向主 isolate 回发 `ready`（携带本端 SendPort），
/// 之后循环收任务 → 调 [executeEngineTask]（纯 Dart 算法）→ 回发结果。
void engineWorker(SendPort mainPort) {
  final ReceivePort workerPort = ReceivePort();
  mainPort.send(<String, Object?>{
    'type': 'ready',
    'port': workerPort.sendPort,
  });
  workerPort.listen((Object? raw) async {
    final Map<String, Object?> msg = (raw! as Map).cast<String, Object?>();
    final EngineTask task;
    try {
      task = EngineTask.fromMessage(msg);
    } on Object catch (e) {
      // 消息本身不可解析：无 taskId 可路由，只能尽力回报（带 0 代次）。
      mainPort.send(<String, Object?>{
        'type': 'error',
        'taskId': (msg['taskId'] as int?) ?? 0,
        'generation': (msg['generation'] as int?) ?? 0,
        'code': 'E_ENGINE_002',
        'message': '任务消息无法解析：$e',
      });
      return;
    }
    try {
      // 诊断延迟（默认 0；测试验证 loading/cancel/不阻塞用）。
      if (task.delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: task.delayMs));
      }
      mainPort.send(executeEngineTask(task).toMessage());
    } on Object catch (e) {
      mainPort.send(EngineErrorResult(
        taskId: task.taskId,
        generation: task.generation,
        message: '引擎执行失败：$e',
      ).toMessage());
    }
  });
}

/// 执行一个引擎任务（worker isolate 内运行；算法全部来自 `sudoku_core`）。
EngineResult executeEngineTask(EngineTask task) => switch (task) {
      GradeTask t => _executeGrade(t),
      GenerateTask t => _executeGenerate(t),
      HintScanTask t => _executeHintScan(t),
    };

final DifficultyGrader _grader = DifficultyGrader();
final PuzzleGenerator _generator = const PuzzleGenerator();
final StepwiseSolver _solver = StepwiseSolver();

/// 由 81 串 + given 掩码重建盘面。
Board _rebuildBoard(String puzzle81, String? givenMask81) {
  final Board board = Board.fromPuzzleString(puzzle81, markGivens: false);
  if (givenMask81 != null && givenMask81.length == kCellCount) {
    for (int i = 0; i < kCellCount; i++) {
      board.setGiven(i, givenMask81[i] == '1');
    }
  }
  return board;
}

/// 规则集重建（空列表 = 全量 T2）。
RuleSet _ruleSet(List<String> ids) =>
    ids.isEmpty ? RuleSet.t2() : RuleSet.fromIdList(ids);

/// 终局解解析（`null` 表示未携带）。
List<int>? _parseSolution(String? solution81) => solution81 == null
    ? null
    : <int>[
        for (final String ch in solution81.split('')) int.parse(ch),
      ];

EngineResult _executeGrade(GradeTask t) {
  final Board board = _rebuildBoard(t.puzzle81, t.givenMask81);
  final GradingReport report = _grader.grade(
    board,
    ruleSet: _ruleSet(t.ruleSetIds),
    solution: _parseSolution(t.solution81),
    uniqueSolutionGuaranteed: t.uniqueGuaranteed,
  );
  return GradeResult(
    taskId: t.taskId,
    generation: t.generation,
    reportJson: report.toJson(),
  );
}

EngineResult _executeGenerate(GenerateTask t) {
  SymmetryMode symmetryOf(String id) {
    for (final SymmetryMode mode in SymmetryMode.values) {
      if (mode.id == id) {
        return mode;
      }
    }
    return SymmetryMode.none;
  }

  final Puzzle puzzle = _generator.generate(
    Rng(t.seed),
    targetGivens: t.targetGivens,
    symmetry: symmetryOf(t.symmetryId),
    requireExactTarget: t.requireExactTarget,
  );
  return GenerateResult(
    taskId: t.taskId,
    generation: t.generation,
    puzzle81: puzzle.givenString,
    solution81: puzzle.solutionString,
    givenCount: puzzle.givenCount,
  );
}

EngineResult _executeHintScan(HintScanTask t) {
  final Board board = _rebuildBoard(t.puzzle81, t.givenMask81);
  _restoreHintCandidates(board, t.candidateMasks81);
  final SolveContext ctx = SolveContext(
    board: board,
    ruleSet: _ruleSet(t.ruleSetIds),
    solution: _parseSolution(t.solution81),
  );
  final SolveStep? step = _solver.nextSolveStep(ctx, order: 1);
  return HintScanResult(
    taskId: t.taskId,
    generation: t.generation,
    techniqueJson: step?.result.toJson(),
  );
}

/// 为提示扫描恢复候选状态。
///
/// 先重算合法候选作为安全上界；若主 isolate 传来了完整候选盘面，则再取交集，
/// 从而保留玩家按照对子、数组、鱼、翼等提示已经完成的删数。传输数据损坏、
/// 长度不符或导致任一空格无候选时回退全量重算，绝不让非法笔记污染引擎。
void _restoreHintCandidates(Board board, List<int>? candidateMasks81) {
  CandidateCalculator.recomputeAll(board);
  if (candidateMasks81 == null || candidateMasks81.length != kCellCount) {
    return;
  }

  final List<int> constrained = List<int>.filled(kCellCount, 0);
  for (int i = 0; i < kCellCount; i++) {
    if (board.isFilled(i)) {
      continue;
    }
    final int sent = candidateMasks81[i] & CandidateSet.all.mask;
    final int intersection = board.candidateMasks[i] & sent;
    if (intersection == 0) {
      return;
    }
    constrained[i] = intersection;
  }
  for (int i = 0; i < kCellCount; i++) {
    board.candidateMasks[i] = constrained[i];
  }
}

// ================================================================ 主 isolate 侧

/// 常驻 Isolate 引擎服务（主 isolate 侧调度）。
class IsolateEngineService {
  /// 构造服务（worker 在首次提交任务时惰性启动）。
  IsolateEngineService();

  ReceivePort? _receivePort;
  Isolate? _isolate;
  SendPort? _workerPort;
  Completer<void>? _ready;
  bool _started = false;

  int _nextTaskId = 1;
  int _generation = 1;
  final Map<int, Completer<EngineResult>> _pending =
      <int, Completer<EngineResult>>{};

  /// 当前全局代次（暴露给测试断言「过期结果被丢弃」）。
  int get generation => _generation;

  /// 提交一个任务。
  ///
  /// [build] 接收服务端分配的 `taskId` 与当前 `generation`，构造任务。
  /// 返回的 Future 在任务完成（或 `cancelAll`）时结束。
  Future<EngineResult> runTask(
    EngineTask Function(int taskId, int generation) build,
  ) async {
    await _ensureStarted();
    final int taskId = _nextTaskId++;
    final EngineTask task = build(taskId, _generation);
    final Completer<EngineResult> completer = Completer<EngineResult>();
    _pending[taskId] = completer;
    _workerPort!.send(task.toMessage());
    return completer.future;
  }

  /// 取消全部在途任务：代次自增，未决调用方收到 `E_ENGINE_001`，
  /// 在途结果回来时代次不匹配被 [dispatchResult] 丢弃。
  void cancelAll() {
    _generation++;
    final int cancelledGeneration = _generation;
    for (final MapEntry<int, Completer<EngineResult>> e in _pending.entries) {
      e.value.complete(
        EngineErrorResult(
          taskId: e.key,
          generation: cancelledGeneration,
          code: 'E_ENGINE_001',
          message: '任务已取消',
        ),
      );
    }
    _pending.clear();
  }

  /// 处理 worker 回发的结果（供 facade/测试复用，含代次过滤）。
  void dispatchResult(EngineResult result) {
    if (result.generation != _generation) {
      return; // 过期结果，丢弃。
    }
    final Completer<EngineResult>? completer = _pending.remove(result.taskId);
    completer?.complete(result);
  }

  /// 释放资源：kill isolate、关闭端口、重置状态（Provider dispose 调用）。
  Future<void> dispose() async {
    _generation++;
    _pending.clear();
    _receivePort?.close();
    _receivePort = null;
    _workerPort = null;
    _ready = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _started = false;
  }

  Future<void> _ensureStarted() async {
    if (_started) {
      return;
    }
    _started = true;
    final ReceivePort receivePort = ReceivePort();
    _receivePort = receivePort;
    receivePort.listen(_onMessage);
    final Completer<void> ready = Completer<void>();
    _ready = ready;
    _isolate = await Isolate.spawn(engineWorker, receivePort.sendPort);
    await ready.future;
  }

  void _onMessage(Object? raw) {
    final Map<String, Object?> msg = (raw! as Map).cast<String, Object?>();
    if (msg['type'] == 'ready') {
      _workerPort = msg['port'] as SendPort;
      _ready?.complete();
      return;
    }
    dispatchResult(EngineResult.fromMessage(msg));
  }

  /// 便捷：将 `EngineErrorResult` 转成 `AppError`（facade 用）。
  static AppError toAppError(EngineErrorResult e) => AppError(
        e.code,
        e.message,
      );
}
