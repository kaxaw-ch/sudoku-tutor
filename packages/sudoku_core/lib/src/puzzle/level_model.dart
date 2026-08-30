/// 关卡模型（T-CORE-09：doc 06 §4.3 关卡 JSON schema 权威定义）。
///
/// [LessonLevel] 覆盖 doc 06 §4.3 全部字段：
/// `schemaVersion` / `id` / `chapter` / `order` / `kind` / `title` / `intro` /
/// `techniqueTags` / `puzzle81` / `solution81` / `poolRef` / `script`。
///
/// ⚠️ 三方对照结论（doc 06 §4.3 vs CLI 产物 vs 本模型）：
/// 1. 候选 JSON（export-level 产物）与 doc 06 §4.3 **字段名完全一致**（含 `cell` 键）；
/// 2. doc 06 §4.3 无 `givenMask`/`narration` 字段——本模型按任务要求
///    **扩展可选** `narration`（教学旁白数组，序列化时非空才输出）与
///    `givenMask`（'1'/'0' 字符串，供试炼关校验盘面；同样非空才输出），
///    不破坏既有字段的读写兼容；
/// 3. 关卡 codec 见 `level_codec.dart`，本文件只承载模型与类型。
library;

import 'package:meta/meta.dart';

import '../model/digit.dart';
import '../techniques/technique_id.dart';
import 'puzzle.dart';
import 'solution_script.dart';

/// 关卡 schema 版本（doc 06 §7.2 `kLevelSchemaVersion`）。
///
/// ⚠️ 与 CLI `export_level_command.dart` 的 `kLevelSchemaVersion` 保持一致（=1）；
/// `level_codec.dart` 在解码时校验。
const int kLevelSchemaVersion = 1;

/// 关卡类型（doc 06 §4.3 `LevelKind`）。
enum LevelKind {
  /// 原理演示关（盘面只读，逐步播放脚本）。
  demo('demo', '演示'),

  /// 引导实操关（玩家可自由填数，脚本作三级提示锚点）。
  guidedPractice('guidedPractice', '实操'),

  /// 验收试炼关（盘面从题池抽取，`poolRef` 指向题池）。
  trial('trial', '试炼');

  const LevelKind(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文名。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static LevelKind? tryParse(String id) {
    for (final LevelKind value in LevelKind.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 一关（一关一 JSON，doc 06 §4.3 / PRD C-25）。
@immutable
class LessonLevel {
  /// 构造关卡。
  ///
  /// - [script] 演示关必填、实操关可选、试炼关可为空（题池抽取）；
  /// - [narration] 教学旁白数组（任务要求的扩展字段，doc 06 §4.3 未定义），
  ///   为空时序列化省略；
  /// - [givenMask] 81 字符 '1'/'0'，为空时序列化省略（按题面推导）。
  LessonLevel({
    this.schemaVersion = kLevelSchemaVersion,
    required this.id,
    required this.chapter,
    required this.order,
    required this.kind,
    required     this.title,
    this.intro = '',
    List<String> narration = const <String>[],
    Set<TechniqueId> techniqueTags = const <TechniqueId>{},
    required this.puzzle81,
    required this.solution81,
    this.givenMask,
    this.poolRef,
    this.script,
  })  : techniqueTags = Set<TechniqueId>.unmodifiable(techniqueTags),
        narration = List<String>.unmodifiable(narration);

  /// 关卡 JSON schema 版本（应为 [kLevelSchemaVersion]）。
  final int schemaVersion;

  /// 关卡唯一标识（如 `ch1_l03`）。
  final String id;

  /// 所属章节（0 起）。
  final int chapter;

  /// 章内序号（从 1 开始）。
  final int order;

  /// 关卡类型（演示 | 实操 | 试炼）。
  final LevelKind kind;

  /// 标题。
  final String title;

  /// 简介（讲解内容）。
  final String intro;

  /// 教学旁白数组（每步讲解的补充文案；doc 06 §4.3 未定义，本模型扩展）。
  final List<String> narration;

  /// 本关目标/涉及的技巧标签。
  final Set<TechniqueId> techniqueTags;

  /// 题面 81 字符串（`.`/`0` = 空）。
  final String puzzle81;

  /// 终局解 81 字符串（1..9）。
  final String solution81;

  /// 原始题面给定掩码（81 字符 '1'/'0'；为 `null` 时按题面推导）。
  final String? givenMask;

  /// 试炼关的题池引用（如 `pools/ch1`）；演示/实操关为 `null`。
  final String? poolRef;

  /// 解题脚本（演示关必填；实操关可选，用于三级提示锚点）。
  final SolutionScript? script;

  /// 题面提示数。
  int get givenCount {
    int count = 0;
    for (final int code in puzzle81.codeUnits) {
      if (code != kEmptyChar.codeUnitAt(0) && code != '0'.codeUnitAt(0)) {
        count++;
      }
    }
    return count;
  }

  /// 是否有解题脚本。
  bool get hasScript => script != null && script!.isNotEmpty;

  /// 转换为可参与引擎求解的题目条目（供回放/提示复用）。
  LevelPuzzle toLevelPuzzle() => LevelPuzzle(
        puzzle81: puzzle81,
        solution81: solution81,
        givenMask: givenMask,
        difficulty: null,
        techniques: techniqueTags,
        script: script,
      );

  @override
  String toString() => 'LessonLevel($id, ${kind.id}, $title, '
      'givens=$givenCount, script=${script?.stepCount ?? 0}步)';
}
