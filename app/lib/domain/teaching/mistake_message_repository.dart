/// 误操作文案仓库（T-EDU-04 / P0-EDU-05，配套 20–30 条文案）。
///
/// 职责：读取 `assets/text/mistakes_zh.json`，按 [MistakeType]（含技巧细分）
/// 取「错在哪 + 正确思路」两段模板，渲染 `{cell}` / `{digit}` / `{technique}`
/// 占位符，弹窗**不给答案**（模板本身只讲思路、不透露正确数字）。
///
/// 文案轮转：同一类别内按已发次数轮转取模板，降低同一错误重复文案的
/// 观感疲劳（2 分钟去重由 `MistakeDetector` 负责，这里是文案层轮转）。
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sudoku_tutor/core/core.dart';

import 'mistake_detector.dart';

/// 资产读取函数签名（测试注入假文本；生产默认 rootBundle）。
typedef MistakeTextLoader = Future<String> Function(String assetPath);

/// 生产默认加载器。
Future<String> defaultMistakeTextLoader(String assetPath) =>
    rootBundle.loadString(assetPath);

/// 一条完整弹窗文案（「错在哪」+「正确思路」，两段）。
class MistakeMessage {
  /// 构造文案。
  const MistakeMessage({required this.what, required this.how});

  /// 错在哪。
  final String what;

  /// 正确思路（不含答案）。
  final String how;
}

/// 误操作文案仓库。
class MistakeMessageRepository {
  /// 构造仓库；[loader] 缺省用 [defaultMistakeTextLoader]。
  MistakeMessageRepository({MistakeTextLoader? loader})
      : _loader = loader ?? defaultMistakeTextLoader;

  /// 资产路径（与 pubspec 声明的 assets/text/ 对齐）。
  static const String kAssetPath = 'assets/text/mistakes_zh.json';

  final MistakeTextLoader _loader;

  /// 未加载前的兜底文案（避免 UI 空白）。
  static const MistakeMessage kFallbackMessage = MistakeMessage(
    what: '这一步的填法有待商榷，请结合所在行、列、宫重新判断。',
    how: '换一种思路：先看其它已确定的数字能排除哪些候选，再决定下一步。',
  );

  Map<String, Object?>? _parsed;

  /// 各类别模板（按类别轮转计数）。
  final Map<String, int> _roundRobin = <String, int>{};

  /// 取一条文案（同步；数据未加载时返回兜底文案）。
  MistakeMessage messageFor(MistakeEvent event) {
    final List<MistakeMessage> templates = _templatesFor(event);
    if (templates.isEmpty) {
      return kFallbackMessage;
    }
    final int index = (_roundRobin[event.type.id] =
            (_roundRobin[event.type.id] ?? 0) + 1) %
        templates.length;
    final MistakeMessage template = templates[index];
    return MistakeMessage(
      what: _render(template.what, event),
      how: _render(template.how, event),
    );
  }

  /// 显式加载（可提前预热；页面弹窗时也可懒加载）。
  Future<void> load() async {
    if (_parsed != null) {
      return;
    }
    final String text;
    try {
      text = await _loader(kAssetPath);
    } on Object {
      _parsed = const <String, Object?>{};
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      _parsed = const <String, Object?>{};
      return;
    }
    // jsonDecode 产物是 `Map<String, dynamic>`，经 Map.from 归一为内部口径。
    if (decoded is Map) {
      _parsed = Map<String, Object?>.from(decoded);
    } else {
      _parsed = const <String, Object?>{};
    }
  }

  // ------------------------------------------------------------ 内部

  /// 按事件类型取候选模板列表（prematureFill 按技巧细分 + default 兜底）。
  List<MistakeMessage> _templatesFor(MistakeEvent event) {
    final Map<String, Object?>? root = _parsed;
    if (root == null) {
      return const <MistakeMessage>[];
    }
    final Object? rawCategories = root['categories'];
    if (rawCategories is! List) {
      return const <MistakeMessage>[];
    }
    for (final Object? item in rawCategories) {
      if (item is! Map) {
        continue;
      }
      final Map<String, Object?> category = Map<String, Object?>.from(item);
      if (category['id'] != event.type.id) {
        continue;
      }
      return _templatesOf(category, event);
    }
    return const <MistakeMessage>[];
  }

  List<MistakeMessage> _templatesOf(
      Map<String, Object?> category, MistakeEvent event) {
    final Object? raw = category['templates'];
    if (event.type == MistakeType.prematureFill && raw is Map) {
      // 形如 { "byTechnique": { "nakedSingle": [...], "default": [...] } }。
      final Map<String, Object?> by = Map<String, Object?>.from(raw);
      final Object? byTechnique = by['byTechnique'];
      final List<Object?>? exact = byTechnique is Map
          ? (Map<String, Object?>.from(byTechnique))['${event.techniqueId?.id}']
              as List<Object?>?
          : null;
      if (exact is List && exact.isNotEmpty) {
        return _parseList(exact);
      }
      final Object? def = by['default'];
      if (def is List) {
        return _parseList(def);
      }
      return const <MistakeMessage>[];
    }
    if (raw is List) {
      return _parseList(raw);
    }
    return const <MistakeMessage>[];
  }

  List<MistakeMessage> _parseList(List<Object?> items) => <MistakeMessage>[
        for (final Object? item in items)
          if (item is Map)
            MistakeMessage(
              what: (item['what'] as String?) ?? '',
              how: (item['how'] as String?) ?? '',
            ),
      ];

  /// 渲染 {cell} / {digit} / {technique} 占位符。
  static String _render(String template, MistakeEvent event) {
    final String cell = Coord.zhLabel(event.cellIndex);
    final String digit = '${event.digit}';
    final String technique = event.techniqueId?.zhName ?? '';
    return template
        .replaceAll('{cell}', cell)
        .replaceAll('{digit}', digit)
        .replaceAll('{technique}', technique);
  }
}
