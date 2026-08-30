/// 一次原子操作（填数 / 清除 / 标记候选 / 删候选 / 自动填写候选）值对象
/// （P0-ENG-05）。
///
/// [Move] 只描述**意图**，不含任何回滚所需的历史数据；
/// 回滚数据由 `MoveApplier.apply` 产出的 `MoveRecord` 承载。
/// 这样 [Move] 可以被 UI 层直接构造、序列化与比较，而不必了解盘面内部状态。
library;

import 'package:meta/meta.dart';

import '../model/coord.dart';
import '../model/digit.dart';
import '../util/core_error.dart';

/// 原子操作类型。
enum MoveType {
  /// 在某格填入数字。
  place('place', '填数'),

  /// 清除某格的填数。
  clear('clear', '清除'),

  /// 为某格标记一个候选（手动笔记）。
  addCandidate('addCandidate', '标记候选'),

  /// 从某格删除一个候选（手动笔记）。
  removeCandidate('removeCandidate', '删除候选'),

  /// 一次性为整盘空格填写全部合法候选。
  autoFillCandidates('autoFillCandidates', '自动填写候选');

  const MoveType(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文名（供操作历史文案复用）。
  final String zhName;

  /// 是否会改变格子的**填数值**（决定是否需要同步 peer 候选）。
  bool get changesValue => this == MoveType.place || this == MoveType.clear;

  /// 按 [id] 反查；未知返回 `null`。
  static MoveType? tryParse(String id) {
    for (final MoveType value in MoveType.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 一次原子操作。
@immutable
class Move {
  /// 通用构造；[digit] 对清除及整盘自动填写候选无意义，统一传 0。
  Move({
    required this.type,
    required this.cellIndex,
    this.digit = kEmptyValue,
  }) {
    Coord.requireIndex(cellIndex);
    if (type == MoveType.clear || type == MoveType.autoFillCandidates) {
      if (digit != kEmptyValue) {
        throw CoreException(
          CoreErrorCode.boardIndexRange,
          '${type.id} 操作的 digit 必须为 0，实际 $digit',
        );
      }
    } else {
      Digit.requireDigit(digit);
    }
  }

  /// 填数操作。
  factory Move.place(int cellIndex, int digit) =>
      Move(type: MoveType.place, cellIndex: cellIndex, digit: digit);

  /// 清除操作。
  factory Move.clear(int cellIndex) =>
      Move(type: MoveType.clear, cellIndex: cellIndex);

  /// 标记候选操作。
  factory Move.addCandidate(int cellIndex, int digit) =>
      Move(type: MoveType.addCandidate, cellIndex: cellIndex, digit: digit);

  /// 删除候选操作。
  factory Move.removeCandidate(int cellIndex, int digit) =>
      Move(type: MoveType.removeCandidate, cellIndex: cellIndex, digit: digit);

  /// 整盘自动填写候选操作。
  ///
  /// 该操作不针对单格；为保持序列化结构兼容，固定使用格索引 0 作为占位。
  factory Move.autoFillCandidates() =>
      Move(type: MoveType.autoFillCandidates, cellIndex: 0);

  /// 操作类型。
  final MoveType type;

  /// 目标格索引 0..80。
  final int cellIndex;

  /// 相关数字；清除及整盘自动填写候选时为 0。
  final int digit;

  /// 人类可读标签，如 `r3c5 填数 7`。
  String get label {
    if (type == MoveType.autoFillCandidates) {
      return type.zhName;
    }
    return digit == kEmptyValue
        ? '${Coord.label(cellIndex)} ${type.zhName}'
        : '${Coord.label(cellIndex)} ${type.zhName} $digit';
  }

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type.id,
        'cellIndex': cellIndex,
        'digit': digit,
      };

  /// 由 JSON map 反序列化；类型未知抛 `E_IMPORT_001`。
  static Move fromJson(Map<String, Object?> json) {
    final String typeId = json['type']! as String;
    final MoveType? type = MoveType.tryParse(typeId);
    if (type == null) {
      throw CoreException(CoreErrorCode.importFormat, '未知操作类型「$typeId」');
    }
    return Move(
      type: type,
      cellIndex: json['cellIndex']! as int,
      digit: (json['digit'] as int?) ?? kEmptyValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Move &&
          other.type == type &&
          other.cellIndex == cellIndex &&
          other.digit == digit);

  @override
  int get hashCode => Object.hash(type, cellIndex, digit);

  @override
  String toString() => 'Move($label)';
}
