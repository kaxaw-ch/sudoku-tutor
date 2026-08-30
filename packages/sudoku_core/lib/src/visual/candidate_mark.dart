/// 候选数标记：划除 / 强调 / 结论目标（doc 06 §6.4）。
library;

import 'package:meta/meta.dart';

import '../model/coord.dart';
import '../model/digit.dart';

/// 候选数标记类型。
enum CandidateMarkKind {
  /// 划除（该候选被本步删除）。
  strike('strike', '划除'),

  /// 强调（该候选参与构成模式）。
  emphasize('emphasize', '强调'),

  /// 结论目标（本步要填入的数字）。
  target('target', '结论目标');

  const CandidateMarkKind(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文名。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static CandidateMarkKind? tryParse(String id) {
    for (final CandidateMarkKind value in CandidateMarkKind.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 单个候选数上的标记。
@immutable
class CandidateMark {
  /// 构造一个候选数标记。
  CandidateMark({
    required this.cellIndex,
    required this.digit,
    required this.kind,
  }) {
    Coord.requireIndex(cellIndex);
    Digit.requireDigit(digit);
  }

  /// 所在格索引。
  final int cellIndex;

  /// 候选数字 1..9。
  final int digit;

  /// 标记类型。
  final CandidateMarkKind kind;

  /// 人类可读标签，如 `r5c2 的 5`。
  String get label => '${Coord.label(cellIndex)} 的 $digit';

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'cellIndex': cellIndex,
        'digit': digit,
        'kind': kind.id,
      };

  /// 由 JSON map 反序列化。
  static CandidateMark fromJson(Map<String, Object?> json) => CandidateMark(
        cellIndex: json['cellIndex']! as int,
        digit: json['digit']! as int,
        kind: CandidateMarkKind.tryParse(json['kind'] as String? ?? '') ??
            CandidateMarkKind.emphasize,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CandidateMark &&
          other.cellIndex == cellIndex &&
          other.digit == digit &&
          other.kind == kind);

  @override
  int get hashCode => Object.hash(cellIndex, digit, kind);

  @override
  String toString() => 'CandidateMark($label,${kind.id})';
}
