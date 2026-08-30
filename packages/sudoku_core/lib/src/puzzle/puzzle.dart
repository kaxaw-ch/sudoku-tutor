/// 题目模型（题面 / givenMask / 终局解 / 技巧标签 / 难度 / 指纹）。
///
/// ⚠️ 归属说明：doc 06 §3.1 将本文件列在 `puzzle/` 目录、doc 07 归入
/// **批次 C 的 T-CORE-09**。此处提前落地**值对象本体**（不含 JSON codec、
/// 解题脚本与关卡模型），原因是批次 B 的 `engine/generator.dart`
/// 按 doc 07 T-CORE-03 需要「产出 `Puzzle{given, solution}`」。
/// 批次 C 只需在同目录补 `puzzle_codec.dart` 等文件，无需改动本类。
library;

import 'package:meta/meta.dart';

import '../grading/difficulty.dart';
import '../model/board.dart';
import '../model/coord.dart';
import '../model/digit.dart';
import '../techniques/technique_id.dart';
import '../util/core_error.dart';
import '../util/fingerprint.dart';
import 'solution_script.dart';

/// 一道题目：题面 + 终局解 + 标注信息。
@immutable
class Puzzle {
  /// 构造一道题目。
  ///
  /// - [given] 为题面（未填格为 0），[solution] 为 81 个 1..9 的终局解；
  /// - [difficulty] / [techniques] / [seed] 为标注信息，生成阶段可缺省；
  /// - [fingerprint] 省略时按题面自动计算规范化指纹（同构去重用）。
  Puzzle({
    required List<int> given,
    required List<int> solution,
    List<bool>? givenMask,
    this.difficulty,
    Set<TechniqueId> techniques = const <TechniqueId>{},
    this.seed,
    String? fingerprint,
  })  : given = List<int>.unmodifiable(_checkGiven(given)),
        solution = List<int>.unmodifiable(_checkSolution(solution)),
        givenMask = List<bool>.unmodifiable(
          givenMask ?? <bool>[for (final int v in given) v != kEmptyValue],
        ),
        techniques = Set<TechniqueId>.unmodifiable(techniques),
        fingerprint = fingerprint ?? Fingerprint.ofValues(given);

  /// 由题面盘面与终局解盘面构造。
  factory Puzzle.fromBoards({
    required Board given,
    required Board solution,
    Difficulty? difficulty,
    Set<TechniqueId> techniques = const <TechniqueId>{},
    int? seed,
  }) =>
      Puzzle(
        given: given.toValueList(),
        solution: solution.toValueList(),
        givenMask: List<bool>.of(given.givenMask),
        difficulty: difficulty,
        techniques: techniques,
        seed: seed,
      );

  /// 题面 81 格值（0 = 空）。
  final List<int> given;

  /// 终局解 81 格值（全部 1..9）。
  final List<int> solution;

  /// 原始题面给定掩码（PRD C-11，全链路携带）。
  final List<bool> givenMask;

  /// 难度档；未标注时为 `null`。
  final Difficulty? difficulty;

  /// 解题过程中出现的技巧标签；未标注时为空集合。
  final Set<TechniqueId> techniques;

  /// 生成本题所用的随机种子；便于复现（未记录时为 `null`）。
  final int? seed;

  /// 规范化指纹（同构去重用）。
  final String fingerprint;

  /// 题面提示数个数。
  int get givenCount {
    int count = 0;
    for (final int value in given) {
      if (value != kEmptyValue) {
        count++;
      }
    }
    return count;
  }

  /// 空格个数。
  int get blankCount => kCellCount - givenCount;

  /// 题面 81 字符串（空格用 `.`）。
  String get givenString => <String>[
        for (final int v in given) Digit.charOf(v),
      ].join();

  /// 终局解 81 字符串。
  String get solutionString => solution.join();

  /// 生成一个可对局的题面盘面（`givenMask` 已固化）。
  Board toGivenBoard() => Board.fromValues(given, givenMask: givenMask);

  /// 生成终局解盘面（全部标记为给定，只读用途）。
  Board toSolutionBoard() => Board.fromValues(solution);

  /// 返回替换部分标注字段后的副本。
  Puzzle copyWith({
    Difficulty? difficulty,
    Set<TechniqueId>? techniques,
    int? seed,
  }) =>
      Puzzle(
        given: given,
        solution: solution,
        givenMask: givenMask,
        difficulty: difficulty ?? this.difficulty,
        techniques: techniques ?? this.techniques,
        seed: seed ?? this.seed,
        fingerprint: fingerprint,
      );

  static List<int> _checkGiven(List<int> values) {
    if (values.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        'given 长度 ${values.length}，期望 $kCellCount',
      );
    }
    for (int i = 0; i < kCellCount; i++) {
      if (!Digit.isValidValue(values[i])) {
        throw CoreException(CoreErrorCode.boardIndexRange, 'given[$i]=${values[i]}');
      }
    }
    return values;
  }

  static List<int> _checkSolution(List<int> values) {
    if (values.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        'solution 长度 ${values.length}，期望 $kCellCount',
      );
    }
    for (int i = 0; i < kCellCount; i++) {
      if (!Digit.isValid(values[i])) {
        throw CoreException(
          CoreErrorCode.boardIndexRange,
          'solution[$i]=${values[i]} 必须为 1..9',
        );
      }
    }
    return values;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Puzzle &&
          other.givenString == givenString &&
          other.solutionString == solutionString);

  @override
  int get hashCode => Object.hash(givenString, solutionString);

  @override
  String toString() =>
      'Puzzle(givens=$givenCount, difficulty=${difficulty?.id ?? "-"}, '
      'seed=${seed ?? "-"})';
}

/// 关卡/题库条目模型（T-CORE-09）：题面81 + 终局解81 + 标注 + 解题脚本。
///
/// ⚠️ 字段与 CLI 侧 `AnnotatedPuzzle`（批次 D，权威产出格式）逐一对齐：
/// `puzzle81` / `solution81` / `givenMask`(81 字符 '1'/'0') / `seed` / `fingerprint` /
/// `difficulty` / `hardestTechnique` / `stepCount` / `techniques` / `usageCounts` / `script`。
///
/// 区别与分工：
/// - [Puzzle] 是**引擎内部值对象**（`List<int>` 值数组，供求解/生成直接使用）；
/// - [LevelPuzzle] 是**传输/存储模型**（81 字符串 + 标注 + 脚本），JSON 编解码
///   在 `puzzle_codec.dart`，两者可互相转换（见 [fromCore]/[toCore]）。
///
/// 本类不依赖任何算法：校验只做字符串长度/字符合法性，数值口径与 [Puzzle] 一致。
class LevelPuzzle {
  /// 构造关卡题目条目。
  ///
  /// - [puzzle81] 题面 81 字符（`.`/`0` = 空），[solution81] 终局解 81 字符（1..9）；
  /// - [givenMask] 81 字符 '1'/'0'，省略时按题面推导；
  /// - [techniques]/[usageCounts] 为标注信息，可缺省；
  /// - [script] 解题脚本，自由练习题库通常不带（体积考虑）。
  LevelPuzzle({
    required String puzzle81,
    required String solution81,
    String? givenMask,
    this.seed = 0,
    this.fingerprint = '',
    this.difficulty,
    this.hardestTechnique,
    this.stepCount = 0,
    Set<TechniqueId> techniques = const <TechniqueId>{},
    Map<TechniqueId, int> usageCounts = const <TechniqueId, int>{},
    this.script,
  })  : puzzle81 = _check81(puzzle81, 'puzzle81'),
        solution81 = _check81(solution81, 'solution81'),
        givenMask = givenMask == null ? null : _checkMask(givenMask),
        techniques = Set<TechniqueId>.unmodifiable(techniques),
        usageCounts = Map<TechniqueId, int>.unmodifiable(usageCounts);

  /// 题面 81 字符串（空格用 `.`）。
  final String puzzle81;

  /// 终局解 81 字符串。
  final String solution81;

  /// 原始题面给定掩码（81 字符 '1'/'0'）；为 `null` 时按题面推导。
  final String? givenMask;

  /// 生成本题的随机种子（可复现）。
  final int seed;

  /// 规范化指纹（同构去重用，来自 [Fingerprint]）。
  final String fingerprint;

  /// 评定难度档（未标注时为 `null`）。
  final Difficulty? difficulty;

  /// 用到的最难技巧（未标注时为 `null`）。
  final TechniqueId? hardestTechnique;

  /// 逐级求解步数。
  final int stepCount;

  /// 用到的全部技巧（rank 升序去重）。
  final Set<TechniqueId> techniques;

  /// 各技巧使用次数（rank 升序）。
  final Map<TechniqueId, int> usageCounts;

  /// 解题脚本（标注后才有；`null` 表示未标注/未携带）。
  final SolutionScript? script;

  /// 是否已标注（难度 + 脚本）。
  bool get isAnnotated => difficulty != null && script != null && script!.isNotEmpty;

  /// 题面提示数。
  int get givenCount {
    int count = 0;
    for (final int code in puzzle81.codeUnits) {
      if (code != kEmptyChar.codeUnitAt(0) && code != '0'.codeUnitAt(0)) {
        count++;
      }
    }
    return count;
  }

  /// 空格个数。
  int get blankCount => kCellCount - givenCount;

  /// 由引擎 [Puzzle] 转换（标注字段透传；[script] 需单独装配）。
  factory LevelPuzzle.fromCore(
    Puzzle puzzle, {
    int seed = 0,
    String? fingerprint,
    int stepCount = 0,
    Map<TechniqueId, int>? usageCounts,
    SolutionScript? script,
  }) =>
      LevelPuzzle(
        puzzle81: puzzle.givenString,
        solution81: puzzle.solutionString,
        givenMask: puzzle.toGivenBoard().toGivenMaskString(),
        seed: seed,
        fingerprint: fingerprint ?? puzzle.fingerprint,
        difficulty: puzzle.difficulty,
        hardestTechnique: null,
        stepCount: stepCount,
        techniques: puzzle.techniques,
        usageCounts: usageCounts ?? const <TechniqueId, int>{},
        script: script,
      );

  /// 转回引擎 [Puzzle]（校验题面与终局解兼容；不可兼容时抛 [CoreException]）。
  Puzzle toCore() {
    final List<int> given = _decode(puzzle81);
    final List<int> solution = _decode(solution81);
    return Puzzle(
      given: given,
      solution: solution,
      givenMask: _decodeMask(),
      difficulty: difficulty,
      techniques: techniques,
      seed: seed == 0 ? null : seed,
      fingerprint: fingerprint,
    );
  }

  /// 显式给定掩码列表（按 [givenMask] 或题面推导）。
  List<bool> _decodeMask() {
    final String? raw = givenMask;
    if (raw != null) {
      if (raw.length != kCellCount) {
        throw CoreException(
          CoreErrorCode.boardStringLength,
          'givenMask 长度 ${raw.length}，期望 $kCellCount',
        );
      }
      return <bool>[
        for (final int code in raw.codeUnits) code == '1'.codeUnitAt(0),
      ];
    }
    return <bool>[for (final int v in _decode(puzzle81)) v != kEmptyValue];
  }

  @override
  String toString() =>
      'LevelPuzzle(givens=$givenCount, difficulty=${difficulty?.id ?? "-"}, '
      'steps=$stepCount, seed=$seed)';

  static List<int> _decode(String s81) {
    if (s81.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        '81 字符串长度 ${s81.length}，期望 $kCellCount',
      );
    }
    final List<int> values = <int>[];
    for (final int code in s81.codeUnits) {
      // 空字符双兼容：'.'（CLI 产物）与 '0'（导入/经典题面）。
      if (code == kEmptyChar.codeUnitAt(0) || code == '0'.codeUnitAt(0)) {
        values.add(kEmptyValue);
      } else {
        final int value = code - '0'.codeUnitAt(0);
        if (value < 1 || value > 9) {
          throw CoreException(
            CoreErrorCode.boardStringChar,
            '81 字符串含非法字符「${String.fromCharCode(code)}」',
          );
        }
        values.add(value);
      }
    }
    return values;
  }

  static String _check81(String s81, String field) {
    _decode(s81);
    return s81;
  }

  static String _checkMask(String mask) {
    if (mask.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        'givenMask 长度 ${mask.length}，期望 $kCellCount',
      );
    }
    for (final int code in mask.codeUnits) {
      if (code != '0'.codeUnitAt(0) && code != '1'.codeUnitAt(0)) {
        throw CoreException(
          CoreErrorCode.boardStringChar,
          'givenMask 含非法字符「${String.fromCharCode(code)}」',
        );
      }
    }
    return mask;
  }
}
