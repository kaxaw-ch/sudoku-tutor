/// 内建出题 profile（T1 / T2）与五档难度默认参数的单一登记点。
///
/// 对应 doc 06 §3.2 `lib/src/config/default_profiles.dart`、
/// doc 07 T-CLI-01「`--profile t2.yaml` 能声明式启用规则集」。
/// 规则集定义**直接取用 `sudoku_core` 的 `RuleSet`**，本文件零算法实现。
library;

import 'package:sudoku_core/sudoku_core.dart';

import 'cli_config.dart';

/// 内建 profile 名 → 规则集映射（作为 `--profile <name>` 的快捷方式）。
///
/// `RuleSet.t1()`/`t2()` 非常量构造，故 map 用 `final`（库加载时求值一次）。
final Map<String, RuleSet> kBuiltinRuleSets = <String, RuleSet>{
  // T1：13 项（全部技巧减去 T2 新增的 3 项，对齐 `RuleSet.t1()`）。
  't1': RuleSet.t1(),
  // T2（本期 scope）：16 项全量。
  't2': RuleSet.t2(),
};

/// 各档难度出题时的默认目标提示数（供 generate/export-* 未显式传参时使用）。
///
/// ⚠️ 仅为「初始提示数」，不是难度保证；最终难度由逐级求解分级决定，
/// 命中率不足时管线会自动把提示数下调（自适应降洞，见 `GenerationPipeline`）。
///
/// 取值依据批次 D 实测（doc 07 风险 A-06）：提示数 20–24 时 hard 档
/// 命中率约 15%、master 约 1.3%；medium 档（nakedTriple/hiddenTriple/xWing
/// 为最高技巧）在随机生成下命中率≈0%，属**分档口径问题**，已回报主理人。
const Map<Difficulty, int> kDefaultTargetGivensByDifficulty = <Difficulty, int>{
  Difficulty.beginner: 36,
  Difficulty.easy: 32,
  Difficulty.medium: 26,
  Difficulty.hard: 24,
  Difficulty.master: 22,
};

/// 各档难度对应的默认规则集名（大师档允许放开 T2 三项）。
const Map<Difficulty, String> kDefaultProfileByDifficulty = <Difficulty, String>{
  Difficulty.beginner: 't1',
  Difficulty.easy: 't1',
  Difficulty.medium: 't1',
  Difficulty.hard: 't1',
  Difficulty.master: 't2',
};

/// 内建 profile 声明（YAML 落盘内容与 `profiles/*.yaml` 保持一致）。
///
/// 提供 `builtinProfileSpec` 供代码内直接构造 `ProfileSpec`，
/// 同时用于生成 `profiles/t1.yaml`、`profiles/t2.yaml` 的可读清单。
const List<ProfileSpec> kBuiltinProfileSpecs = <ProfileSpec>[
  ProfileSpec(
    name: 't1',
    description: '基础档规则集：13 项（不含 T2 新增的鳍形 X 翼 / W 翼 / 简单涂色）。',
    ruleSetMode: RuleSetMode.t1,
    customIds: <String>[],
    defaultDifficulty: Difficulty.medium,
    defaultTargetGivens: 30,
    symmetry: SymmetryMode.none,
    maxAttempts: 500,
  ),
  ProfileSpec(
    name: 't2',
    description: '全量规则集：16 项（含鳍形 X 翼 / W 翼 / 简单涂色），本期默认推荐档。',
    ruleSetMode: RuleSetMode.t2,
    customIds: <String>[],
    defaultDifficulty: Difficulty.medium,
    defaultTargetGivens: 30,
    symmetry: SymmetryMode.none,
    maxAttempts: 500,
  ),
];
