/// 设置模型（P0-STO-08 冻结清单的领域表达）。
///
/// 冻结清单：应用主题（本期仅白色实现，粉/蓝置灰预留）、棋盘主题、音效开关、
/// 震动开关、自动候选数、错误标红、计时显示、相同数字高亮、自由练习提示次数、
/// 界面语言（简体中文 / English）、存档导入/导出、清空错题本、重置全部进度、关于与版本号、
/// 开发者模式入口（隐藏）。
/// 其中「导入/导出/清空/重置/关于」属于动作而非布尔开关，不在此建模。
library;

import 'package:sudoku_tutor/l10n/language.dart';

/// 主题插槽（P0-UI-01：白/粉/蓝三套令牌插槽）。
///
/// 本期只实现 [white]，[pink] 与 [blue] 为置灰占位（UI 显示为不可选）。
/// ⚠️ 本枚举定义在 domain 层，`ui/theme/color_tokens.dart` 消费同一枚举，
/// 保证「设置项」与「主题令牌」二者永远指向同一事实源，不会各自漂移。
enum ThemeSlot {
  /// 白色主题（主方案，本期唯一实现）。
  white('white', '白色'),

  /// 粉色主题（置灰预留）。
  pink('pink', '粉色'),

  /// 蓝色主题（置灰预留）。
  blue('blue', '蓝色');

  const ThemeSlot(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文名。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static ThemeSlot? tryParse(String id) {
    for (final ThemeSlot value in ThemeSlot.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 棋盘配色主题。
///
/// 与 [ThemeSlot] 的整套应用外观不同，本枚举只控制数独棋盘本身，做题、教学
/// 演示、引导实操与试炼共用同一选择。
enum BoardThemeStyle {
  /// 原有的经典蓝色棋盘。
  blue('blue', '经典蓝色'),

  /// 暖白、鼠尾草绿与青绿色组成的清新棋盘（默认）。
  green('green', '清新绿色');

  const BoardThemeStyle(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 设置页显示名称。
  final String zhName;

  /// 按 [id] 反查；未知返回 `null`。
  static BoardThemeStyle? tryParse(String id) {
    for (final BoardThemeStyle value in BoardThemeStyle.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 自由练习提示次数配额（P0-PRA-04）。
enum HintQuota {
  /// 关闭（不提供提示）。
  off('off', '关闭'),

  /// 每局最多 3 次。
  three('three', '3 次'),

  /// 每局最多 5 次。
  five('five', '5 次'),

  /// 不限次数（默认）。
  unlimited('unlimited', '不限');

  const HintQuota(this.id, this.zhName);

  /// JSON 序列化用的稳定标识。
  final String id;

  /// 简体中文名。
  final String zhName;

  /// 是否为 [unlimited]。
  bool get isUnlimited => this == HintQuota.unlimited;

  /// 配额次数（[off] 为 0，[unlimited] 视为足够大的上限）。
  int get count => switch (this) {
        HintQuota.off => 0,
        HintQuota.three => 3,
        HintQuota.five => 5,
        HintQuota.unlimited => 1 << 20,
      };

  /// 按 [id] 反查；未知返回 `null`。
  static HintQuota? tryParse(String id) {
    for (final HintQuota value in HintQuota.values) {
      if (value.id == id) {
        return value;
      }
    }
    return null;
  }
}

/// 全局设置状态（不可变值对象）。
class SettingsState {
  /// 构造设置状态（各字段与 P0-STO-08 冻结清单一一对应）。
  const SettingsState({
    this.theme = ThemeSlot.white,
    this.boardTheme = BoardThemeStyle.green,
    this.soundOn = false,
    this.hapticOn = true,
    this.autoCandidates = false,
    this.markErrors = true,
    this.showTimer = true,
    this.highlightSameDigit = true,
    this.hintQuota = HintQuota.unlimited,
    this.language = 'zh',
    this.developerMode = false,
  });

  /// 主题插槽（本期仅 [ThemeSlot.white] 有真实实现）。
  final ThemeSlot theme;

  /// 棋盘配色主题（蓝色 / 绿色）。
  final BoardThemeStyle boardTheme;

  /// 音效开关（默认关闭，P0-UI-09）。
  final bool soundOn;

  /// 震动开关（移动端默认开，桌面无操作）。
  final bool hapticOn;

  /// 自动候选数（默认关闭；与手动笔记互斥，P0-PRA-07）。
  final bool autoCandidates;

  /// 错误标红（只描边不填底）。
  final bool markErrors;

  /// 计时显示。
  final bool showTimer;

  /// 相同数字高亮。
  final bool highlightSameDigit;

  /// 自由练习提示配额。
  final HintQuota hintQuota;

  /// 界面语言（`zh` / `en`，默认简体中文）。
  final String language;

  /// 开发者模式（连点版本号 7 次进入，隐藏入口）。
  final bool developerMode;

  /// 返回替换部分字段后的副本（其余字段保持不变）。
  SettingsState copyWith({
    ThemeSlot? theme,
    BoardThemeStyle? boardTheme,
    bool? soundOn,
    bool? hapticOn,
    bool? autoCandidates,
    bool? markErrors,
    bool? showTimer,
    bool? highlightSameDigit,
    HintQuota? hintQuota,
    String? language,
    bool? developerMode,
  }) =>
      SettingsState(
        theme: theme ?? this.theme,
        boardTheme: boardTheme ?? this.boardTheme,
        soundOn: soundOn ?? this.soundOn,
        hapticOn: hapticOn ?? this.hapticOn,
        autoCandidates: autoCandidates ?? this.autoCandidates,
        markErrors: markErrors ?? this.markErrors,
        showTimer: showTimer ?? this.showTimer,
        highlightSameDigit: highlightSameDigit ?? this.highlightSameDigit,
        hintQuota: hintQuota ?? this.hintQuota,
        language: language ?? this.language,
        developerMode: developerMode ?? this.developerMode,
      );

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'theme': theme.id,
        'boardTheme': boardTheme.id,
        'soundOn': soundOn,
        'hapticOn': hapticOn,
        'autoCandidates': autoCandidates,
        'markErrors': markErrors,
        'showTimer': showTimer,
        'highlightSameDigit': highlightSameDigit,
        'hintQuota': hintQuota.id,
        'language': language,
        'developerMode': developerMode,
      };

  /// 由 JSON map 反序列化；未知枚举值一律回退默认（迁移/损坏兜底）。
  factory SettingsState.fromJson(Map<String, Object?> json) => SettingsState(
        theme: ThemeSlot.tryParse(json['theme']! as String) ?? ThemeSlot.white,
        boardTheme: json['boardTheme'] is String
            ? BoardThemeStyle.tryParse(json['boardTheme']! as String) ??
                BoardThemeStyle.green
            : BoardThemeStyle.green,
        soundOn: (json['soundOn'] as bool?) ?? false,
        hapticOn: (json['hapticOn'] as bool?) ?? true,
        autoCandidates: (json['autoCandidates'] as bool?) ?? false,
        markErrors: (json['markErrors'] as bool?) ?? true,
        showTimer: (json['showTimer'] as bool?) ?? true,
        highlightSameDigit: (json['highlightSameDigit'] as bool?) ?? true,
        hintQuota: HintQuota.tryParse(json['hintQuota']! as String) ??
            HintQuota.unlimited,
        language: AppLanguages.normalize(json['language'] as String?),
        developerMode: (json['developerMode'] as bool?) ?? false,
      );
}
