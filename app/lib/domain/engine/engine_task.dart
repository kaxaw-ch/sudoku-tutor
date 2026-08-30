/// 引擎任务/结果 —— **纯数据协议**（架构 §7.5 Isolate 通信协议）。
///
/// 铁律：
/// - 消息仅 `EngineTask` / `EngineResult` 两族**纯数据类**；
/// - 字段限于 `int / String / bool / List / Map`，**禁止闭包 / Widget /
///   BuildContext / 文件句柄 / Stream / Riverpod Ref**；
/// - 所有跨 Isolate 传输一律经过 `toMessage()/fromMessage()` 编解码
///   成 JSON 可序列化 map，保证 `SendPort.send` 可安全收发；
/// - 任务与结果均携带 `taskId`（请求代次）+ `generation`（全局代次），
///   `cancelAll()` 后旧代次结果在服务端被丢弃。
library;

/// 引擎任务类型（编解码的 `type` 字段）。
enum EngineTaskType {
  /// 难度评级。
  grade,

  /// 谜题生成。
  generate,

  /// 提示扫描（取当前盘面下一步技巧）。
  hintScan;

  /// 稳定标识。
  String get id => name;

  /// 反查。
  static EngineTaskType? tryParse(String id) {
    for (final EngineTaskType t in EngineTaskType.values) {
      if (t.id == id) {
        return t;
      }
    }
    return null;
  }
}

/// 引擎任务（sealed：评级/生成/提示扫描）。
sealed class EngineTask {
  /// 构造任务基类。
  const EngineTask({
    required this.taskId,
    required this.generation,
    this.delayMs = 0,
  });

  /// 请求代次：单任务唯一 ID（服务端用 Completer 路由）。
  final int taskId;

  /// 全局代次：`cancelAll()` 自增；结果回来时代次不匹配即丢弃。
  final int generation;

  /// 测试/诊断用：worker 计算前先睡眠该时长（毫秒，默认 0）。
  ///
  /// 用于确定性验证「>300ms 上抛 loading」「cancelAll 丢弃过期结果」
  /// 「Isolate 耗时任务不阻塞 UI 帧」，生产环境一律为 0。
  final int delayMs;

  /// 序列化为可 send 的 JSON map。
  Map<String, Object?> toMessage();

  /// 由消息反序列化。
  static EngineTask fromMessage(Map<String, Object?> msg) {
    final EngineTaskType? type =
        EngineTaskType.tryParse(msg['type']! as String);
    if (type == null) {
      throw ArgumentError('未知任务类型「${msg['type']}」');
    }
    final int taskId = msg['taskId']! as int;
    final int generation = msg['generation']! as int;
    final int delayMs = (msg['delayMs'] as int?) ?? 0;
    return switch (type) {
      EngineTaskType.grade => GradeTask(
          taskId: taskId,
          generation: generation,
          delayMs: delayMs,
          puzzle81: msg['puzzle81']! as String,
          givenMask81: msg['givenMask81'] as String?,
          solution81: msg['solution81'] as String?,
          ruleSetIds: <String>[
            if (msg['ruleSetIds'] is List)
              for (final Object? id in msg['ruleSetIds']! as List)
                id! as String,
          ],
          uniqueGuaranteed: (msg['uniqueGuaranteed'] as bool?) ?? true,
        ),
      EngineTaskType.generate => GenerateTask(
          taskId: taskId,
          generation: generation,
          delayMs: delayMs,
          seed: msg['seed']! as int,
          targetGivens: (msg['targetGivens'] as int?) ?? 30,
          symmetryId: (msg['symmetryId'] as String?) ?? 'none',
          requireExactTarget: (msg['requireExactTarget'] as bool?) ?? false,
        ),
      EngineTaskType.hintScan => HintScanTask(
          taskId: taskId,
          generation: generation,
          delayMs: delayMs,
          puzzle81: msg['puzzle81']! as String,
          givenMask81: msg['givenMask81'] as String?,
          solution81: msg['solution81'] as String?,
          candidateMasks81: msg['candidateMasks81'] is List
              ? <int>[
                  for (final Object? mask in msg['candidateMasks81']! as List)
                    mask! as int,
                ]
              : null,
          ruleSetIds: <String>[
            if (msg['ruleSetIds'] is List)
              for (final Object? id in msg['ruleSetIds']! as List)
                id! as String,
          ],
          maxSteps: (msg['maxSteps'] as int?) ?? 1,
        ),
    };
  }
}

/// 难度评级任务。
class GradeTask extends EngineTask {
  /// 构造评级任务。
  const GradeTask({
    required super.taskId,
    required super.generation,
    super.delayMs,
    required this.puzzle81,
    this.givenMask81,
    this.solution81,
    this.ruleSetIds = const <String>[],
    this.uniqueGuaranteed = true,
  });

  /// 当前盘面 81 字符串（空格用 `.`）。
  final String puzzle81;

  /// given 掩码 81 字符串（`1` = 给定格；可空，空则非空格视为 given）。
  final String? givenMask81;

  /// 终局解 81 字符串（可空，SanityGuard/唯一解判定用）。
  final String? solution81;

  /// 启用的技巧 ID 列表（`RuleSet.fromIdList` 口径；空 = 全量 T2）。
  final List<String> ruleSetIds;

  /// 谜题是否保证唯一解。
  final bool uniqueGuaranteed;

  @override
  Map<String, Object?> toMessage() => <String, Object?>{
        'type': EngineTaskType.grade.id,
        'taskId': taskId,
        'generation': generation,
        'delayMs': delayMs,
        'puzzle81': puzzle81,
        if (givenMask81 != null) 'givenMask81': givenMask81,
        if (solution81 != null) 'solution81': solution81,
        'ruleSetIds': ruleSetIds,
        'uniqueGuaranteed': uniqueGuaranteed,
      };
}

/// 谜题生成任务。
class GenerateTask extends EngineTask {
  /// 构造生成任务。
  const GenerateTask({
    required super.taskId,
    required super.generation,
    super.delayMs,
    required this.seed,
    this.targetGivens = 30,
    this.symmetryId = 'none',
    this.requireExactTarget = false,
  });

  /// 随机种子（同 seed 必产出同一道题，架构 §7.1 可复现性铁律）。
  final int seed;

  /// 目标提示数（钳制到不低于 17）。
  final int targetGivens;

  /// 对称策略（`SymmetryMode.id`：`none` / `central`）。
  final String symmetryId;

  /// 是否严格要求达到目标提示数（困难/大师档由题库保证，不走生成）。
  final bool requireExactTarget;

  @override
  Map<String, Object?> toMessage() => <String, Object?>{
        'type': EngineTaskType.generate.id,
        'taskId': taskId,
        'generation': generation,
        'delayMs': delayMs,
        'seed': seed,
        'targetGivens': targetGivens,
        'symmetryId': symmetryId,
        'requireExactTarget': requireExactTarget,
      };
}

/// 提示扫描任务（取当前盘面按规则集可用的**下一步**技巧）。
class HintScanTask extends EngineTask {
  /// 构造提示扫描任务。
  const HintScanTask({
    required super.taskId,
    required super.generation,
    super.delayMs,
    required this.puzzle81,
    this.givenMask81,
    this.solution81,
    this.candidateMasks81,
    this.ruleSetIds = const <String>[],
    this.maxSteps = 1,
  });

  /// 当前盘面 81 字符串。
  final String puzzle81;

  /// given 掩码 81 字符串。
  final String? givenMask81;

  /// 终局解 81 字符串（可空）。
  final String? solution81;

  /// 玩家当前的 81 格候选掩码；`null` 表示候选未完整初始化，worker 自行重算。
  final List<int>? candidateMasks81;

  /// 启用的技巧 ID 列表。
  final List<String> ruleSetIds;

  /// 最大推进步数（提示场景取 1 步即可；解整盘调试可调大）。
  final int maxSteps;

  @override
  Map<String, Object?> toMessage() => <String, Object?>{
        'type': EngineTaskType.hintScan.id,
        'taskId': taskId,
        'generation': generation,
        'delayMs': delayMs,
        'puzzle81': puzzle81,
        if (givenMask81 != null) 'givenMask81': givenMask81,
        if (solution81 != null) 'solution81': solution81,
        if (candidateMasks81 != null) 'candidateMasks81': candidateMasks81,
        'ruleSetIds': ruleSetIds,
        'maxSteps': maxSteps,
      };
}

/// 引擎结果（sealed：评级/生成/提示/错误）。
sealed class EngineResult {
  /// 构造结果基类。
  const EngineResult({required this.taskId, required this.generation});

  /// 请求代次（与任务对应，服务端按此路由）。
  final int taskId;

  /// 全局代次（不匹配当前代次即过期丢弃）。
  final int generation;

  /// 序列化为可 send 的 JSON map。
  Map<String, Object?> toMessage();

  /// 由消息反序列化。
  static EngineResult fromMessage(Map<String, Object?> msg) {
    final int taskId = msg['taskId']! as int;
    final int generation = msg['generation']! as int;
    final String type = msg['type']! as String;
    return switch (type) {
      'grade' => GradeResult(
          taskId: taskId,
          generation: generation,
          reportJson: msg['report']! as Map<String, Object?>,
        ),
      'generate' => GenerateResult(
          taskId: taskId,
          generation: generation,
          puzzle81: msg['puzzle81']! as String,
          solution81: msg['solution81']! as String,
          givenCount: (msg['givenCount'] as int?) ?? 0,
        ),
      'hintScan' => HintScanResult(
          taskId: taskId,
          generation: generation,
          techniqueJson: msg['technique'] as Map<String, Object?>?,
        ),
      'error' => EngineErrorResult(
          taskId: taskId,
          generation: generation,
          code: (msg['code'] as String?) ?? 'E_ENGINE_002',
          message: (msg['message'] as String?) ?? '引擎任务失败',
        ),
      _ => throw ArgumentError('未知结果类型「$type」'),
    };
  }
}

/// 评级结果（携带完整 `GradingReport.toJson()`）。
class GradeResult extends EngineResult {
  /// 构造评级结果。
  const GradeResult({
    required super.taskId,
    required super.generation,
    required this.reportJson,
  });

  /// `GradingReport.toJson()` 结果。
  final Map<String, Object?> reportJson;

  @override
  Map<String, Object?> toMessage() => <String, Object?>{
        'type': 'grade',
        'taskId': taskId,
        'generation': generation,
        'report': reportJson,
      };
}

/// 生成结果。
class GenerateResult extends EngineResult {
  /// 构造生成结果。
  const GenerateResult({
    required super.taskId,
    required super.generation,
    required this.puzzle81,
    required this.solution81,
    required this.givenCount,
  });

  /// 题面 81 字符串。
  final String puzzle81;

  /// 终局解 81 字符串。
  final String solution81;

  /// 提示数。
  final int givenCount;

  @override
  Map<String, Object?> toMessage() => <String, Object?>{
        'type': 'generate',
        'taskId': taskId,
        'generation': generation,
        'puzzle81': puzzle81,
        'solution81': solution81,
        'givenCount': givenCount,
      };
}

/// 提示扫描结果。
class HintScanResult extends EngineResult {
  /// 构造提示扫描结果。
  const HintScanResult({
    required super.taskId,
    required super.generation,
    this.techniqueJson,
  });

  /// `TechniqueResult.toJson()`；`null` = 当前规则集下无可用提示。
  final Map<String, Object?>? techniqueJson;

  @override
  Map<String, Object?> toMessage() => <String, Object?>{
        'type': 'hintScan',
        'taskId': taskId,
        'generation': generation,
        if (techniqueJson != null) 'technique': techniqueJson,
      };
}

/// 引擎错误结果（`cancelAll` / worker 内异常统一走此通道）。
class EngineErrorResult extends EngineResult {
  /// 构造错误结果。
  const EngineErrorResult({
    required super.taskId,
    required super.generation,
    this.code = 'E_ENGINE_002',
    this.message = '引擎任务失败',
  });

  /// 稳定错误码（`E_ENGINE_001` 取消 / `E_ENGINE_002` 执行失败）。
  final String code;

  /// 中文说明。
  final String message;

  @override
  Map<String, Object?> toMessage() => <String, Object?>{
        'type': 'error',
        'taskId': taskId,
        'generation': generation,
        'code': code,
        'message': message,
      };
}
