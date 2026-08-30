/// 连线标记：两端格 + 强/弱链 + 承载数字（doc 06 §6.4）。
///
/// 使用方：XY 翼、XYZ 翼、W 翼、简单涂色。
library;

import 'package:meta/meta.dart';

import '../model/coord.dart';
import '../model/digit.dart';

/// 一条链路连线。
@immutable
class LinkMark {
  /// 构造一条连线。
  LinkMark({
    required this.fromCell,
    required this.toCell,
    required this.digit,
    required this.strong,
  }) {
    Coord.requireIndex(fromCell);
    Coord.requireIndex(toCell);
    Digit.requireDigit(digit);
  }

  /// 起点格索引。
  final int fromCell;

  /// 终点格索引。
  final int toCell;

  /// 连线承载的数字（线上小标）。
  final int digit;

  /// 是否强链（实线）；否为弱链（虚线）。
  final bool strong;

  /// 人类可读标签，如 `r2c3=5=r7c3`（强链）或 `r2c3-5-r7c3`（弱链）。
  String get label {
    final String joint = strong ? '=' : '-';
    return '${Coord.label(fromCell)}$joint$digit$joint${Coord.label(toCell)}';
  }

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'fromCell': fromCell,
        'toCell': toCell,
        'digit': digit,
        'strong': strong,
      };

  /// 由 JSON map 反序列化。
  static LinkMark fromJson(Map<String, Object?> json) => LinkMark(
        fromCell: json['fromCell']! as int,
        toCell: json['toCell']! as int,
        digit: json['digit']! as int,
        strong: json['strong'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LinkMark &&
          other.fromCell == fromCell &&
          other.toCell == toCell &&
          other.digit == digit &&
          other.strong == strong);

  @override
  int get hashCode => Object.hash(fromCell, toCell, digit, strong);

  @override
  String toString() => 'LinkMark($label)';
}
