/// 讲解文案模板引擎：占位符替换 + 单元/坐标的中文表述（P0-ENG-10）。
///
/// 占位符规范（doc 06 §6.5）：
/// - `{digit}` 单个数字；
/// - `{cellsLabel}` 形如 `第 2 行第 3 列、第 7 行第 8 列`；
/// - `{baseUnits}` 形如 `第 2 行与第 8 行`；
/// - `{elimList}` 形如 `第 5 行第 2 列的候选 5`。
///
/// **演示旁白与三级提示复用同一套模板**，避免文案漂移。
library;

import '../model/coord.dart';
import '../model/unit.dart';

/// 一条可渲染的文案模板。
class NarrationTemplate {
  /// 由模板串构造，如 `'{cellsLabel} 构成裸对。'`。
  const NarrationTemplate(this.pattern);

  /// 模板原文（含 `{key}` 占位符）。
  final String pattern;

  /// 占位符匹配正则：`{key}`，key 为字母/数字/下划线。
  static final RegExp _placeholder = RegExp(r'\{([A-Za-z0-9_]+)\}');

  /// 模板中出现的全部占位符名（按出现顺序，去重）。
  List<String> placeholders() {
    final List<String> keys = <String>[];
    for (final RegExpMatch match in _placeholder.allMatches(pattern)) {
      final String key = match.group(1)!;
      if (!keys.contains(key)) {
        keys.add(key);
      }
    }
    return List<String>.unmodifiable(keys);
  }

  /// 用 [slots] 渲染模板。
  ///
  /// 未提供的占位符原样保留（便于测试立刻暴露缺参，而不是静默输出空串）。
  String render(Map<String, Object?> slots) =>
      NarrationFormat.localizeCoordinates(
        pattern.replaceAllMapped(_placeholder, (Match match) {
          final String key = match.group(1)!;
          if (!slots.containsKey(key)) {
            return match.group(0)!;
          }
          return NarrationFormat.stringify(slots[key]);
        }),
      );

  /// [slots] 是否覆盖了模板需要的全部占位符。
  bool isSatisfiedBy(Map<String, Object?> slots) {
    for (final String key in placeholders()) {
      if (!slots.containsKey(key)) {
        return false;
      }
    }
    return true;
  }

  /// 缺失的占位符名列表。
  List<String> missingSlots(Map<String, Object?> slots) => <String>[
        for (final String key in placeholders())
          if (!slots.containsKey(key)) key,
      ];

  @override
  String toString() => 'NarrationTemplate($pattern)';
}

/// 槽位值 → 中文串的格式化工具（全部为静态纯函数）。
abstract final class NarrationFormat {
  /// 中文顿号分隔符。
  static const String separator = '、';

  /// 把教学文本中的内部坐标记号统一转换为中文。
  ///
  /// 同时兼容标准写法 `r3c4` 和历史数据中偶见的 `3r4c`，转换后均为
  /// `第 3 行第 4 列`。该函数是纯函数，可安全用于资源生成和运行时兜底。
  static String localizeCoordinates(String source) {
    String localized = source.replaceAllMapped(
      RegExp(r'(?<![A-Za-z0-9])r([1-9])c([1-9])(?![A-Za-z0-9])',
          caseSensitive: false),
      (Match match) => '第 ${match.group(1)} 行第 ${match.group(2)} 列',
    );
    localized = localized.replaceAllMapped(
      RegExp(r'(?<![A-Za-z0-9])([1-9])r([1-9])c(?![A-Za-z0-9])',
          caseSensitive: false),
      (Match match) => '第 ${match.group(1)} 行第 ${match.group(2)} 列',
    );
    return localized;
  }

  /// 通用槽位值字符串化。
  ///
  /// - `null` → 空串；
  /// - `Iterable` → 顿号连接；
  /// - 其它 → `toString()`。
  static String stringify(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is Iterable<Object?>) {
      return value.map(stringify).join(separator);
    }
    return value.toString();
  }

  /// 一组格索引 → `第 2 行第 3 列、第 7 行第 8 列`。
  static String cellsLabel(Iterable<int> cells) =>
      cells.map(Coord.zhLabel).join(separator);

  /// 单个单元 → `第 2 行`。
  static String unitLabel(UnitType type, int id) => Units.of(type, id).zhLabel;

  /// 一组同类单元 → `第 2 行与第 8 行`。
  static String unitsLabel(UnitType type, Iterable<int> ids) {
    final List<String> labels = <String>[
      for (final int id in ids) Units.of(type, id).zhLabel,
    ];
    if (labels.isEmpty) {
      return '';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    return '${labels.sublist(0, labels.length - 1).join(separator)}与${labels.last}';
  }

  /// 删数条目 → `第 5 行第 2 列的候选 5`。
  static String elimLabel(int cellIndex, int digit) =>
      '${Coord.zhLabel(cellIndex)}的候选 $digit';

  /// 一组删数条目 → `第 5 行第 2 列的候选 5、第 6 行第 2 列的候选 5`。
  static String elimList(Iterable<MapEntry<int, int>> eliminations) =>
      eliminations
          .map((MapEntry<int, int> e) => elimLabel(e.key, e.value))
          .join(separator);

  /// 一组数字 → `2、5`。
  static String digitList(Iterable<int> digits) => digits.join(separator);
}
