/// 9×9 盘面模型：`values` + `givenMask` + `candidates`。
///
/// 设计要点（架构文档 §4.1、PRD C-11）：
/// - `givenMask` 记录**原始题面提示格**，永不随玩家操作变化，
///   唯一矩形族（UR）与 W 翼判定强依赖此掩码，全链路（生成/求解/提示/回放）携带；
/// - 候选集以 9 位掩码存于 [Uint16List]，读写 O(1)；
/// - 本类只做**数据表达**，不含任何推理规则；候选同步、冲突检测等由 `engine` 层负责。
library;

import 'dart:typed_data';

import '../util/core_error.dart';
import 'candidate_set.dart';
import 'cell.dart';
import 'coord.dart';
import 'digit.dart';

/// 9×9 数独盘面（可变）。
///
/// 需要不可变快照时使用 [snapshot] / [clone]（二者等价，深拷贝）。
class Board {
  Board._(this.values, this.givenMask, this.candidateMasks);

  /// 构造一个全空盘面（无给定格、无候选）。
  factory Board.empty() => Board._(
        Int8List(kCellCount),
        List<bool>.filled(kCellCount, false),
        Uint16List(kCellCount),
      );

  /// 由 81 字符串构造盘面。
  ///
  /// - 允许的空格字符：`.`、`0`、空格、`_`、`*`；
  /// - 会自动剔除换行、制表符与竖线（便于粘贴多行文本）；
  /// - [markGivens] 为 true 时，所有非空格自动标记为题面给定格；
  /// - 长度非 81 抛 `E_BOARD_001`，含非法字符抛 `E_BOARD_002`。
  factory Board.fromPuzzleString(String s81, {bool markGivens = true}) {
    final String cleaned = s81.replaceAll(RegExp(r'[\s|\-+]'), '');
    if (cleaned.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        '有效字符数 ${cleaned.length}，期望 $kCellCount',
      );
    }
    final Int8List values = Int8List(kCellCount);
    final List<bool> givens = List<bool>.filled(kCellCount, false);
    for (int i = 0; i < kCellCount; i++) {
      final int value = Digit.parseChar(cleaned[i]);
      values[i] = value;
      givens[i] = markGivens && value != kEmptyValue;
    }
    return Board._(values, givens, Uint16List(kCellCount));
  }

  /// 由数值列表构造盘面。
  ///
  /// [values] 长度必须为 81；[givenMask] 省略时按「非空即给定」推断。
  factory Board.fromValues(List<int> values, {List<bool>? givenMask}) {
    if (values.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        'values 长度 ${values.length}，期望 $kCellCount',
      );
    }
    if (givenMask != null && givenMask.length != kCellCount) {
      throw CoreException(
        CoreErrorCode.boardStringLength,
        'givenMask 长度 ${givenMask.length}，期望 $kCellCount',
      );
    }
    final Int8List store = Int8List(kCellCount);
    final List<bool> givens = List<bool>.filled(kCellCount, false);
    for (int i = 0; i < kCellCount; i++) {
      final int value = values[i];
      if (!Digit.isValidValue(value)) {
        throw CoreException(CoreErrorCode.boardIndexRange, 'values[$i]=$value 超出 0..9');
      }
      store[i] = value;
      givens[i] = givenMask != null ? givenMask[i] : value != kEmptyValue;
    }
    return Board._(store, givens, Uint16List(kCellCount));
  }

  /// 81 格当前值，0 表示空。
  final Int8List values;

  /// 81 格的原始题面给定掩码（PRD C-11，永不随玩家操作变化）。
  final List<bool> givenMask;

  /// 81 格的候选位掩码（低 9 位，`1 << (d - 1)`）。
  final Uint16List candidateMasks;

  // ---------------------------------------------------------------- 读取

  /// 取格 [index] 的值。
  int valueAt(int index) {
    Coord.requireIndex(index);
    return values[index];
  }

  /// 取第 [row] 行第 [col] 列的值。
  int valueAtRc(int row, int col) => valueAt(Coord.indexOf(row, col));

  /// 格 [index] 是否为题面给定格。
  bool isGiven(int index) {
    Coord.requireIndex(index);
    return givenMask[index];
  }

  /// 格 [index] 是否已填数。
  bool isFilled(int index) => valueAt(index) != kEmptyValue;

  /// 格 [index] 是否为空。
  bool isBlank(int index) => valueAt(index) == kEmptyValue;

  /// 取格 [index] 的候选集。
  CandidateSet candidatesAt(int index) {
    Coord.requireIndex(index);
    return CandidateSet(candidateMasks[index]);
  }

  /// 取格 [index] 的只读视图。
  Cell cellAtIndex(int index) => Cell(
        index: index,
        value: valueAt(index),
        isGiven: isGiven(index),
        candidates: candidatesAt(index),
      );

  /// 取第 [row] 行第 [col] 列的只读视图。
  Cell cellAt(int row, int col) => cellAtIndex(Coord.indexOf(row, col));

  /// 第 [row] 行的 9 个值。
  List<int> rowValues(int row) {
    Coord.requireUnitId(row);
    return <int>[for (final int i in Coord.cellsOfRow(row)) values[i]];
  }

  /// 第 [col] 列的 9 个值。
  List<int> colValues(int col) {
    Coord.requireUnitId(col);
    return <int>[for (final int i in Coord.cellsOfCol(col)) values[i]];
  }

  /// 第 [box] 宫的 9 个值。
  List<int> boxValues(int box) {
    Coord.requireUnitId(box);
    return <int>[for (final int i in Coord.cellsOfBox(box)) values[i]];
  }

  /// 已填格数量。
  int filledCount() {
    int count = 0;
    for (int i = 0; i < kCellCount; i++) {
      if (values[i] != kEmptyValue) {
        count++;
      }
    }
    return count;
  }

  /// 空格数量。
  int blankCount() => kCellCount - filledCount();

  /// 题面给定格数量。
  int givenCount() {
    int count = 0;
    for (int i = 0; i < kCellCount; i++) {
      if (givenMask[i]) {
        count++;
      }
    }
    return count;
  }

  /// 81 格是否全部填满（不校验合法性，合法性见 `Validator`）。
  bool get isFull => filledCount() == kCellCount;

  /// 全部空格索引（升序）。
  List<int> blankCells() {
    final List<int> result = <int>[];
    for (int i = 0; i < kCellCount; i++) {
      if (values[i] == kEmptyValue) {
        result.add(i);
      }
    }
    return result;
  }

  /// 当前盘面上候选集中含有 [digit] 的空格索引（升序）。
  List<int> cellsWithCandidate(int digit) {
    Digit.requireDigit(digit);
    final int bit = 1 << (digit - 1);
    final List<int> result = <int>[];
    for (int i = 0; i < kCellCount; i++) {
      if (values[i] == kEmptyValue && (candidateMasks[i] & bit) != 0) {
        result.add(i);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------- 写入

  /// 在格 [index] 填入数字 [digit]，并清空该格候选。
  ///
  /// ⚠️ 只处理本格；同行/列/宫的候选同步由 `CandidateCalculator.syncAfterPlace` 负责。
  /// 对题面给定格写入会抛 `E_BOARD_004`。
  void place(int index, int digit) {
    Coord.requireIndex(index);
    Digit.requireDigit(digit);
    if (givenMask[index]) {
      throw CoreException(CoreErrorCode.boardGivenImmutable, '给定格 ${Coord.label(index)}');
    }
    values[index] = digit;
    candidateMasks[index] = 0;
  }

  /// 清除格 [index] 的填数。
  ///
  /// ⚠️ 只处理本格；候选恢复由 `CandidateCalculator.syncAfterClear` 负责。
  /// 对题面给定格清除会抛 `E_BOARD_004`。
  void clear(int index) {
    Coord.requireIndex(index);
    if (givenMask[index]) {
      throw CoreException(CoreErrorCode.boardGivenImmutable, '给定格 ${Coord.label(index)}');
    }
    values[index] = kEmptyValue;
  }

  /// 强制写入格 [index] 的值（**绕过给定格保护**）。
  ///
  /// 仅供引擎内部（求解器、生成器、撤销回滚）使用，业务代码请用 [place] / [clear]。
  void forceSetValue(int index, int value) {
    Coord.requireIndex(index);
    if (!Digit.isValidValue(value)) {
      throw CoreException(CoreErrorCode.boardIndexRange, 'value=$value 超出 0..9');
    }
    values[index] = value;
  }

  /// 从格 [index] 的候选集中删除 [digit]。
  void eliminate(int index, int digit) {
    Coord.requireIndex(index);
    Digit.requireDigit(digit);
    candidateMasks[index] &= ~(1 << (digit - 1));
  }

  /// 向格 [index] 的候选集中加入 [digit]。
  void addCandidate(int index, int digit) {
    Coord.requireIndex(index);
    Digit.requireDigit(digit);
    candidateMasks[index] |= 1 << (digit - 1);
  }

  /// 整体设置格 [index] 的候选集。
  void setCandidates(int index, CandidateSet candidates) {
    Coord.requireIndex(index);
    candidateMasks[index] = candidates.mask;
  }

  /// 设置格 [index] 的给定标记。
  ///
  /// 仅供题目装载/生成阶段使用；对局过程中不得调用。
  void setGiven(int index, bool given) {
    Coord.requireIndex(index);
    givenMask[index] = given;
  }

  /// 按「当前非空即给定」重建 [givenMask]。
  ///
  /// 供生成器挖洞完成后固化题面使用。
  void freezeGivensFromValues() {
    for (int i = 0; i < kCellCount; i++) {
      givenMask[i] = values[i] != kEmptyValue;
    }
  }

  /// 清空全部候选集。
  void clearAllCandidates() {
    for (int i = 0; i < kCellCount; i++) {
      candidateMasks[i] = 0;
    }
  }

  /// 重置本局：把所有非给定格恢复为空，并清空全部候选。
  ///
  /// 候选需要调用方随后执行 `CandidateCalculator.recomputeAll` 重建。
  void resetToGivens() {
    for (int i = 0; i < kCellCount; i++) {
      if (!givenMask[i]) {
        values[i] = kEmptyValue;
      }
      candidateMasks[i] = 0;
    }
  }

  // ---------------------------------------------------------------- 拷贝与序列化

  /// 深拷贝（跨 Isolate 传递、撤销快照用）。
  Board snapshot() => Board._(
        Int8List.fromList(values),
        List<bool>.of(givenMask),
        Uint16List.fromList(candidateMasks),
      );

  /// [snapshot] 的同义方法。
  Board clone() => snapshot();

  /// 导出 81 字符串，空格用 [emptyChar]（默认 `.`）。
  String toPuzzleString({String emptyChar = kEmptyChar}) {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < kCellCount; i++) {
      buffer.write(values[i] == kEmptyValue ? emptyChar : '${values[i]}');
    }
    return buffer.toString();
  }

  /// 导出 81 位给定掩码字符串（`1` = 给定，`0` = 非给定）。
  String toGivenMaskString() {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < kCellCount; i++) {
      buffer.write(givenMask[i] ? '1' : '0');
    }
    return buffer.toString();
  }

  /// 导出为普通 int 列表（不可变副本）。
  List<int> toValueList() => List<int>.unmodifiable(values);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! Board) {
      return false;
    }
    for (int i = 0; i < kCellCount; i++) {
      if (values[i] != other.values[i] ||
          givenMask[i] != other.givenMask[i] ||
          candidateMasks[i] != other.candidateMasks[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        toPuzzleString(),
        toGivenMaskString(),
        Object.hashAll(candidateMasks),
      );

  @override
  String toString() => 'Board(${toPuzzleString()})';
}
