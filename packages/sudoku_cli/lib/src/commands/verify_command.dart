/// `verify` 子命令：题库/关卡 JSON 回放校验（doc 07 T-CLI-03 验收项）。
///
/// 校验内容（**全部驱动 `sudoku_core` 算法，零重新实现**）：
/// 1. 结构/编解码合法性；
/// 2. 唯一解 + 终局解一致性（`UniquenessChecker` + `BacktrackingSolver`）；
/// 3. 标注回放：用 profile 规则集重新逐级求解，比对难度/最高技巧/步数/技巧集合；
/// 4. 脚本回放：按关卡 JSON `script.steps[]` 逐状态推进，用对应识别器
///    `Technique.find` 验证每步标注的删数/填数确实可被识别，并核对
///    `techniqueTags` 与实际使用技巧一致。
///
/// 输出不一致清单，退出码：0=全过；1=存在不一致；2=参数/IO 错误。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sudoku_core/sudoku_core.dart';

import '../config/cli_config.dart';
import '../io/json_writer.dart';
import 'command_base.dart';

/// 一条校验问题。
class VerifyIssue {
  /// 构造问题。
  const VerifyIssue(this.source, this.code, this.message);

  /// 来源标识（文件路径或关卡 id）。
  final String source;

  /// 问题码（形如 `E_VERIFY_001`）。
  final String code;

  /// 可读描述。
  final String message;

  @override
  String toString() => '[不一致] $source $code：$message';
}

/// 关卡/集合回放校验器。
class VerifyCommand extends SudokuCommand {
  /// 构造命令。
  VerifyCommand(super.reporter) {
    argParser
      ..addOption(
        'input',
        abbr: 'i',
        help: '输入文件：题库/集合 JSON 或单关 JSON（.gz 自动解压）',
      )
      ..addOption(
        'dataset',
        help: '输入目录：递归遍历其中 *.json / *.json.gz 逐个校验（T-QA-02 标注集）',
      );
  }

  @override
  String get name => 'verify';

  @override
  String get description =>
      '回放校验题库/关卡 JSON（唯一解 + 标注回放 + 脚本逐级验证）';

  @override
  Future<Object?> run() async {
    final String? input = argResults!['input'] as String?;
    final String? dataset = argResults!['dataset'] as String?;
    if ((input == null || input.isEmpty) && (dataset == null || dataset.isEmpty)) {
      throw UsageException('--input <file> 或 --dataset <dir> 至少提供一个', usage);
    }
    final ProfileSpec profile = profileValue();
    final TechniqueRegistry registry = TechniqueRegistry.defaults();

    final List<VerifyIssue> issues = <VerifyIssue>[];
    int checked = 0;

    if (input != null && input.isNotEmpty) {
      final String path = resolvePath(input);
      checked += _verifyFile(path, profile, registry, issues);
    }
    if (dataset != null && dataset.isNotEmpty) {
      final String dir = resolvePath(dataset);
      if (!Directory(dir).existsSync()) {
        reporter.error('--dataset 目录不存在：$dir');
        return 2;
      }
      final List<File> files = Directory(dir)
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) =>
              f.path.toLowerCase().endsWith('.json') ||
              f.path.toLowerCase().endsWith('.gz'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
      for (final File file in files) {
        checked += _verifyFile(file.path, profile, registry, issues);
      }
    }

    reporter.section('verify 结果');
    reporter.info('  校验文件/条目数 : $checked');
    reporter.info('  不一致数       : ${issues.length}');
    if (issues.isNotEmpty) {
      reporter.section('不一致清单');
      for (final VerifyIssue issue in issues) {
        reporter.error(issue.toString());
      }
      return 1;
    }
    reporter.info('全部通过 ✅');
    return 0;
  }

  /// 校验单个文件；返回其中校验的条目数（集合取题数，单关取 1）。
  int _verifyFile(
    String path,
    ProfileSpec profile,
    TechniqueRegistry registry,
    List<VerifyIssue> issues,
  ) {
    final Map<String, Object?> root;
    try {
      root = JsonWriter.readJsonMap(path);
    } on CliIoException catch (e) {
      issues.add(VerifyIssue(path, 'E_VERIFY_001', '读取失败：${e.message}'));
      return 1;
    }
    final String source = p.basename(path);

    if (root.containsKey('puzzles') && root['puzzles'] is List<Object?>) {
      // 题库/集合形态。
      final List<Object?> rawPuzzles = root['puzzles'] as List<Object?>;
      int checked = 0;
      for (final Object? raw in rawPuzzles) {
        if (raw is! Map<String, Object?>) {
          issues.add(VerifyIssue(source, 'E_VERIFY_002', 'puzzles[] 存在非对象条目'));
          continue;
        }
        final String itemSource = '$source#${checked + 1}';
        _verifyPuzzleItem(
          itemSource,
          raw,
          profile,
          registry,
          issues,
        );
        checked++;
      }
      return checked;
    }

    if (root.containsKey('puzzle81')) {
      // 单关形态。
      _verifyLevelItem(source, root, profile, registry, issues);
      return 1;
    }

    issues.add(VerifyIssue(source, 'E_VERIFY_002', '既不是集合也不是单关 JSON'));
    return 1;
  }

  // ------------------------------------------------------------ 集合条目

  void _verifyPuzzleItem(
    String source,
    Map<String, Object?> item,
    ProfileSpec profile,
    TechniqueRegistry registry,
    List<VerifyIssue> issues,
  ) {
    final String? puzzle81 = item['puzzle81'] as String?;
    final String? solution81 = item['solution81'] as String?;
    if (puzzle81 == null || solution81 == null) {
      issues.add(VerifyIssue(source, 'E_VERIFY_003', '缺少 puzzle81/solution81'));
      return;
    }
    final Board? board = _decodeBoard(source, puzzle81, solution81, issues);
    if (board == null) {
      return;
    }

    _verifyUniquenessAndSolution(source, board, solution81, issues);
    _verifyAnnotationReplay(source, board, solution81, item, profile, issues);

    final List<Object?>? rawScript = item['script'] as List<Object?>?;
    if (rawScript != null && rawScript.isNotEmpty) {
      _verifyScriptReplay(
        source,
        board,
        solution81,
        rawScript,
        levelFormat: false,
        techniqueTags: null,
        profile: profile,
        registry: registry,
        issues: issues,
      );
    }
  }

  // ------------------------------------------------------------ 单关

  void _verifyLevelItem(
    String source,
    Map<String, Object?> root,
    ProfileSpec profile,
    TechniqueRegistry registry,
    List<VerifyIssue> issues,
  ) {
    final String? puzzle81 = root['puzzle81'] as String?;
    final String? solution81 = root['solution81'] as String?;
    if (puzzle81 == null || solution81 == null) {
      issues.add(VerifyIssue(source, 'E_VERIFY_003', '缺少 puzzle81/solution81'));
      return;
    }
    final Board? board = _decodeBoard(source, puzzle81, solution81, issues);
    if (board == null) {
      return;
    }
    _verifyUniquenessAndSolution(source, board, solution81, issues);

    // 单关标注回放：techniqueTags 与实际脚本技巧比对（回放时收集）。
    final Object? rawScript = root['script'];
    if (rawScript is Map<String, Object?> && rawScript['steps'] is List<Object?>) {
      final Set<TechniqueId> tags = <TechniqueId>{
        for (final Object? tag in (root['techniqueTags'] as List<Object?>?) ??
            const <Object?>[])
          TechniqueId.tryParse(tag! as String) ?? TechniqueId.nakedSingle,
      };
      _verifyScriptReplay(
        source,
        board,
        solution81,
        rawScript['steps'] as List<Object?>,
        levelFormat: true,
        techniqueTags: tags,
        profile: profile,
        registry: registry,
        issues: issues,
      );
    }
  }

  // ------------------------------------------------------------ 公共校验

  Board? _decodeBoard(
    String source,
    String puzzle81,
    String solution81,
    List<VerifyIssue> issues,
  ) {
    try {
      if (BoardCodec.decodeValues(puzzle81).length != 81 ||
          BoardCodec.decodeValues(solution81).length != 81) {
        issues.add(VerifyIssue(source, 'E_VERIFY_004', '81 字符串长度非法'));
        return null;
      }
      final List<int> given = BoardCodec.decodeValues(puzzle81);
      final List<int> solution = BoardCodec.decodeValues(solution81);
      if (!Validator.isValidSolution(solution)) {
        issues.add(VerifyIssue(source, 'E_VERIFY_005', '终局解非法（含冲突）'));
        return null;
      }
      final Board board = Board.fromValues(given, givenMask: <bool>[
        for (final int v in given) v != kEmptyValue,
      ]);
      CandidateCalculator.recomputeAll(board);
      if (!Validator.isConsistent(board)) {
        issues.add(VerifyIssue(source, 'E_VERIFY_006', '题面自相矛盾'));
        return null;
      }
      return board;
    } on Object catch (e) {
      issues.add(VerifyIssue(source, 'E_VERIFY_004', '题面解析失败：$e'));
      return null;
    }
  }

  void _verifyUniquenessAndSolution(
    String source,
    Board board,
    String solution81,
    List<VerifyIssue> issues,
  ) {
    if (!const UniquenessChecker().isUnique(board)) {
      issues.add(VerifyIssue(source, 'E_VERIFY_007', '非唯一解（题库必须唯一解）'));
      return;
    }
    final List<int>? solved = const BacktrackingSolver().solveFirst(board);
    if (solved == null) {
      issues.add(VerifyIssue(source, 'E_VERIFY_008', '回溯求解失败（应可解）'));
      return;
    }
    if (solved.join() != solution81) {
      issues.add(VerifyIssue(source, 'E_VERIFY_009',
          '终局解与回溯解不一致：标注 ${solution81.substring(0, 9)}… 实际 ${solved.join().substring(0, 9)}…'));
    }
  }

  /// 标注回放：重新逐级求解，比对难度/最高技巧/步数/技巧集合。
  void _verifyAnnotationReplay(
    String source,
    Board board,
    String solution81,
    Map<String, Object?> item,
    ProfileSpec profile,
    List<VerifyIssue> issues,
  ) {
    final List<int> solution = BoardCodec.decodeValues(solution81);
    final StepwiseSolveOutcome outcome = StepwiseSolver().solve(
      SolveContext(
        board: board,
        ruleSet: profile.ruleSet,
        uniqueSolutionGuaranteed: true,
        solution: solution,
      ),
    );
    if (!outcome.solved) {
      issues.add(VerifyIssue(source, 'E_VERIFY_010',
          '当前 profile 下纯逻辑不可解（若标注为已解，标注与规则集矛盾）'));
      return;
    }
    final GradingReport report = DifficultyGrader.fromOutcome(outcome);

    final String? annotatedDifficulty = item['difficulty'] as String?;
    if (annotatedDifficulty != null &&
        Difficulty.tryParse(annotatedDifficulty) != report.difficulty) {
      issues.add(VerifyIssue(source, 'E_VERIFY_011',
          '难度标注 $annotatedDifficulty ≠ 回放 ${report.difficulty.id}'));
    }

    final String? annotatedHardest = item['hardestTechnique'] as String?;
    if (annotatedHardest != null &&
        annotatedHardest != report.hardestTechnique?.id) {
      issues.add(VerifyIssue(source, 'E_VERIFY_012',
          '最高技巧标注 $annotatedHardest ≠ 回放 ${report.hardestTechnique?.id ?? '-'}'));
    }

    final int? annotatedSteps = item['stepCount'] as int?;
    if (annotatedSteps != null && annotatedSteps != report.stepCount) {
      issues.add(VerifyIssue(source, 'E_VERIFY_013',
          '步数标注 $annotatedSteps ≠ 回放 ${report.stepCount}'));
    }

    final Set<String> annotatedTechs = <String>{
      for (final Object? v in (item['techniques'] as List<Object?>?) ??
          const <Object?>[])
        v! as String,
    };
    if (annotatedTechs.isNotEmpty) {
      final Set<String> replayedTechs = <String>{
        for (final TechniqueId id in report.usedTechniques) id.id,
      };
      if (annotatedTechs.length != replayedTechs.length ||
          !annotatedTechs.containsAll(replayedTechs)) {
        issues.add(VerifyIssue(source, 'E_VERIFY_014',
            '技巧集合标注 ${annotatedTechs.join(",")} ≠ 回放 ${replayedTechs.join(",")}'));
      }
    }
  }

  /// 脚本回放：逐状态推进，用识别器验证每步标注结论。
  void _verifyScriptReplay(
    String source,
    Board board,
    String solution81,
    List<Object?> rawSteps, {
    required bool levelFormat,
    Set<TechniqueId>? techniqueTags,
    required ProfileSpec profile,
    required TechniqueRegistry registry,
    required List<VerifyIssue> issues,
  }) {
    final List<int> solution = BoardCodec.decodeValues(solution81);
    Board state = board.snapshot();
    final Set<TechniqueId> usedTechniques = <TechniqueId>{};

    for (final Object? rawStep in rawSteps) {
      if (rawStep is! Map<String, Object?>) {
        issues.add(VerifyIssue(source, 'E_VERIFY_020', 'script.steps[] 非对象'));
        continue;
      }
      final int order = (rawStep['order'] as int?) ?? -1;
      final String techId = rawStep['techniqueId'] as String? ?? '';
      final TechniqueId? technique = TechniqueId.tryParse(techId);
      if (technique == null) {
        issues.add(VerifyIssue(source, 'E_VERIFY_021',
            '第 $order 步未知技巧 id「$techId」'));
        continue;
      }
      if (!profile.ruleSet.allows(technique)) {
        issues.add(VerifyIssue(source, 'E_VERIFY_022',
            '第 $order 步技巧 ${technique.id} 不在当前规则集内'));
        continue;
      }
      usedTechniques.add(technique);

      final (List<(int, int)>, List<(int, int)>) parsed = _parseStepConclusions(
        rawStep,
        levelFormat: levelFormat,
        source: source,
        order: order,
        issues: issues,
      );
      final List<(int, int)> elims = parsed.$1;
      final List<(int, int)> placements = parsed.$2;

      // 1) 识别器确认标注结论。
      final Technique recognizer = registry.byId(technique);
      final SolveContext ctx = SolveContext(
        board: state,
        ruleSet: profile.ruleSet,
        uniqueSolutionGuaranteed: true,
        solution: solution,
      );
      final List<TechniqueResult> hits =
          recognizer.find(ctx, limit: 64).toList();
      for (final (int cell, int digit) in elims) {
        final bool confirmed = hits.any((TechniqueResult r) => r.eliminations
            .any((Elimination e) => e.cellIndex == cell && e.digit == digit));
        if (!confirmed) {
          issues.add(VerifyIssue(source, 'E_VERIFY_023',
              '第 $order 步 ${technique.id}：识别器无法确认删数 '
              '${Coord.label(cell)} 的 $digit'));
        }
      }
      for (final (int cell, int digit) in placements) {
        final bool confirmed = hits.any((TechniqueResult r) => r.placements
            .any((Placement pl) => pl.cellIndex == cell && pl.digit == digit));
        if (!confirmed) {
          issues.add(VerifyIssue(source, 'E_VERIFY_024',
              '第 $order 步 ${technique.id}：识别器无法确认填数 '
              '${Coord.label(cell)} 填 $digit'));
        }
      }

      // 2) 应用步骤，推进状态。
      for (final (int cell, int digit) in elims) {
        if (state.isBlank(cell) && state.candidatesAt(cell).contains(digit)) {
          state.eliminate(cell, digit);
        } else {
          issues.add(VerifyIssue(source, 'E_VERIFY_025',
              '第 $order 步删数无法应用：${Coord.label(cell)} 的 $digit'
              '（候选不存在或格已填）'));
        }
      }
      for (final (int cell, int digit) in placements) {
        if (!state.isBlank(cell)) {
          issues.add(VerifyIssue(source, 'E_VERIFY_026',
              '第 $order 步填数无法应用：${Coord.label(cell)} 已填'));
          continue;
        }
        if (state.isGiven(cell)) {
          issues.add(VerifyIssue(source, 'E_VERIFY_027',
              '第 $order 步试图改写给定格 ${Coord.label(cell)}'));
          continue;
        }
        state.forceSetValue(cell, digit);
        CandidateCalculator.syncAfterPlace(state, cell, digit);
      }
    }

    // 3) 终态检查：填满且与终局解一致。
    if (!state.isFull) {
      issues.add(VerifyIssue(source, 'E_VERIFY_028',
          '脚本未解满盘面（剩 ${state.blankCount()} 格）'));
    } else if (state.toPuzzleString() != solution81) {
      issues.add(VerifyIssue(source, 'E_VERIFY_029', '脚本终态与终局解不一致'));
    }

    // 4) techniqueTags 与脚本实际使用技巧核对。
    if (techniqueTags != null && techniqueTags.isNotEmpty) {
      final Set<TechniqueId> expected =
          techniqueTags.difference(usedTechniques);
      if (expected.isNotEmpty) {
        issues.add(VerifyIssue(source, 'E_VERIFY_030',
            'techniqueTags 含脚本未使用的技巧：'
            '${expected.map((TechniqueId id) => id.id).join(",")}'));
      }
    }
  }

  /// 解析一步脚本的删数/填数结论（兼容集合 `cellIndex` 与关卡 `cell` 字段）。
  (List<(int, int)>, List<(int, int)>) _parseStepConclusions(
    Map<String, Object?> rawStep, {
    required bool levelFormat,
    required String source,
    required int order,
    required List<VerifyIssue> issues,
  }) {
    final List<(int, int)> elims = <(int, int)>[];
    final List<(int, int)> placements = <(int, int)>[];

    void parseList(String key, List<(int, int)> into) {
      for (final Object? item in (rawStep[key] as List<Object?>?) ??
          const <Object?>[]) {
        if (item is! Map<String, Object?>) {
          issues.add(VerifyIssue(source, 'E_VERIFY_020',
              '第 $order 步 $key[] 存在非对象条目'));
          continue;
        }
        final String cellKey = levelFormat ? 'cell' : 'cellIndex';
        final Object? rawCell = item[cellKey] ?? item['cell'] ?? item['cellIndex'];
        final int? cell = rawCell is int ? rawCell : null;
        final Object? rawDigit = item['digit'];
        final int? digit = rawDigit is int ? rawDigit : null;
        if (cell == null || digit == null) {
          issues.add(VerifyIssue(source, 'E_VERIFY_020',
              '第 $order 步 $key 缺少 cell/digit 字段'));
          continue;
        }
        into.add((cell, digit));
      }
    }

    parseList('eliminations', elims);
    parseList('placements', placements);
    return (elims, placements);
  }
}
