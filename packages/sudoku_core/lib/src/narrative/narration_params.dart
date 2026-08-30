/// 结构化讲解参数（技巧、数字、行列号、格集合、删数集合）（P0-ENG-10）。
///
/// 识别器只产出**结构化参数**，不拼接自然语言；
/// 具体措辞由 `zh_cn_templates.dart` 的模板决定，保证文案可集中校订。
library;

import 'package:meta/meta.dart';

import '../techniques/technique_id.dart';
import 'narration_template.dart';

/// 一步技巧结论的讲解参数。
@immutable
class NarrationParams {
  /// 构造讲解参数（`slots` 做不可变拷贝）。
  NarrationParams({
    required this.techniqueId,
    Map<String, Object?> slots = const <String, Object?>{},
  }) : slots = Map<String, Object?>.unmodifiable(<String, Object?>{...slots});

  /// 对应技巧。
  final TechniqueId techniqueId;

  /// 占位符槽位表，键名须与模板中的 `{key}` 一致。
  final Map<String, Object?> slots;

  /// 用给定模板渲染出最终中文句子。
  String render(NarrationTemplate template) => template.render(slots);

  /// 返回追加/覆盖若干槽位后的新参数对象。
  NarrationParams withSlots(Map<String, Object?> extra) => NarrationParams(
        techniqueId: techniqueId,
        slots: <String, Object?>{...slots, ...extra},
      );

  /// 序列化为 JSON map。
  ///
  /// 槽位值统一转为字符串，保证跨 Isolate 与落盘时类型稳定（doc 06 §7.5）。
  Map<String, Object?> toJson() => <String, Object?>{
        'techniqueId': techniqueId.id,
        'slots': <String, String>{
          for (final MapEntry<String, Object?> entry in slots.entries)
            entry.key: NarrationFormat.stringify(entry.value),
        },
      };

  /// 由 JSON map 反序列化。
  static NarrationParams fromJson(Map<String, Object?> json) {
    final Map<String, Object?> raw =
        (json['slots'] as Map<String, Object?>?) ?? const <String, Object?>{};
    return NarrationParams(
      techniqueId: TechniqueId.parse(json['techniqueId']! as String),
      slots: <String, Object?>{
        for (final MapEntry<String, Object?> entry in raw.entries) entry.key: entry.value,
      },
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! NarrationParams ||
        other.techniqueId != techniqueId ||
        other.slots.length != slots.length) {
      return false;
    }
    for (final MapEntry<String, Object?> entry in slots.entries) {
      if (!other.slots.containsKey(entry.key)) {
        return false;
      }
      if (NarrationFormat.stringify(other.slots[entry.key]) !=
          NarrationFormat.stringify(entry.value)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        techniqueId,
        Object.hashAllUnordered(<String>[
          for (final MapEntry<String, Object?> e in slots.entries)
            '${e.key}=${NarrationFormat.stringify(e.value)}',
        ]),
      );

  @override
  String toString() => 'NarrationParams(${techniqueId.id},slots=${slots.keys.toList()})';
}
