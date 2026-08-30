/// CLI 出题 profile 的解析与表示（doc 06 §3.2 `lib/src/config/cli_config.dart`）。
///
/// 职责（T-CLI-01，P0-CLI-02）：
/// - 把 `--profile t2.yaml` / `--profile t2` 解析为 [ProfileSpec]；
/// - **规则集声明**直接对接 `sudoku_core` 的 `RuleSet`
///   （t1 / t2 / custom 三种模式，见 `profiles/t1.yaml`、`profiles/t2.yaml`）；
/// - 提供 [ProfileSpec.toJson]/[fromJson]，供 `--concurrency` 分片
///   跨 Isolate 传递（纯数据，禁闭包）。
///
/// 铁律：本文件不做任何算法，只做「YAML/字符串 → 结构化配置」的映射。
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sudoku_core/sudoku_core.dart';
import 'package:yaml/yaml.dart';

import 'default_profiles.dart';

/// 规则集声明模式。
enum RuleSetMode {
  /// T1 档 13 项（`RuleSet.t1()`）。
  t1('t1', '基础档 13 项'),

  /// T2 档 16 项全量（`RuleSet.t2()`）。
  t2('t2', '全量 16 项'),

  /// 自定义技巧清单（`RuleSet.fromIdList`）。
  custom('custom', '自定义清单');

  const RuleSetMode(this.id, this.zhName);

  /// 稳定标识（YAML/JSON 用）。
  final String id;

  /// 简体中文名。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static RuleSetMode? tryParse(String id) {
    for (final RuleSetMode mode in RuleSetMode.values) {
      if (mode.id == id) {
        return mode;
      }
    }
    return null;
  }
}

/// 一份可序列化的出题 profile 声明（不可变）。
class ProfileSpec {
  /// 构造 profile。
  const ProfileSpec({
    required this.name,
    required this.description,
    required this.ruleSetMode,
    required this.customIds,
    required this.defaultDifficulty,
    required this.defaultTargetGivens,
    required this.symmetry,
    required this.maxAttempts,
  });

  /// profile 名（与 YAML 的 `name` 字段一致）。
  final String name;

  /// 人类可读说明。
  final String description;

  /// 规则集声明模式。
  final RuleSetMode ruleSetMode;

  /// 自定义技巧清单（仅 `ruleSetMode == custom` 时生效）。
  final List<String> customIds;

  /// 默认目标难度（生成命令未显式指定时）。
  final Difficulty defaultDifficulty;

  /// 默认目标提示数。
  final int defaultTargetGivens;

  /// 默认挖洞对称策略。
  final SymmetryMode symmetry;

  /// 单道题尝试预算的默认上限（防止命中率极低档无限空转）。
  final int maxAttempts;

  /// 由声明解析出的实际规则集（**直接对接 sudoku_core**）。
  RuleSet get ruleSet {
    switch (ruleSetMode) {
      case RuleSetMode.t1:
        return RuleSet.t1();
      case RuleSetMode.t2:
        return RuleSet.t2();
      case RuleSetMode.custom:
        return RuleSet.fromIdList(customIds);
    }
  }

  /// 序列化为 JSON map（跨 Isolate / 报表用）。
  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'description': description,
        'ruleSetMode': ruleSetMode.id,
        'customIds': List<String>.of(customIds),
        'defaultDifficulty': defaultDifficulty.id,
        'defaultTargetGivens': defaultTargetGivens,
        'symmetry': symmetry.id,
        'maxAttempts': maxAttempts,
      };

  /// 由 JSON map 反序列化（与 [toJson] 往返一致）。
  static ProfileSpec fromJson(Map<String, Object?> json) => ProfileSpec(
        name: json['name']! as String,
        description: json['description']! as String,
        ruleSetMode: RuleSetMode.tryParse(json['ruleSetMode']! as String) ??
            RuleSetMode.t2,
        customIds: <String>[
          for (final Object? v in (json['customIds'] as List<Object?>?) ??
              const <Object?>[])
            v! as String,
        ],
        defaultDifficulty: Difficulty.tryParse(
              json['defaultDifficulty'] as String? ?? Difficulty.medium.id,
            ) ??
            Difficulty.medium,
        defaultTargetGivens: (json['defaultTargetGivens'] as int?) ?? 30,
        symmetry: SymmetryMode.values.firstWhere(
          (SymmetryMode mode) =>
              mode.id == (json['symmetry'] as String? ?? SymmetryMode.none.id),
          orElse: () => SymmetryMode.none,
        ),
        maxAttempts: (json['maxAttempts'] as int?) ?? 500,
      );

  @override
  String toString() =>
      'ProfileSpec($name, mode=${ruleSetMode.id}, rules=${ruleSet.length}, '
      'target=$defaultTargetGivens, maxAttempts=$maxAttempts)';
}

/// YAML profile 文件 / 内建 profile 的载入入口。
abstract final class CliConfig {
  /// 解析 `--profile` 参数值。
  ///
  /// - `t1` / `t2` → 内建 profile（见 [default_profiles.dart]）；
  /// - 形如 `path/to/t1.yaml` → 从文件载入并校验；
  /// - 其它 → 抛 [FormatException]（统一由命令层转成错误提示）。
  static ProfileSpec loadProfile(String value, {String? baseDir}) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('profile 参数不能为空');
    }
    if (!trimmed.endsWith('.yaml') && !trimmed.endsWith('.yml')) {
      final RuleSet? builtin = _builtinByName(trimmed);
      if (builtin != null) {
        return _specFromBuiltin(trimmed);
      }
      throw FormatException('未知内建 profile「$trimmed」'
          '（可用：t1 / t2，或直接给 YAML 文件路径）');
    }
    final String path = p.isAbsolute(trimmed)
        ? trimmed
        : p.normalize(p.join(baseDir ?? Directory.current.path, trimmed));
    final File file = File(path);
    if (!file.existsSync()) {
      throw FormatException('profile 文件不存在：$path');
    }
    return parseYamlString(file.readAsStringSync(), source: path);
  }

  /// 解析 YAML 文本为 [ProfileSpec]（公开给测试用）。
  static ProfileSpec parseYamlString(String yamlText, {String source = '<yaml>'}) {
    final Object? root = loadYaml(yamlText);
    if (root is! YamlMap) {
      throw FormatException('$source：profile 必须是 YAML 映射对象');
    }
    final Object? rawName = root['name'];
    if (rawName is! String || rawName.trim().isEmpty) {
      throw FormatException('$source：缺少非空 name 字段');
    }
    final Object? rawRuleSet = root['ruleSet'];
    if (rawRuleSet is! YamlMap) {
      throw FormatException('$source：缺少 ruleSet 声明');
    }
    final String modeId = _asString(rawRuleSet['mode'], '$source/ruleSet.mode');
    final RuleSetMode? mode = RuleSetMode.tryParse(modeId);
    if (mode == null) {
      throw FormatException('$source：未知 ruleSet.mode「$modeId」'
          '（可用：t1 / t2 / custom）');
    }
    final List<String> customIds = <String>[];
    if (mode == RuleSetMode.custom) {
      final Object? rawIds = rawRuleSet['ids'];
      if (rawIds is! YamlList || rawIds.isEmpty) {
        throw FormatException('$source：custom 模式必须提供非空 ids 列表');
      }
      for (final Object? item in rawIds) {
        customIds.add(_asString(item, '$source/ruleSet.ids[]'));
      }
    }

    final Object? rawDefaults = root['defaults'];
    final Map<String, Object?> defaults = rawDefaults is YamlMap
        ? <String, Object?>{for (final MapEntry<Object?, Object?> e in rawDefaults.entries) '${e.key}': e.value}
        : const <String, Object?>{};

    final Difficulty difficulty = Difficulty.tryParse(
          _asString(defaults['difficulty'], '$source/defaults.difficulty',
              required: false),
        ) ??
        Difficulty.medium;
    final SymmetryMode symmetry = SymmetryMode.values.firstWhere(
      (SymmetryMode s) =>
          s.id == _asString(defaults['symmetry'], '$source/defaults.symmetry',
              required: false),
      orElse: () => SymmetryMode.none,
    );

    return ProfileSpec(
      name: rawName.trim(),
      description: _asString(root['description'], '$source/description',
          required: false),
      ruleSetMode: mode,
      customIds: customIds,
      defaultDifficulty: difficulty,
      defaultTargetGivens: _asInt(defaults['targetGivens'],
              '$source/defaults.targetGivens', fallback: 30) ??
          30,
      symmetry: symmetry,
      maxAttempts:
          _asInt(defaults['maxAttempts'], '$source/defaults.maxAttempts',
              fallback: 500) ??
              500,
    );
  }

  /// 按内建名取规则集（null 表示未知）。
  static RuleSet? _builtinByName(String name) {
    for (final ProfileSpec spec in kBuiltinProfileSpecs) {
      if (spec.name == name) {
        return spec.ruleSet;
      }
    }
    return null;
  }

  /// 由内建 profile 声明构造 ProfileSpec。
  static ProfileSpec _specFromBuiltin(String name) {
    for (final ProfileSpec spec in kBuiltinProfileSpecs) {
      if (spec.name == name) {
        return spec;
      }
    }
    throw FormatException('未知内建 profile「$name」');
  }

  // ------------------------------------------------------------ 类型助手

  static String _asString(Object? value, String path, {bool required = true}) {
    if (value is String) {
      return value;
    }
    if (!required) {
      return '';
    }
    throw FormatException('$path：期望字符串，实际 ${value.runtimeType}');
  }

  static int? _asInt(Object? value, String path, {int? fallback}) {
    if (value == null) {
      return fallback;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('$path：期望整数，实际 ${value.runtimeType}');
  }
}
