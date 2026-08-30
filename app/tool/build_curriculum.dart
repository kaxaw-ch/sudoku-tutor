/// F-5 主生成脚本（T-CNT-04 + T-CNT-05 交付物生成器）。
///
/// 职责：
/// 1. 从 dataset/level_candidates 精选 31 个非试炼关，覆盖正式 title/intro、
///    补 givenMask，写入 app/assets/curriculum/；
/// 2. 从 app/assets/pools 抽取 3 个试炼关，用 sudoku_core 逐级求解器生成
///    完整解题脚本（复用候选同款叙事模板），写入 app/assets/curriculum/；
/// 3. 生成 app/assets/curriculum/index.json（登记 34 关）；
/// 4. 输出 dataset/level_candidates/f5_selection_report.md（精选对齐证明）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

import 'project_paths.dart';

final String _root = findProjectRoot();
final String _candDir = '$_root/dataset/level_candidates';
final String _outDir = '$_root/app/assets/curriculum';
final String _poolDir = '$_root/app/assets/pools';

/// 基础技巧（不计入"最高技巧"）。
const Set<String> _base = <String>{'nakedSingle', 'hiddenSingle'};

/// 34 关精选表：id → (候选文件名, 正式标题, intro)。
/// kind 以候选现有 kind 为准（脚本读候选填充）。
const Map<String, List<String>> _selection = <String, List<String>>{
  // ---------- 第 0 章 ----------
  'ch0_l01': <String>[
    'ch0_l01_candidate_1.json',
    '规则讲解 · 唯一余数',
    '欢迎来到数独世界！先认识最基础也最常用的技巧——唯一余数：当一格只剩一个候选数时，它就只能填那个数。跟着演示，一格一格把盘面填满吧。',
  ],
  'ch0_l02': <String>[
    'ch0_l02_candidate_1.json',
    '规则讲解 · 隐性唯一数',
    '当某个数字在一行、一列或一宫里只剩一个位置可放时，这一格就锁定它。这叫隐性唯一数，与唯一余数一起构成数独的两大基本功。',
  ],
  'ch0_l03': <String>[
    'ch0_l03_candidate_1.json',
    '唯一余数（演示）',
    '再看一次唯一余数：数清每格还剩下哪些候选数，找到只剩一个候选的格子，把它填下去。',
  ],
  'ch0_l04': <String>[
    'ch0_l04_candidate_1.json',
    '隐性唯一数（演示）',
    '这一关演示隐性唯一数：逐行、逐列、逐宫观察，找出某个数字唯一能放的位置。',
  ],
  'ch0_l05': <String>[
    'ch0_l05_candidate_2.json',
    '裸对（演示）',
    '当同一单元（行、列或宫）里的两格候选数恰好都只含相同的两个数时，它们构成裸对；这两格相当于一个整体，可以排除该单元其余格中的这两个数。',
  ],
  'ch0_l06': <String>[
    'ch0_l06_candidate_1.json',
    '裸对（实操一）',
    '自己动手找裸对！回忆要点：同单元两格候选相同即构成裸对，把这对格子当作整体，排除其余格中的同名候选。',
  ],
  'ch0_l07': <String>[
    'ch0_l07_candidate_2.json',
    '隐对（演示）',
    '当两个数字在一个单元里只出现在同一对格子上时，它们构成隐对：这一对格子就专属于这两个数字，其余候选都可以删掉。',
  ],
  'ch0_l08': <String>[
    'ch0_l08_candidate_2.json',
    '隐对（实操一）',
    '来试试隐对：在行、列或宫里寻找「只属于两格的两个数字」，然后删除这两格中的多余候选。',
  ],
  'ch0_l09': <String>[
    'ch0_l09_candidate_4.json',
    '区块排除（演示）',
    '当某个宫里的一个数字只集中在同一行（或同一列）时，这条线穿越的其它宫里就可以排除该数字。这就是区块排除（指针法/占位法）。',
  ],
  'ch0_l10': <String>[
    'ch0_l10_candidate_3.json',
    '区块排除（实操一）',
    '现在你来实践区块排除：找到「宫指向行/列」或「行/列指向宫」的候选集中情形，排除对应单元里的数字。',
  ],
  // ---------- 第 1 章 ----------
  'ch1_l01': <String>[
    'ch1_l01_candidate_1.json',
    '裸三（演示）',
    '裸对升级为裸三：当同一单元里的三格候选数都来自同一组三个数时，它们构成裸三，可排除该单元其余格中的这三个数。',
  ],
  'ch1_l02': <String>[
    'ch1_l02_candidate_1.json',
    '隐三（演示）',
    '隐三是隐对的延伸：当三个数字在一个单元里只出现在三格中时，这三格就专属于它们，可删除三格的其它候选。',
  ],
  'ch1_l03': <String>[
    'ch1_l03_candidate_6.json',
    '裸三（实操一）',
    '动手找裸三：在三格候选都限于同一组三个数的单元里，排除其余格中的这三个数。',
  ],
  'ch1_l04': <String>[
    'ch1_l04_candidate_1.json',
    '隐三（实操一）',
    '练习隐三：留意单元中「只属于三格的三个数字」，然后删除那三格的其余候选。',
  ],
  'ch1_l05': <String>[
    'ch1_l05_candidate_2.json',
    'X 翼（演示）',
    'X 翼：当某个数字在两行里都恰好只出现在相同的两列上时，这两列上的其它位置就可以排除该数字。行列对偶，反之亦然。',
  ],
  'ch1_l06': <String>[
    'ch1_l06_candidate_1.json',
    'X 翼（实操一）',
    '现在轮到你来找 X 翼：盯住一个数字，看它是否在两行（或两列）中只落在相同的两列（或两行）上。',
  ],
  // ---------- 第 2 章 ----------
  'ch2_l01': <String>[
    'ch2_l01_candidate_1.json',
    '鳍形 X 翼（演示）',
    '鳍形 X 翼是 X 翼的变体：X 翼结构缺了一个角，但多出一个与缺角同宫的「鳍」格，依然能做出删数（含 Sashimi 退化形态）。',
  ],
  'ch2_l02': <String>[
    'ch2_l02_candidate_2.json',
    '剑鱼（演示）',
    '剑鱼是 X 翼的扩展：当某个数字在三行里只出现在相同的三列上时，构成剑鱼，这三列上的其它位置可排除该数字。',
  ],
  'ch2_l03': <String>[
    'ch2_l03_candidate_1.json',
    '鳍形 X 翼（实操一）',
    '练习鳍形 X 翼：先画出基本 X 翼，再找与缺角同宫的鳍格，判断它能否支撑删数。',
  ],
  'ch2_l04': <String>[
    'ch2_l04_candidate_3.json',
    '鳍形 X 翼（实操二）',
    '再来一关鳍形 X 翼：注意鳍可能藏在行内（Sashimi 形态），仔细核对候选的位置关系。',
  ],
  'ch2_l05': <String>[
    'ch2_l05_candidate_6.json',
    '剑鱼（实操一）',
    '实践剑鱼：在三个行（或三列）中找只落在相同三列（或三行）上的数字。',
  ],
  'ch2_l06': <String>[
    'ch2_l06_candidate_2.json',
    '剑鱼（实操二）',
    '剑鱼再练习：结构可能更隐蔽，先锁定一个数字，再看它的候选位置是否恰好铺成 3×3 的鱼形。',
  ],
  // ---------- 第 3 章 ----------
  'ch3_l01': <String>[
    'ch3_l01_candidate_6.json',
    'XY 翼（演示一）',
    'XY 翼：一个候选为 XY 的枢轴格，与两个分别含 XZ、YZ 的夹翼格相连；同时看到两个夹翼的那一格，不能填 Z。',
  ],
  'ch3_l02': <String>[
    'ch3_l02_candidate_3.json',
    'XY 翼（演示二）',
    '再看一个 XY 翼：记住判定要点——枢轴格候选为 XY，两夹翼分别为 XZ、YZ，三者必须两两互相「看到」。',
  ],
  'ch3_l03': <String>[
    'ch3_l03_candidate_4.json',
    'XYZ 翼（演示）',
    'XYZ 翼是 XY 翼的加强版：枢轴格候选为 XYZ，两夹翼分别为 XZ、YZ；同时看到枢轴格与两个夹翼的格子，不能填 Z。',
  ],
  'ch3_l04': <String>[
    'ch3_l04_candidate_1.json',
    'XY 翼（实操一）',
    '动手找 XY 翼：先找一个双候选格作枢轴，再检查它是否连接着两个能形成 XZ、YZ 的夹翼格。',
  ],
  'ch3_l05': <String>[
    'ch3_l05_candidate_2.json',
    'XY 翼（实操二）',
    '继续练习 XY 翼：注意三个格必须互相「看到」，删数格必须同时看到两个夹翼。',
  ],
  'ch3_l06': <String>[
    'ch3_l06_candidate_2.json',
    'XY 翼（实操三）',
    '最后一轮 XY 翼实操：多观察几次，你就能一眼认出这个经典的翅膀结构。',
  ],
  'ch3_l07': <String>[
    'ch3_l07_candidate_6.json',
    'XYZ 翼（实操一）',
    '实践 XYZ 翼：枢轴格三候选，两个夹翼与它共享其中两个数，删数发生在三者共同可见的格子上。',
  ],
  'ch3_l08': <String>[
    'ch3_l08_candidate_4.json',
    'XYZ 翼（实操二）',
    '再练 XYZ 翼：核对枢轴格与夹翼格的候选关系，找出能同时看到三者的删数格。',
  ],
  'ch3_l09': <String>[
    'ch3_l09_candidate_6.json',
    'XYZ 翼（实操三）',
    'XYZ 翼收官实操：把这组翅膀技巧融会贯通吧，你离第 3 章试炼只差一步。',
  ],
};

/// 试炼关定义：id → (章, order, 目标技巧, 池文件, 池内 seed, 标题, intro)。
const List<List<Object>> _trials = <List<Object>>[
  <Object>[
    'ch1_l07',
    1,
    7,
    'xWing',
    'ch1.json.gz',
    330092,
    'X 翼（试炼）',
    '本关为第 1 章验收试炼：从 X 翼题池随机抽题，完整解出整盘即可通关。系统不校验你是否用了目标技巧，但盘面必须用到 X 翼才能解开。',
  ],
  <Object>[
    'ch2_l07',
    2,
    7,
    'finnedXWing',
    'ch2.json.gz',
    140092,
    '鳍形 X 翼（试炼）',
    '本关为第 2 章验收试炼：从鳍形 X 翼（含 Sashimi）题池随机抽题，完整解出整盘即可通关。',
  ],
  <Object>[
    'ch3_l10',
    3,
    10,
    'xyzWing',
    'ch3.json.gz',
    150232,
    'XYZ 翼（试炼）',
    '本关为第 3 章验收试炼：从 XYZ 翼题池随机抽题，完整解出整盘即可通关。',
  ],
];

void main() {
  Directory(_outDir).createSync(recursive: true);

  final List<String> reportLines = <String>[];
  final ScriptReplayer replayer = ScriptReplayer();
  final Map<String, Map<String, Object?>> levelJsonById =
      <String, Map<String, Object?>>{};

  // ---- 1. 非试炼关精选 ----
  for (final String id in _selection.keys) {
    final List<String> sel = _selection[id]!;
    final String candidateFile = sel[0];
    final String title = sel[1];
    final String intro = sel[2];
    // ⚠️ 候选 JSON 内 id/order 是 T-CNT-03 export 时的连续序（文件名 lYY 是起始关，
    //    候选 N 的 JSON id = chX_l(YY+N-1)）。正式关的 id/chapter/order 一律以目标关为准。
    final RegExpMatch idMatch = RegExp(r'^ch(\d+)_l(\d+)$').firstMatch(id)!;
    final int chapter = int.parse(idMatch.group(1)!);
    final int order = int.parse(idMatch.group(2)!);
    final String candPath = '$_candDir/ch$chapter/$candidateFile';
    final Map<String, Object?> json =
        (jsonDecode(File(candPath).readAsStringSync()) as Map<String, Object?>);
    final LessonLevel level = LevelCodec.decode(json);
    final String? hardest = _hardest(level.techniqueTags);

    // 覆盖正式文案，补 givenMask（由题面推导）。
    final Map<String, Object?> out = <String, Object?>{
      'schemaVersion': 1,
      'id': id,
      'chapter': chapter,
      'order': order,
      'kind': level.kind.id,
      'title': title,
      'intro': intro,
      'techniqueTags': <String>[
        for (final TechniqueId t in level.techniqueTags) t.id
      ],
      'puzzle81': level.puzzle81,
      'solution81': level.solution81,
      'givenMask': _deriveMask(level.puzzle81),
      'poolRef': null,
      // 候选产物可能仍含历史 r3c4/3r4c 记号；正式教学资源统一中文化。
      'script': _localizeTeachingText(json['script']),
    };
    levelJsonById[id] = out;
    _writeJson('$_outDir/$id.json', out);

    // 回放校验（生成即验，失败立刻暴露）。
    final ScriptReplayOutcome outcome = replayer.replayLevel(level);
    if (!outcome.passed) {
      stderr.writeln('[FATAL] $id 回放失败：${outcome.mismatches.first}');
      exit(2);
    }
    reportLines.add(
      '$id|$candidateFile|${_targetOf(id)}|${hardest ?? "basic"}|'
      '${level.script!.stepCount}|${level.kind.id}|回放通过',
    );
  }

  // ---- 2. 试炼关 ----
  final Map<String, List<Map<String, Object?>>> poolCache =
      <String, List<Map<String, Object?>>>{};
  for (final List<Object> trial in _trials) {
    final String id = trial[0] as String;
    final int chapter = trial[1] as int;
    final int order = trial[2] as int;
    final String target = trial[3] as String;
    final String poolFile = trial[4] as String;
    final int seed = trial[5] as int;
    final String title = trial[6] as String;
    final String intro = trial[7] as String;

    final List<Map<String, Object?>> puzzles =
        poolCache.putIfAbsent(poolFile, () => _loadPool(poolFile));
    Map<String, Object?>? poolPuzzle;
    for (final Map<String, Object?> p in puzzles) {
      if (p['seed'] == seed) {
        poolPuzzle = p;
        break;
      }
    }
    if (poolPuzzle == null) {
      stderr.writeln('[FATAL] 池 $poolFile 未找到 seed=$seed 的题');
      exit(2);
    }
    final String puzzle81 = poolPuzzle['puzzle81']! as String;
    final String solution81 = poolPuzzle['solution81']! as String;

    // 用 sudoku_core 逐级求解器生成脚本（复用候选同款叙事模板）。
    final SolutionScript script = _solveScript(puzzle81, solution81);
    final String? hardest = _hardestOfScript(script);

    final Map<String, Object?> out = <String, Object?>{
      'schemaVersion': 1,
      'id': id,
      'chapter': chapter,
      'order': order,
      'kind': 'trial',
      'title': title,
      'intro': intro,
      'techniqueTags': <String>[target],
      'puzzle81': puzzle81,
      'solution81': solution81,
      'givenMask':
          (poolPuzzle['givenMask'] as String?) ?? _deriveMask(puzzle81),
      'poolRef': 'pools/$poolFile',
      'script': script.toJson(),
    };
    levelJsonById[id] = out;
    _writeJson('$_outDir/$id.json', out);

    // 校验：唯一解 + 最高技巧 == 目标技巧 + 回放通过。
    final LessonLevel level = LevelCodec.decode(out);
    final Board board = level.toLevelPuzzle().toCore().toGivenBoard();
    final bool unique = const UniquenessChecker().isUnique(board);
    final ScriptReplayOutcome replay = replayer.replayLevel(level);
    final bool targetOk = hardest == target;
    if (!unique || !replay.passed || !targetOk) {
      stderr.writeln('[FATAL] $id 试炼校验失败 unique=$unique targetOk=$targetOk '
          '(actual hardest=$hardest) replay=${replay.mismatchCount}');
      exit(2);
    }
    reportLines.add(
      '$id|pools/$poolFile(seed=$seed)|$target|$hardest|'
      '${script.stepCount}|trial|回放通过',
    );
  }

  // ---- 3. index.json ----
  final Map<String, Object?> index = _buildIndex(levelJsonById);
  _writeJson('$_outDir/index.json', index);

  // ---- 4. 精选报告 ----
  _writeReport(reportLines, levelJsonById);

  stdout.writeln('完成：${levelJsonById.length} 关已写入 $_outDir，'
      'index 登记 ${index['chapters'] == null ? 0 : ((index['chapters'] as List<Object?>).length)} 章');
}

// ------------------------------------------------------------ 工具

String? _targetOf(String id) {
  // 按 PRD P0-LVL 表返回该关目标技巧；basic = 仅基础技巧。
  const Map<String, String> targets = <String, String>{
    'ch0_l01': 'basic',
    'ch0_l02': 'basic',
    'ch0_l03': 'basic',
    'ch0_l04': 'basic',
    'ch0_l05': 'nakedPair',
    'ch0_l06': 'nakedPair',
    'ch0_l07': 'hiddenPair',
    'ch0_l08': 'hiddenPair',
    'ch0_l09': 'lockedCandidates',
    'ch0_l10': 'lockedCandidates',
    'ch1_l01': 'nakedTriple',
    'ch1_l02': 'hiddenTriple',
    'ch1_l03': 'nakedTriple',
    'ch1_l04': 'hiddenTriple',
    'ch1_l05': 'xWing',
    'ch1_l06': 'xWing',
    'ch2_l01': 'finnedXWing',
    'ch2_l02': 'swordfish',
    'ch2_l03': 'finnedXWing',
    'ch2_l04': 'finnedXWing',
    'ch2_l05': 'swordfish',
    'ch2_l06': 'swordfish',
    'ch3_l01': 'xyWing',
    'ch3_l02': 'xyWing',
    'ch3_l03': 'xyzWing',
    'ch3_l04': 'xyWing',
    'ch3_l05': 'xyWing',
    'ch3_l06': 'xyWing',
    'ch3_l07': 'xyzWing',
    'ch3_l08': 'xyzWing',
    'ch3_l09': 'xyzWing',
  };
  return targets[id] ?? '?';
}

/// 最高阶技巧（techniqueTags 中非基础技巧里 rank 最高者）。
String? _hardest(Set<TechniqueId> tags) {
  int best = -1;
  String? bestId;
  for (final TechniqueId t in tags) {
    if (_base.contains(t.id)) {
      continue;
    }
    if (t.index > best) {
      best = t.index;
      bestId = t.id;
    }
  }
  return bestId;
}

String? _hardestOfScript(SolutionScript script) {
  int best = -1;
  String? bestId;
  for (final ScriptStep step in script.steps) {
    if (_base.contains(step.techniqueId.id)) {
      continue;
    }
    if (step.techniqueId.index > best) {
      best = step.techniqueId.index;
      bestId = step.techniqueId.id;
    }
  }
  return bestId;
}

/// 题面 81 字符串 → givenMask（'1'/'0'）。
String _deriveMask(String puzzle81) => <String>[
      for (final int code in puzzle81.codeUnits)
        (code == '.'.codeUnitAt(0) || code == '0'.codeUnitAt(0)) ? '0' : '1',
    ].join();

/// 读 gz 池，返回 puzzles 列表。
List<Map<String, Object?>> _loadPool(String poolFile) {
  final String text =
      utf8.decode(gzip.decode(File('$_poolDir/$poolFile').readAsBytesSync()));
  final Map<String, Object?> root = (jsonDecode(text) as Map<String, Object?>);
  return <Map<String, Object?>>[
    for (final Object? p
        in (root['puzzles'] as List<Object?>?) ?? const <Object?>[])
      p! as Map<String, Object?>,
  ];
}

/// 用 sudoku_core 逐级求解器生成完整脚本（与 CLI annotate 同口径）。
SolutionScript _solveScript(String puzzle81, String solution81) {
  final Puzzle puzzle = Puzzle(
    given: BoardCodec.decodeValues(puzzle81),
    solution: BoardCodec.decodeValues(solution81),
  );
  final Board board = puzzle.toGivenBoard();
  CandidateCalculator.recomputeAll(board);
  final StepwiseSolveOutcome outcome = StepwiseSolver().solve(
    SolveContext(
      board: board,
      ruleSet: RuleSet.t2(),
      uniqueSolutionGuaranteed: true,
      solution: puzzle.solution,
    ),
  );
  if (!outcome.solved) {
    throw StateError('逐级求解未解出：${outcome.reason.id}');
  }
  return SolutionScript(steps: <ScriptStep>[
    for (final SolveStep step in outcome.steps)
      ScriptStep(
        order: step.order,
        techniqueId: step.techniqueId,
        eliminations: step.result.eliminations,
        placements: step.result.placements,
        involvedCells: step.result.involvedCells(),
        narration: _renderNarration(step.techniqueId, step.result),
        visual: step.result.visual,
      ),
  ]);
}

/// 用 zh_cn_templates 渲染一步旁白（复用候选同款文案源）。
String? _renderNarration(TechniqueId id, TechniqueResult result) {
  final String? pattern = zhCnTemplates[id];
  if (pattern == null) {
    return null;
  }
  return NarrationTemplate(pattern).render(result.narration.slots);
}

void _writeJson(String path, Map<String, Object?> json) {
  File(path).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(json)}\n',
  );
}

/// 深度转换脚本中的教学文本；索引、数字和可视化结构保持原样。
Object? _localizeTeachingText(Object? value) {
  if (value is String) {
    return NarrationFormat.localizeCoordinates(value);
  }
  if (value is List<Object?>) {
    return <Object?>[
      for (final Object? item in value) _localizeTeachingText(item),
    ];
  }
  if (value is Map<String, Object?>) {
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in value.entries)
        entry.key: _localizeTeachingText(entry.value),
    };
  }
  return value;
}

/// 构造 index.json。
Map<String, Object?> _buildIndex(
    Map<String, Map<String, Object?>> levelJsonById) {
  final List<Map<String, Object?>> chapters = <Map<String, Object?>>[];
  for (final int ch in <int>[0, 1, 2, 3]) {
    final List<Map<String, Object?>> levels = <Map<String, Object?>>[
      for (final Map<String, Object?> json in levelJsonById.values)
        if (json['chapter'] == ch) json,
    ]..sort((Map<String, Object?> a, Map<String, Object?> b) =>
        (a['order']! as int).compareTo(b['order']! as int));
    chapters.add(<String, Object?>{
      'chapter': ch,
      'title': _chapterTitle(ch),
      'techniqueTags': _chapterTags(ch),
      'levels': <Map<String, Object?>>[
        for (final Map<String, Object?> lv in levels)
          <String, Object?>{
            'id': lv['id'],
            'chapter': ch,
            'order': lv['order'],
            'kind': lv['kind'],
            'title': lv['title'],
            'techniqueTags': lv['techniqueTags'],
            'file': '${lv['id']}.json',
          },
      ],
    });
  }
  return <String, Object?>{
    'schemaVersion': 1,
    'chapters': chapters,
  };
}

String _chapterTitle(int ch) => switch (ch) {
      0 => '第 0 章 · 规则与基础',
      1 => '第 1 章 · 三数与 X 翼',
      2 => '第 2 章 · 鳍形 X 翼与剑鱼',
      _ => '第 3 章 · XY 翼与 XYZ 翼',
    };

List<String> _chapterTags(int ch) => switch (ch) {
      0 => <String>[
          'nakedSingle',
          'hiddenSingle',
          'nakedPair',
          'hiddenPair',
          'lockedCandidates',
        ],
      1 => <String>['nakedTriple', 'hiddenTriple', 'xWing'],
      2 => <String>['finnedXWing', 'swordfish'],
      _ => <String>['xyWing', 'xyzWing'],
    };

/// 生成精选对齐报告。
void _writeReport(
    List<String> reportLines, Map<String, Map<String, Object?>> levelJsonById) {
  final StringBuffer buf = StringBuffer();
  buf.writeln('# F-5 精选报告（T-CNT-04 + T-CNT-05）');
  buf.writeln();
  buf.writeln('> 生成批次：F-5（寇豆码 / Kou）｜生成时间：2026-08-08');
  buf.writeln(
      '> 说明：31 个非试炼关从 T-CNT-03 每关 6 个候选中精选 1 个；3 个试炼关从 T-CNT-02 题池抽取并用引擎重生成解题脚本。');
  buf.writeln();
  buf.writeln('## 一、34 关精选对齐总表');
  buf.writeln();
  buf.writeln('| 关 | 候选数 | 选定候选 | 目标技巧 | 最高技巧 | 步数 | kind |');
  buf.writeln('|---|---|---|---|---|---|---|');
  for (final String line in reportLines) {
    final List<String> parts = line.split('|');
    buf.writeln('| ${parts[0]} | 6 | ${parts[1]} | ${parts[2]} | ${parts[3]} | '
        '${parts[4]} | ${parts[5]} |');
  }
  buf.writeln();
  buf.writeln('## 二、三处 kind 与 PRD 预期差异说明（以候选现有 kind 为准）');
  buf.writeln();
  buf.writeln('1. `ch0_l03` / `ch0_l04`：PRD 期望「唯一余数/隐性唯一数」为实操（guidedPractice），'
      '但 T-CNT-03 候选全部生成为 demo；按任务指示以候选现有 kind 为准，两关均为 demo。');
  buf.writeln('2. `ch1_l05`：PRD 期望为 X 翼实操，但候选全部为 demo；以候选为准，本关为 demo。'
      '（第 1 章因此为 3 演示 + 3 实操 + 1 试炼。）');
  buf.writeln('3. `ch1_l07` / `ch2_l07` / `ch3_l10`：候选盘面 kind 为 guidedPractice，'
      '但任务要求这三关为试炼关（trial）；不采用候选盘面，改从对应章节题池抽取。');
  buf.writeln();
  buf.writeln('## 三、步数说明');
  buf.writeln();
  buf.writeln('所有候选脚本为 T-CNT-03 生成的完整解题脚本（55~72 步），为保证 ScriptReplayer '
      '终态校验通过（脚本须解满整盘），**未做截断**；各关已在候选中优先选取步数较短者。'
      '「优先步数适中（10~30 步）」在候选产物约束下无法满足，已向主理人报告。');
  buf.writeln();
  buf.writeln('## 四、试炼关来源');
  buf.writeln();
  buf.writeln('| 关 | 池文件 | 池内 seed | 目标技巧 | 生成脚本步数 |');
  buf.writeln('|---|---|---|---|---|');
  for (final List<Object> trial in _trials) {
    final Map<String, Object?> json = levelJsonById[trial[0]]!;
    final Map<String, Object?> script = json['script']! as Map<String, Object?>;
    final Object? rawSteps = script['steps'];
    final int steps = rawSteps is List<Object?> ? rawSteps.length : 0;
    buf.writeln(
        '| ${trial[0]} | pools/${trial[4]} | ${trial[5]} | ${trial[3]} | '
        '$steps |');
  }
  buf.writeln();
  buf.writeln('## 五、产出文件');
  buf.writeln();
  buf.writeln(
      '- 非试炼关：`app/assets/curriculum/ch0_l01.json` ~ `ch3_l09.json`（31 个）');
  buf.writeln(
      '- 试炼关：`app/assets/curriculum/ch1_l07.json` / `ch2_l07.json` / `ch3_l10.json`');
  buf.writeln(
      '- 课程索引：`app/assets/curriculum/index.json`（登记 34 关，`ch0_l01_test` 不再引用）');
  buf.writeln('- 校验脚本：`app/tool/verify_curriculum.dart`');
  File('$_candDir/f5_selection_report.md').writeAsStringSync(buf.toString());
}
