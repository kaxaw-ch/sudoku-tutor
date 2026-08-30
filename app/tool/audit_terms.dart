/// T-CNT-06 术语一致性审计脚本（可复跑，纯 Dart）。
///
/// 职责（对应 doc 07 §6 / T-CNT-06）：
/// 1. 读取 `packages/sudoku_core` 的 `TechniqueId.zhName`（定死译名，权威基准）；
/// 2. 遍历 `assets/curriculum/` 下全部关卡 JSON（包括未登记的测试资产）的
///    `title` / `intro` / `script.steps[].narration` + `assets/text/mistakes_zh.json`
///    的全部字符串，抽取技巧中文名（模糊匹配），与 zhName 逐字比对；
/// 3. 输出不一致清单：错误译名 / 英文残留 / 半角横杠 / 无空格 / 全半角标点混用 /
///    面向玩家的内部坐标（`rXcY` / `XrYc`，应改为“第 X 行第 Y 列”）。
///
/// 运行：`cd app && dart run tool/audit_terms.dart`
///（纯 Dart，不 import flutter；依赖 `package:sudoku_core/sudoku_core.dart`）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

import 'project_paths.dart';

/// 项目根（运行时自动发现，也可用 `PROJECT_ROOT` 覆盖）。
final String _root = findProjectRoot();
final String _curriculumDir = '$_root/app/assets/curriculum';
final String _mistakesPath = '$_root/app/assets/text/mistakes_zh.json';

/// 一条审计发现。
class AuditFinding {
  const AuditFinding(this.file, this.field, this.source, this.message);

  /// 来源文件（相对 assets 的展示名）。
  final String file;

  /// 字段（title / intro / narration / mistakes）。
  final String field;

  /// 命中的原始片段。
  final String source;

  /// 问题描述。
  final String message;

  @override
  String toString() => '$file [$field] 「$source」 → $message';
}

void main() {
  final List<AuditFinding> findings = <AuditFinding>[];

  // ------------------------------------------------------------ 权威技巧表
  // （TechniqueId.zhName 由下方 _auditTechniqueNames 直接读取，权威唯一来源。）

  // ------------------------------------------------------------ 关卡文本
  final List<File> levelFiles = Directory(_curriculumDir)
      .listSync()
      .whereType<File>()
      .where((File file) =>
          file.path.endsWith('.json') &&
          !file.path.endsWith('${Platform.pathSeparator}index.json'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  for (final File file in levelFiles) {
    final Map<String, dynamic> data =
        _readJson(file.path) as Map<String, dynamic>;
    _auditLevel(data, findings);
  }

  // ------------------------------------------------------------ mistakes
  final Map<String, dynamic> mistakes =
      _readJson(_mistakesPath) as Map<String, dynamic>;
  _collectMistakeStrings(mistakes, (String s, String where) {
    _auditText(s, 'mistakes', where, findings);
  });
  _auditMistakeStructure(mistakes, findings);
  _auditMistakeResolution(mistakes, findings);

  // ------------------------------------------------------------ 汇总
  if (findings.isEmpty) {
    stdout.writeln('✅ 术语审计通过：0 不一致（技巧名/标点/坐标均与权威基准一致）。');
    return;
  }
  stdout.writeln('❌ 发现 ${findings.length} 处不一致：');
  for (final AuditFinding f in findings) {
    stdout.writeln('  - $f');
  }
  exit(1);
}

/// mistakes 结构校验（与 MistakeMessageRepository 解析兼容性）：
/// 1. `prematureFill.templates` 为 Map，含 `byTechnique` 子 Map；
/// 2. `byTechnique` 键必须是合法 techniqueId（与 TechniqueId.values 对齐）；
/// 3. 34 关出现的全部教学技巧在 byTechnique 中均有模板；
/// 4. `default` 与 `byTechnique` 平级（repo 从 `templates['default']` 取兜底）。
void _auditMistakeStructure(
    Map<String, dynamic> mistakes, List<AuditFinding> findings) {
  final List<dynamic>? categories = mistakes['categories'] as List<dynamic>?;
  if (categories == null) {
    findings.add(AuditFinding(
        'mistakes_zh.json', 'root', 'categories', '缺少 categories 列表'));
    return;
  }
  for (final Object? c in categories) {
    final Map<String, dynamic> category = Map<String, dynamic>.from(c as Map);
    if (category['id'] != 'prematureFill') {
      continue;
    }
    final Object? raw = category['templates'];
    if (raw is! Map) {
      findings.add(AuditFinding('mistakes_zh.json', 'prematureFill',
          raw?.toString() ?? '', 'templates 应为 Map（{byTechnique, default}）'));
      continue;
    }
    final Map<String, Object?> templates = Map<String, Object?>.from(raw);
    final Object? byTechnique = templates['byTechnique'];
    if (byTechnique is! Map) {
      findings.add(AuditFinding('mistakes_zh.json', 'prematureFill',
          'byTechnique', '缺少 byTechnique 子 Map'));
      continue;
    }
    final Map<String, Object?> by = Map<String, Object?>.from(byTechnique);
    final Set<String> validIds = <String>{
      for (final TechniqueId t in TechniqueId.values) t.id,
    };
    for (final String key in by.keys) {
      if (!validIds.contains(key)) {
        findings.add(AuditFinding(
            'mistakes_zh.json',
            'prematureFill.byTechnique',
            key,
            '非合法 techniqueId，应对齐 TechniqueId.values'));
      }
    }
    // 34 关出现的教学技巧全覆盖。
    for (final String id in kCurriculumTechniqueIds) {
      final Object? v = by[id];
      if (v is! List || v.isEmpty) {
        findings.add(AuditFinding('mistakes_zh.json',
            'prematureFill.byTechnique.$id', id, '34 关出现的教学技巧缺模板'));
      }
    }
    // default 与 byTechnique 平级。
    if (templates['default'] is! List) {
      findings.add(AuditFinding(
          'mistakes_zh.json',
          'prematureFill.templates',
          'default',
          'default 应与 byTechnique 平级且为列表（repo 取 templates.default）'));
    }
  }
}

/// prematureFill byTechnique 必须覆盖的教学技巧（任务书第 2 节列出的 9 个；
/// 基础技巧 nakedSingle/hiddenSingle/lockedCandidates 由 default 兜底）。
const List<String> kCurriculumTechniqueIds = <String>[
  'nakedPair',
  'hiddenPair',
  'nakedTriple',
  'hiddenTriple',
  'xWing',
  'finnedXWing',
  'swordfish',
  'xyWing',
  'xyzWing',
];

/// 检查模板文本占位符：仅允许 repo 渲染支持的 {cell}/{digit}/{technique}。
void _checkPlaceholders(String what, String how, String file, String field,
    String source, List<AuditFinding> findings) {
  final RegExp ph = RegExp(r'\{([a-zA-Z]+)\}');
  final Set<String> allowed = <String>{'cell', 'digit', 'technique'};
  for (final String text in <String>[what, how]) {
    for (final RegExpMatch m in ph.allMatches(text)) {
      final String key = m.group(1)!;
      if (!allowed.contains(key)) {
        findings.add(AuditFinding(file, field, source,
            '模板占位符 {$key} 不受支持（repo 仅渲染 {cell}/{digit}/{technique}）'));
      }
    }
  }
}

/// 按 `MistakeMessageRepository._templatesOf` 逻辑做模板取用冒烟：
/// 对 34 关每个教学技巧，模拟 prematureFill 取模板——byTechnique 精确命中
/// 或 default 兜底，且每类至少有一条可渲染模板（占位符 {cell}/{digit}/{technique}）。
void _auditMistakeResolution(
    Map<String, dynamic> mistakes, List<AuditFinding> findings) {
  final List<dynamic>? categories = mistakes['categories'] as List<dynamic>?;
  if (categories == null) {
    return;
  }
  Map<String, Object?>? premature;
  Map<String, Object?>? wrongFill;
  Map<String, Object?>? deleted;
  for (final Object? c in categories) {
    final Map<String, dynamic> category = Map<String, dynamic>.from(c as Map);
    switch (category['id']) {
      case 'prematureFill':
        premature = Map<String, Object?>.from(category);
      case 'wrongFill':
        wrongFill = Map<String, Object?>.from(category);
      case 'deletedTrueCandidate':
        deleted = Map<String, Object?>.from(category);
    }
  }
  // 每类模板须可解析（至少 1 条）。
  for (final Map<String, Object?>? cat in <Map<String, Object?>?>[
    wrongFill,
    deleted,
    premature
  ]) {
    if (cat == null) {
      continue;
    }
    final Object? raw = cat['templates'];
    final String id = cat['id'] as String;
    if (id == 'prematureFill') {
      if (raw is! Map) {
        findings.add(AuditFinding('mistakes_zh.json', 'prematureFill',
            raw?.toString() ?? '', 'templates 非 Map'));
        continue;
      }
      final Map<String, Object?> templates = Map<String, Object?>.from(raw);
      final Object? byTechnique = templates['byTechnique'];
      final Map<String, Object?> by = byTechnique is Map
          ? Map<String, Object?>.from(byTechnique)
          : <String, Object?>{};
      final Object? def = templates['default'];
      for (final String techniqueId in kCurriculumTechniqueIds) {
        final List<Object?>? exact = by[techniqueId] as List<Object?>?;
        final List<Object?> chosen = (exact != null && exact.isNotEmpty)
            ? exact
            : (def is List ? def : const <Object?>[]);
        if (chosen.isEmpty) {
          findings.add(AuditFinding(
              'mistakes_zh.json',
              'prematureFill.$techniqueId',
              techniqueId,
              '模板取用失败：byTechnique 无命中且 default 缺失'));
          continue;
        }
        final String what = (chosen.first as Map?)?['what'] as String? ?? '';
        final String how = (chosen.first as Map?)?['how'] as String? ?? '';
        if (what.isEmpty || how.isEmpty) {
          findings.add(AuditFinding('mistakes_zh.json',
              'prematureFill.$techniqueId', techniqueId, '模板 what/how 为空'));
        }
        _checkPlaceholders(what, how, 'mistakes_zh.json',
            'prematureFill.$techniqueId', techniqueId, findings);
      }
    } else {
      if (raw is! List || raw.isEmpty) {
        findings.add(AuditFinding(
            'mistakes_zh.json', id, raw?.toString() ?? '', 'templates 应为非空列表'));
        continue;
      }
      final Map<String, dynamic>? first =
          raw.first is Map ? Map<String, dynamic>.from(raw.first as Map) : null;
      final String what = first?['what'] as String? ?? '';
      final String how = first?['how'] as String? ?? '';
      if (what.isEmpty || how.isEmpty) {
        findings.add(AuditFinding(
            'mistakes_zh.json', id, raw.first.toString(), '模板 what/how 为空'));
      }
      _checkPlaceholders(
          what, how, 'mistakes_zh.json', id, raw.first.toString(), findings);
    }
  }
}

// ------------------------------------------------------------ 扫描关卡

void _auditLevel(Map<String, dynamic> data, List<AuditFinding> findings) {
  final String id = data['id'] as String;
  _auditText(data['title'] as String? ?? '', id, 'title', findings);
  _auditText(data['intro'] as String? ?? '', id, 'intro', findings);
  final Map<String, dynamic>? script = data['script'] as Map<String, dynamic>?;
  if (script == null) {
    return;
  }
  final List<dynamic>? steps = script['steps'] as List<dynamic>?;
  if (steps == null) {
    return;
  }
  for (int i = 0; i < steps.length; i++) {
    final Map<String, dynamic> step =
        Map<String, dynamic>.from(steps[i] as Map);
    final String? narration = step['narration'] as String?;
    if (narration != null) {
      _auditText(
          narration, id, 'narration#${step['order'] ?? i + 1}', findings);
    }
  }
}

/// 收集 mistakes_zh.json 内所有字符串（含嵌套 byTechnique / default）。
void _collectMistakeStrings(Object? node, void Function(String, String) onText,
    [String path = 'root']) {
  if (node is String) {
    onText(node, path);
    return;
  }
  if (node is Map) {
    node.forEach((Object? k, Object? v) {
      _collectMistakeStrings(
          v, onText, '$path.${k is String ? k : k.toString()}');
    });
    return;
  }
  if (node is List) {
    for (int i = 0; i < node.length; i++) {
      _collectMistakeStrings(node[i], onText, '$path[$i]');
    }
  }
}

// ------------------------------------------------------------ 单文本审计

/// 对一段教学文本做三方面检查：技巧名 / 全半角标点 / 坐标格式。
void _auditText(
    String text, String file, String field, List<AuditFinding> findings) {
  if (text.isEmpty) {
    return;
  }
  _auditTechniqueNames(text, file, field, findings);
  _auditPunctuation(text, file, field, findings);
  _auditCoords(text, file, field, findings);
}

/// 技巧名比对。
///
/// 权威基准：[TechniqueId.zhName]（如「X 翼」「鳍形 X 翼（含 Sashimi）」「剑鱼（标准）」）。
/// 判定规则：
/// - 文本中出现 zhName 完整串或 zhName 的「核心名」（去括注，如「鳍形 X 翼」「剑鱼」）→ 一致；
/// - 出现英文残留（X-Wing / XY-Wing / Swordfish / Naked Pair …）、无空格（X翼）、
///   中英混写括注（裸对（naked pair））等 → 不一致；
/// - 出现 zhName 内括注之外的括注含英文 → 提示核对。
void _auditTechniqueNames(
    String text, String file, String field, List<AuditFinding> findings) {
  // 1) 显式错误形式（英文残留 / 半角横杠 / 无空格）。
  final List<RegExp> badPatterns = <RegExp>[
    RegExp(r'X\s*-\s*Wing'),
    RegExp(r'XY\s*-\s*Wing'),
    RegExp(r'XYZ\s*-\s*Wing'),
    RegExp(r'W\s*-\s*Wing'),
    RegExp(r'Swordfish'),
    RegExp(r'Naked\s+Pair'),
    RegExp(r'Hidden\s+Pair'),
    RegExp(r'Naked\s+Triple'),
    RegExp(r'Hidden\s+Triple'),
    RegExp(r'Naked\s+Single'),
    RegExp(r'Hidden\s+Single'),
    RegExp(r'Finned\s+X\s*-?\s*Wing'),
    RegExp(r'Pointing|Claiming'),
    RegExp(r'X翼'), // 无空格
    RegExp(r'XY翼'),
    RegExp(r'XYZ翼'),
    RegExp(r'W翼'),
    RegExp(r'裸对（\s*naked|\裸对\(\s*naked', caseSensitive: false),
  ];
  for (final RegExp re in badPatterns) {
    for (final RegExpMatch m in re.allMatches(text)) {
      final String src = m.group(0)!;
      if (_isWhitelistedSashimi(text, m.start, m.end)) {
        continue;
      }
      findings
          .add(AuditFinding(file, field, src, '技巧名形式不规范（应使用代码 zhName 中文译名）'));
    }
  }

  // 3) 技巧名中文核心名抽查：出现「XX 翼 / 裸对 / 剑鱼 / 鳍形 / 矩形 / 涂色 /
  //    唯一余数 / 隐性」等词时，与定死译名核心比对，发现变体即提示。
  final List<RegExp> corePatterns = <RegExp>[
    RegExp(r'X\s+翼'),
    RegExp(r'XY\s+翼'),
    RegExp(r'XYZ\s+翼'),
    RegExp(r'W\s+翼'),
    RegExp(r'鳍形\s+X\s+翼'),
    RegExp(r'裸对|裸三|隐对|隐三'),
    RegExp(r'唯一余数|隐性唯一数|区块排除'),
    RegExp(r'剑鱼'),
    RegExp(r'简单涂色|唯一矩形'),
  ];
  final Set<String> validCores = <String>{
    'X 翼',
    'XY 翼',
    'XYZ 翼',
    'W 翼',
    '鳍形 X 翼',
    '剑鱼',
    '裸对',
    '裸三',
    '隐对',
    '隐三',
    '唯一余数',
    '隐性唯一数',
    '区块排除',
    '简单涂色',
    '唯一矩形',
    for (final TechniqueId t in TechniqueId.values) t.zhName,
  };
  for (final RegExp re in corePatterns) {
    for (final RegExpMatch m in re.allMatches(text)) {
      final String matched = m.group(0)!;
      if (validCores.contains(matched)) {
        continue; // 合法核心名。
      }
      findings.add(AuditFinding(file, field, matched,
          '技巧名「$matched」不在定死译名表内，请对照 TechniqueId.zhName'));
    }
  }
}

/// 全半角标点混用检查（中文语境下不应出现半角 , . ; : ? ! 及半角括号）。
void _auditPunctuation(
    String text, String file, String field, List<AuditFinding> findings) {
  // 半角逗号/句号/括号出现在中文句中。
  final RegExp halfPunct = RegExp(r'[\u4e00-\u9fff][,.;:!?()][\u4e00-\u9fff]');
  for (final RegExpMatch m in halfPunct.allMatches(text)) {
    findings.add(AuditFinding(
        file, field, m.group(0)!, '全半角标点混用：中文语境应使用全角标点（，。；：？！）与全角括号'));
  }
  // 引号配对：中文语境半角引号。
  final RegExp halfQuote = RegExp(r'"');
  for (final RegExpMatch m in halfQuote.allMatches(text)) {
    findings.add(AuditFinding(file, field, m.group(0)!, '半角双引号应改为「」'));
  }
}

/// 坐标格式检查：教学文本不得暴露内部 `rXcY` / `XrYc` 记号。
void _auditCoords(
    String text, String file, String field, List<AuditFinding> findings) {
  final RegExp badCoord = RegExp(
    r'[Rr][1-9]\s*-?\s*[Cc][1-9]|[1-9][Rr][1-9][Cc]',
  );
  for (final RegExpMatch m in badCoord.allMatches(text)) {
    findings.add(AuditFinding(
      file,
      field,
      m.group(0)!,
      '教学坐标应使用中文描述（如「第 3 行第 5 列」）',
    ));
  }
}

// ------------------------------------------------------------ 工具

/// Sashimi 白名单：zhName「鳍形 X 翼（含 Sashimi）」中的 Sashimi 属合法英文。
/// 若命中文本紧邻「（含 Sashimi」或「含 Sashimi）」，跳过英文残留报错。
bool _isWhitelistedSashimi(String text, int start, int end) {
  final int lo = (start - 6).clamp(0, text.length);
  final int hi = (end + 6).clamp(0, text.length);
  final String ctx = text.substring(lo, hi);
  return ctx.contains('含 Sashimi') || ctx.contains('Sashimi 退化');
}

Map<String, Object?> _readJson(String path) {
  try {
    final Object? decoded = jsonDecode(File(path).readAsStringSync());
    return Map<String, Object?>.from(decoded as Map);
  } on Object catch (e) {
    throw StateError('读取/解析 $path 失败: $e');
  }
}
