/// Application localization and localized presentation helpers.
///
/// Chinese remains the source/default language. English UI copy lives in one
/// catalog so every screen can switch immediately without rebuilding domain
/// objects. Structured lesson/hint data is rendered separately below, which
/// keeps all current and future generated Sudoku steps bilingual.
library;

export 'language.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_detector.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_message_repository.dart';

import 'language.dart';

/// Localized strings available through Flutter's [Localizations] widget.
class AppLocalizations {
  /// Creates a catalog for [locale].
  const AppLocalizations(this.locale);

  /// Active locale.
  final Locale locale;

  /// Fallback used by isolated widget tests that mount a page without the app
  /// root. Keeping this fallback Chinese preserves the product default.
  static const AppLocalizations fallback =
      AppLocalizations(Locale(AppLanguages.chinese, 'CN'));

  /// Supported application locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale(AppLanguages.chinese, 'CN'),
    Locale(AppLanguages.english),
  ];

  /// Flutter localization delegate.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Returns the nearest catalog, or the Chinese fallback when a test mounts a
  /// screen without the application localization delegate.
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ?? fallback;

  /// Whether English is active.
  bool get isEnglish => locale.languageCode == AppLanguages.english;

  /// Current normalized language code.
  String get languageCode =>
      isEnglish ? AppLanguages.english : AppLanguages.chinese;

  /// Whether [chinese] has an explicit English catalog entry.
  ///
  /// The localization coverage test uses this to prevent newly added visible
  /// copy from silently falling back to Chinese in the English locale.
  bool hasEnglishTranslation(String chinese) =>
      _englishText.containsKey(chinese) ||
      _englishWikiText.containsKey(chinese);

  /// Translates a Chinese source string and replaces `{name}` placeholders.
  ///
  /// Source strings deliberately remain readable at call sites and in existing
  /// Chinese widget tests. English coverage is audited by localization tests.
  String text(
    String chinese, [
    Map<String, Object?> values = const <String, Object?>{},
  ]) {
    String result = isEnglish
        ? (_englishText[chinese] ?? _englishWikiText[chinese] ?? chinese)
        : chinese;
    for (final MapEntry<String, Object?> value in values.entries) {
      result = result.replaceAll('{${value.key}}', '${value.value ?? ''}');
    }
    return result;
  }

  /// Human-readable technique name.
  String techniqueName(TechniqueId technique) =>
      isEnglish ? technique.enName : technique.zhName;

  /// Human-readable difficulty name.
  String difficultyName(Difficulty difficulty) => isEnglish
      ? switch (difficulty) {
          Difficulty.beginner => 'Beginner',
          Difficulty.easy => 'Easy',
          Difficulty.medium => 'Medium',
          Difficulty.hard => 'Hard',
          Difficulty.master => 'Master',
        }
      : difficulty.zhName;

  /// Human-readable board theme name.
  String boardThemeName(BoardThemeStyle style) => isEnglish
      ? switch (style) {
          BoardThemeStyle.blue => 'Classic Blue',
          BoardThemeStyle.green => 'Fresh Green',
        }
      : style.zhName;

  /// Human-readable app theme name.
  String themeName(ThemeSlot slot) => isEnglish
      ? switch (slot) {
          ThemeSlot.white => 'White',
          ThemeSlot.pink => 'Pink',
          ThemeSlot.blue => 'Blue',
        }
      : slot.zhName;

  /// Human-readable hint quota.
  String hintQuotaName(HintQuota quota) => isEnglish
      ? switch (quota) {
          HintQuota.off => 'Off',
          HintQuota.three => '3 hints',
          HintQuota.five => '5 hints',
          HintQuota.unlimited => 'Unlimited',
        }
      : quota.zhName;

  /// Human-readable hint level.
  String hintLevelName(HintLevel level) => isEnglish
      ? switch (level) {
          HintLevel.level1 => 'Level 1',
          HintLevel.level2 => 'Level 2',
          HintLevel.level3 => 'Level 3',
        }
      : level.zhName;

  /// Human-readable level status.
  String levelStatusName(LevelStatus status) => isEnglish
      ? switch (status) {
          LevelStatus.locked => 'Locked',
          LevelStatus.unlocked => 'Unlocked',
          LevelStatus.completed => 'Completed',
        }
      : status.zhName;

  /// Full level-kind label used on the learning map.
  String levelKindName(LevelKind kind) => isEnglish
      ? switch (kind) {
          LevelKind.demo => 'Tutorial Demo',
          LevelKind.guidedPractice => 'Guided Practice',
          LevelKind.trial => 'Mastery Trial',
        }
      : switch (kind) {
          LevelKind.demo => '教学演示',
          LevelKind.guidedPractice => '引导实操',
          LevelKind.trial => '综合试炼',
        };

  /// A cell label suitable for player-facing explanations.
  String cellLabel(int index) => isEnglish
      ? 'row ${Coord.rowOf(index) + 1}, column ${Coord.colOf(index) + 1}'
      : Coord.zhLabel(index);

  /// A natural-language list of cell labels.
  String cellsLabel(Iterable<int> cells) =>
      _joinNatural(cells.map(cellLabel).toList(growable: false));

  /// Localized chapter title. Production chapters use their stable number,
  /// while injected/test content falls back to its source title.
  String chapterTitle(int chapter, String fallbackTitle) {
    if (!isEnglish) {
      return fallbackTitle;
    }
    return _englishChapterTitles[chapter] ?? text(fallbackTitle);
  }

  /// Localized lesson title keyed by the stable lesson id.
  String lessonTitle(String levelId, String fallbackTitle) {
    if (!isEnglish) {
      return fallbackTitle;
    }
    return _englishLessonTitles[levelId] ?? text(fallbackTitle);
  }

  /// Localized lesson introduction keyed by the stable lesson id.
  String lessonIntro(String levelId, String fallbackIntro) {
    if (!isEnglish) {
      return fallbackIntro;
    }
    return _englishLessonIntros[levelId] ?? text(fallbackIntro);
  }

  /// Renders every structured tutorial step in the selected language.
  ///
  /// Chinese keeps the authored narration. English is generated from the
  /// technique and conclusions, so all 1,900+ existing steps and newly
  /// generated lessons receive meaningful English copy without duplicating
  /// large puzzle assets.
  String scriptNarration(ScriptStep step, String? chineseNarration) {
    if (!isEnglish) {
      final String source = chineseNarration?.trim() ?? '';
      return source.isNotEmpty
          ? NarrationFormat.localizeCoordinates(source)
          : '（本步为「${step.techniqueId.zhName}」讲解）';
    }

    final String technique = techniqueName(step.techniqueId);
    final String focus = cellsLabel(step.involvedCells);
    final String placement = _placementsLabel(step.placements);
    final String elimination = _eliminationsLabel(step.eliminations);

    if (step.techniqueId == TechniqueId.nakedSingle &&
        step.placements.isNotEmpty) {
      final Placement item = step.placements.first;
      return '${cellLabel(item.cellIndex)} has only one candidate left, '
          '${item.digit}, so place ${item.digit} in this cell.';
    }
    if (step.techniqueId == TechniqueId.hiddenSingle &&
        step.placements.isNotEmpty) {
      final Placement item = step.placements.first;
      return 'In the highlighted unit, ${item.digit} can appear only at '
          '${cellLabel(item.cellIndex)}, so place it there.';
    }

    final List<String> conclusions = <String>[
      if (elimination.isNotEmpty) 'Eliminate $elimination',
      if (placement.isNotEmpty) 'place $placement',
    ];
    final String focusSentence = focus.isEmpty ? '' : ' Focus on $focus.';
    if (conclusions.isEmpty) {
      return 'This step demonstrates $technique.$focusSentence';
    }
    return '$technique applies here.$focusSentence '
        '${_capitalize(_joinNatural(conclusions))}.';
  }

  /// Localizes a progressively revealed hint from its structured data.
  String hintNarration(HintState hint) {
    if (!isEnglish) {
      return hint.narration;
    }
    final String technique = techniqueName(hint.techniqueId);
    return switch (hint.level) {
      HintLevel.level1 =>
        'Try $technique here. The relevant area is highlighted.',
      HintLevel.level2 =>
        'The key cells for $technique are ${cellsLabel(hint.highlightedCells)}.',
      HintLevel.level3 => hint.eliminations.isEmpty
          ? 'Review the highlighted $technique pattern.'
          : 'You can eliminate ${_eliminationsLabel(hint.eliminations)}.',
    };
  }

  /// Localizes a hint-unavailable reason.
  String hintUnavailable(HintUnavailableReason? reason) {
    if (!isEnglish) {
      return reason?.zhMessage ?? '暂无可用提示';
    }
    return switch (reason) {
      HintUnavailableReason.quotaOff => 'Hints are turned off in Settings.',
      HintUnavailableReason.quotaExhausted =>
        'You have used all hints available for this game.',
      HintUnavailableReason.noTechnique =>
        'No suitable technique was found. Check the board for mistakes first.',
      HintUnavailableReason.maxLevelReached =>
        'This hint is fully expanded. Make progress to reveal the next step.',
      HintUnavailableReason.noSafeDetail =>
        'This is the most detail available without revealing the answer.',
      null => 'No hint is available right now.',
    };
  }

  /// Provides English mistake coaching from the structured mistake event.
  /// Chinese retains the varied authored templates loaded from the asset.
  MistakeMessage mistakeMessage(
    MistakeEvent event,
    MistakeMessage chineseMessage,
  ) {
    if (!isEnglish) {
      return chineseMessage;
    }
    final String cell = cellLabel(event.cellIndex);
    final String digit = '${event.digit}';
    final String technique = event.techniqueId == null
        ? 'the intended technique'
        : techniqueName(event.techniqueId!);
    return switch (event.type) {
      MistakeType.wrongFill => MistakeMessage(
          what: 'Placing $digit in $cell conflicts with the puzzle solution.',
          how: 'Check the numbers already present in the same row, column, and '
              'box, then eliminate impossible candidates before placing a digit.',
        ),
      MistakeType.deletedTrueCandidate => MistakeMessage(
          what: 'Candidate $digit was removed from $cell, but it is still '
              'possible there.',
          how: 'Restore the candidate and remove it only after a row, column, '
              'box, or technique gives a definite reason.',
        ),
      MistakeType.prematureFill => MistakeMessage(
          what: 'Placing $digit in $cell skips the reasoning required by '
              '$technique.',
          how: 'Find the complete $technique pattern first, apply its '
              'eliminations, and place a digit only when the conclusion is forced.',
        ),
    };
  }

  /// Converts surfaced domain/codec failures to safe player-facing English.
  /// Error codes are retained for support while Chinese internal details are
  /// never leaked into the English UI.
  String errorMessage(Object error) {
    final String raw = '$error';
    if (!isEnglish) {
      return raw;
    }
    for (final MapEntry<String, String> entry
        in _englishErrorFragments.entries) {
      if (raw.contains(entry.key)) {
        return entry.value;
      }
    }
    final RegExpMatch? code = RegExp(r'E_[A-Z_]+_\d+').firstMatch(raw);
    return code == null
        ? 'Something went wrong. Please try again.'
        : 'Something went wrong. Please try again. (${code.group(0)})';
  }

  String _placementsLabel(Iterable<Placement> placements) =>
      _joinNatural(<String>[
        for (final Placement item in placements)
          '${item.digit} in ${cellLabel(item.cellIndex)}',
      ]);

  String _eliminationsLabel(Iterable<Elimination> eliminations) =>
      _joinNatural(<String>[
        for (final Elimination item in eliminations)
          'candidate ${item.digit} from ${cellLabel(item.cellIndex)}',
      ]);

  String _joinNatural(List<String> items) {
    if (items.isEmpty) {
      return '';
    }
    if (!isEnglish) {
      return items.join('、');
    }
    if (items.length == 1) {
      return items.first;
    }
    if (items.length == 2) {
      return '${items.first} and ${items.last}';
    }
    return '${items.sublist(0, items.length - 1).join(', ')}, and ${items.last}';
  }

  static String _capitalize(String value) => value.isEmpty
      ? value
      : '${value.substring(0, 1).toUpperCase()}${value.substring(1)}';
}

/// Convenient localized catalog access from any widget context.
extension AppLocalizationsBuildContext on BuildContext {
  /// Nearest application localization catalog (Chinese fallback in isolated
  /// tests).
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == AppLanguages.chinese ||
      locale.languageCode == AppLanguages.english;

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const Map<int, String> _englishChapterTitles = <int, String>{
  0: 'Chapter 0 · Rules & Foundations',
  1: 'Chapter 1 · Triples & X-Wing',
  2: 'Chapter 2 · Finned X-Wing & Swordfish',
  3: 'Chapter 3 · XY-Wing & XYZ-Wing',
};

const Map<String, String> _englishLessonTitles = <String, String>{
  'ch0_l01': 'Rules · Naked Single',
  'ch0_l02': 'Rules · Hidden Single',
  'ch0_l03': 'Naked Single (Demo)',
  'ch0_l04': 'Hidden Single (Demo)',
  'ch0_l05': 'Naked Pair (Demo)',
  'ch0_l06': 'Naked Pair (Practice 1)',
  'ch0_l07': 'Hidden Pair (Demo)',
  'ch0_l08': 'Hidden Pair (Practice 1)',
  'ch0_l09': 'Pointing & Claiming (Demo)',
  'ch0_l10': 'Pointing & Claiming (Practice 1)',
  'ch1_l01': 'Naked Triple (Demo)',
  'ch1_l02': 'Hidden Triple (Demo)',
  'ch1_l03': 'Naked Triple (Practice 1)',
  'ch1_l04': 'Hidden Triple (Practice 1)',
  'ch1_l05': 'X-Wing (Demo)',
  'ch1_l06': 'X-Wing (Practice 1)',
  'ch1_l07': 'X-Wing (Trial)',
  'ch2_l01': 'Finned X-Wing (Demo)',
  'ch2_l02': 'Swordfish (Demo)',
  'ch2_l03': 'Finned X-Wing (Practice 1)',
  'ch2_l04': 'Finned X-Wing (Practice 2)',
  'ch2_l05': 'Swordfish (Practice 1)',
  'ch2_l06': 'Swordfish (Practice 2)',
  'ch2_l07': 'Finned X-Wing (Trial)',
  'ch3_l01': 'XY-Wing (Demo 1)',
  'ch3_l02': 'XY-Wing (Demo 2)',
  'ch3_l03': 'XYZ-Wing (Demo)',
  'ch3_l04': 'XY-Wing (Practice 1)',
  'ch3_l05': 'XY-Wing (Practice 2)',
  'ch3_l06': 'XY-Wing (Practice 3)',
  'ch3_l07': 'XYZ-Wing (Practice 1)',
  'ch3_l08': 'XYZ-Wing (Practice 2)',
  'ch3_l09': 'XYZ-Wing (Practice 3)',
  'ch3_l10': 'XYZ-Wing (Trial)',
};

const Map<String, String> _englishLessonIntros = <String, String>{
  'ch0_l01': 'Welcome to Sudoku! Start with the most common technique: a cell '
      'with only one candidate must contain that digit. Follow the demo to '
      'complete the grid one cell at a time.',
  'ch0_l02': 'When a digit has only one possible position in a row, column, or '
      'box, that position is fixed. Hidden Singles and Naked Singles are the '
      'two essential foundations of Sudoku.',
  'ch0_l03': 'Review Naked Singles: list the candidates in each cell, find a '
      'cell with only one candidate, and place it.',
  'ch0_l04': 'This lesson demonstrates Hidden Singles. Scan every row, column, '
      'and box for a digit that has only one possible position.',
  'ch0_l05': 'When two cells in one unit contain exactly the same two '
      'candidates, they form a Naked Pair. Treat them as a set and remove '
      'those candidates from the other cells in that unit.',
  'ch0_l06': 'Find a Naked Pair yourself. Look for two cells in one unit with '
      'the same two candidates, then remove those digits elsewhere in the unit.',
  'ch0_l07': 'When two digits can appear only in the same two cells of a unit, '
      'they form a Hidden Pair. Those cells belong to the pair, so their other '
      'candidates can be removed.',
  'ch0_l08': 'Practice Hidden Pairs: find two digits restricted to the same two '
      'cells in a row, column, or box, then clear the extra candidates there.',
  'ch0_l09':
      'If every candidate for a digit in a box lies on one row or column, '
          'that digit can be removed from the rest of the line. The reverse '
          'relationship is called claiming.',
  'ch0_l10': 'Practice Pointing and Claiming by finding candidates concentrated '
      'where a box crosses a row or column, then applying the resulting removals.',
  'ch1_l01': 'A Naked Triple extends a Naked Pair: three cells in one unit use '
      'only the same three digits, allowing those digits to be removed elsewhere.',
  'ch1_l02': 'A Hidden Triple occurs when three digits appear only in the same '
      'three cells of a unit. Remove every other candidate from those cells.',
  'ch1_l03':
      'Practice Naked Triples by finding three cells limited to the same '
          'three digits and removing those digits from the rest of the unit.',
  'ch1_l04': 'Practice Hidden Triples: find three digits restricted to three '
      'cells in a unit, then remove the other candidates from those cells.',
  'ch1_l05': 'An X-Wing appears when one digit has exactly the same two candidate '
      'columns in two rows. Remove that digit from other cells in those columns; '
      'the row/column roles can also be reversed.',
  'ch1_l06':
      'Find an X-Wing yourself: choose one digit and look for two rows or '
          'columns whose candidates align in the same two opposite units.',
  'ch1_l07': 'Chapter 1 mastery trial: solve a puzzle selected from the X-Wing '
      'pool. The completed grid is checked automatically.',
  'ch2_l01': 'A Finned X-Wing is an X-Wing variant with an extra fin candidate '
      'in the same box as a missing corner. It still supports a limited '
      'elimination, including the Sashimi form.',
  'ch2_l02': 'Swordfish extends X-Wing to three rows and three columns. If a '
      'digit in three rows is confined to three columns, remove it elsewhere '
      'in those columns.',
  'ch2_l03':
      'Practice Finned X-Wing: identify the basic X-Wing, locate the fin '
          'in the missing corner\'s box, and verify the supported elimination.',
  'ch2_l04': 'Try another Finned X-Wing. The fin may appear in a Sashimi '
      'arrangement, so check every candidate relationship carefully.',
  'ch2_l05': 'Practice Swordfish by finding one digit whose candidates across '
      'three rows or columns are confined to three opposite units.',
  'ch2_l06':
      'This Swordfish is less obvious. Track one digit and see whether its '
          'candidate positions form a three-by-three fish pattern.',
  'ch2_l07': 'Chapter 2 mastery trial: solve a puzzle selected from the Finned '
      'X-Wing and Sashimi pool.',
  'ch3_l01':
      'In an XY-Wing, a bivalue pivot XY sees pincers XZ and YZ. Any cell '
          'that sees both pincers cannot contain Z.',
  'ch3_l02': 'Review XY-Wing: the pivot is XY, the pincers are XZ and YZ, and '
      'each pincer must see the pivot.',
  'ch3_l03':
      'XYZ-Wing strengthens XY-Wing: a pivot XYZ sees pincers XZ and YZ. '
          'A cell that sees all three pattern cells cannot contain Z.',
  'ch3_l04': 'Find an XY-Wing by starting with a bivalue pivot and checking '
      'whether it connects to matching XZ and YZ pincers.',
  'ch3_l05':
      'Continue practicing XY-Wing. Both pincers must see the pivot, and '
          'an elimination cell must see both pincers.',
  'ch3_l06': 'One final XY-Wing practice puzzle. Repetition will make this '
      'classic wing pattern much easier to recognize.',
  'ch3_l07':
      'Practice XYZ-Wing: use a trivalue pivot and two pincers that share '
          'two of its digits. Eliminate from cells that see all three.',
  'ch3_l08':
      'Try another XYZ-Wing. Verify the pivot/pincer candidates and find '
          'the elimination cells visible to all three pattern cells.',
  'ch3_l09': 'Final XYZ-Wing practice: combine everything you have learned '
      'before the Chapter 3 trial.',
  'ch3_l10':
      'Chapter 3 mastery trial: solve a puzzle selected from the XYZ-Wing '
          'pool to complete the chapter.',
};

const Map<String, String> _englishErrorFragments = <String, String>{
  '挑战编号无效': 'The challenge ID is invalid.',
  '挑战难度不受支持': 'This challenge difficulty is not supported.',
  '挑战题面格式无效': 'The challenge puzzle is invalid.',
  '挑战规则参数无效': 'The challenge rules are invalid.',
  '挑战题目不是唯一解': 'The challenge puzzle does not have a unique solution.',
  '挑战题目无解': 'The challenge puzzle has no solution.',
  '挑战题面无法读取': 'The challenge puzzle could not be read.',
  '成绩数据超出有效范围': 'The result data is outside the valid range.',
  '两份成绩不属于同一场挑战': 'These two results do not belong to the same challenge.',
  '代码过长': 'The code is too long.',
  '不是有效的挑战码': 'This is not a valid challenge code.',
  '不是有效的成绩码': 'This is not a valid result code.',
  '代码校验失败': 'Code verification failed. Copy the complete code again.',
  '代码内容格式无效': 'The code content is invalid.',
  '代码无法解析': 'The code could not be parsed. Check that it was copied in full.',
  '代码版本不受支持': 'This code version is not supported. Update the app first.',
  '代码缺少必要数据': 'The code is missing required data.',
  '需为 1–16 个字符': 'The name must contain 1–16 characters.',
  '剪贴板为空': 'The clipboard is empty.',
  '题目无解': 'The puzzle has no solution.',
  '非唯一解': 'The puzzle does not have a unique solution.',
  '格式非法': 'The imported content has an invalid format.',
  '读取导入文件失败': 'The import file could not be read.',
  '不是合法的 JSON': 'The selected file is not valid JSON.',
  '存档读取失败': 'The saved progress could not be read.',
  '存档写入失败': 'The saved progress could not be written.',
  '课程加载失败': 'The curriculum could not be loaded.',
  '题库资产缺失': 'A required puzzle-bank asset is missing.',
  '引擎':
      'The puzzle engine could not complete this operation. Please try again.',
};

/// English translations for visible source strings. Dynamic values use named
/// placeholders and are supplied by the calling widget.
const Map<String, String> _englishText = <String, String>{
  '数独教学': 'Sudoku Tutor',
  '零门槛入门数独': 'Learn Sudoku from Scratch',
  '学习地图': 'Learning Map',
  '自由练习': 'Free Play',
  '设置': 'Settings',
  '切换到英文': 'Switch to English',
  '切换到中文': 'Switch to Chinese',
  '开始学习': 'Start Learning',
  '跳过': 'Skip',
  '即将推出': 'Coming Soon',
  '下一步': 'Next',
  '上一步': 'Previous',
  '重播': 'Replay',
  '返回': 'Back',
  '取消': 'Cancel',
  '继续': 'Continue',
  '放弃': 'Give Up',
  '重试': 'Retry',
  '导入': 'Import',
  '清空': 'Clear',
  '重置': 'Reset',
  '解锁': 'Unlock',
  '选择难度': 'Select Difficulty',
  '技巧 Wiki': 'Technique Wiki',
  '返回学习地图': 'Back to Learning Map',
  '从定义到落子依据': 'From Definitions to Practical Moves',
  '收录引擎支持的 {count} 种技巧。点击条目查看识别方法、用法和易错点。':
      'Explore all {count} techniques supported by the engine. Open an item '
          'to learn how to recognize and use it, plus common pitfalls.',
  '搜索中文名、英文名或定义': 'Search names or definitions',
  '清除搜索': 'Clear Search',
  '全部技巧': 'All Techniques',
  '找到 {count} 项': '{count} results',
  '没有找到相关技巧': 'No matching techniques found',
  '定义': 'Definition',
  '怎么使用': 'How to Use It',
  '注意': 'Watch Out',
  '从行、列、宫规则到候选数，跟着分步动画一点点看懂数独，不需要任何基础。':
      'Learn rows, columns, boxes, and candidates through step-by-step '
          'animations—no prior experience needed.',
  '四章渐进学习': 'Four Progressive Chapters',
  '基础 → 进阶技巧 → 实战，四章 34 关循序渐进，演示 / 实操 / 试炼三种关卡层层递进。':
      'Progress through 34 lessons in four chapters, from foundations to '
          'advanced techniques, with demos, practice, and mastery trials.',
  '海量题库 · 即时反馈': 'A Large Puzzle Bank · Instant Feedback',
  '五大难度题库离线内置，随时自由练习，即时核对答案与分步提示陪你稳步进步。':
      'Practice offline across five difficulty levels, with answer checks and '
          'progressive hints whenever you need them.',
  '第 {order} 小关': 'Lesson {order}',
  '第 {chapter} 章': 'Chapter {chapter}',
  '已通关 {completed}/{total}': '{completed}/{total} completed',
  '已完成 {completed}/{total} 关': '{completed}/{total} lessons completed',
  '继续你的数独旅程': 'Continue Your Sudoku Journey',
  '更多玩法': 'More Ways to Play',
  '离线对决': 'Offline Duel',
  '挑战码异步竞速': 'Race with shareable challenge codes',
  '课程加载失败': 'Could Not Load the Curriculum',
  '自动笔记': 'Auto Notes',
  '擦除': 'Erase',
  '填数': 'Value',
  '笔记': 'Notes',
  '撤销（Ctrl+Z）': 'Undo (Ctrl+Z)',
  '重做（Ctrl+Y）': 'Redo (Ctrl+Y)',
  '擦除（Del）': 'Erase (Del)',
  '自动笔记：填写全部合法候选数': 'Auto Notes: fill all legal candidates',
  '提示（H）': 'Hint (H)',
  '核对答案（N）': 'Check Answers (N)',
  '填数模式（切换回大数字输入）': 'Value Mode (enter full-size digits)',
  '笔记模式（Shift+1-9 记笔记）': 'Notes Mode (Shift+1–9)',
  '恭喜完成！': 'Congratulations!',
  '恭喜通关！': 'Lesson Complete!',
  '自动核验通过，整盘全部正确。': 'Automatic check passed. The entire grid is correct.',
  '自动核验通过，本关盘面全部正确。':
      'Automatic check passed. This lesson\'s grid is completely correct.',
  '关闭恭喜动画': 'Close congratulations animation',
  '太棒了': 'Great!',
  '正在计算，请稍候…': 'Calculating…',
  '「{title}」尚未交付': '“{title}” is not available yet',
  '计划交付：{milestone}': 'Planned for: {milestone}',
  '挑战完成！': 'Challenge Complete!',
  '{name} · 用时 {time} · 错误 {count}': '{name} · Time {time} · {count} mistakes',
  '计分 {time}': 'Score {time}',
  '把成绩码发给对方，再到对决大厅比较胜负。':
      'Send the result code to your opponent, then compare results in the duel lobby.',
  '成绩码已复制': 'Result code copied',
  '复制成绩码': 'Copy Result Code',
  '返回对决大厅': 'Back to Duel Lobby',
  '玩家': 'Player',
  '创建挑战失败，请稍后重试': 'Could not create the challenge. Please try again.',
  '{label}已复制': '{label} copied',
  '无需联网：分享挑战码进入同一道题，完成后交换成绩码。每个核验错误格罚时 5 秒。':
      'No internet required: share a challenge code to play the same puzzle, '
          'then exchange result codes. Each incorrect cell adds a 5-second penalty.',
  '我的昵称': 'My Nickname',
  '发起挑战': 'Create a Challenge',
  '题目难度': 'Puzzle Difficulty',
  '正在选题…': 'Choosing a puzzle…',
  '生成挑战码': 'Generate Challenge Code',
  '挑战码 · {id}': 'Challenge Code · {id}',
  '挑战码': 'Challenge code',
  '开始我的挑战': 'Start My Challenge',
  '接受挑战': 'Accept a Challenge',
  '粘贴对方的挑战码': 'Paste the other player\'s challenge code',
  '验证并开始': 'Verify and Start',
  '比较成绩': 'Compare Results',
  '第一份成绩码': 'First result code',
  '第二份成绩码': 'Second result code',
  '比较胜负': 'Compare',
  '说明：离线成绩码带复制校验，但不具备服务器级防作弊能力，适合熟人之间公平约战。':
      'Note: offline result codes include copy validation, but not server-grade '
          'anti-cheat protection. They are intended for friendly matches.',
  '复制': 'Copy',
  '从剪贴板粘贴': 'Paste from Clipboard',
  '平局': 'Draw',
  '{name} 获胜': '{name} Wins',
  '{first}：{firstTime}　·　{second}：{secondTime}':
      '{first}: {firstTime} · {second}: {secondTime}',
  '从文本导入题目': 'Import Puzzle from Text',
  '困难 / 大师档仅使用预置题库；入门 / 简单 / 中等档可运行时生成补充。':
      'Hard and Master use curated puzzles only. Beginner, Easy, and Medium '
          'can generate additional puzzles when needed.',
  '开始新局？': 'Start a New Game?',
  '开始新局将覆盖上次未完成的对局，且不可恢复。':
      'Starting a new game will overwrite the unfinished game and cannot be undone.',
  '最高需用到：{technique}': 'Hardest technique: {technique}',
  '最高需用到：加载中…': 'Hardest technique: loading…',
  '最高需用到：—': 'Hardest technique: —',
  '剪贴板为空': 'The clipboard is empty',
  '请输入 81 位题目字符串': 'Enter an 81-character puzzle string',
  '导入失败：{error}': 'Import failed: {error}',
  '粘贴 81 位题目字符串（0/./空格表示空格，可含换行与竖线）。导入前将校验格式与唯一解。':
      'Paste an 81-character puzzle string. Use 0, a dot, or a space for an '
          'empty cell; line breaks and vertical bars are allowed. Format and '
          'uniqueness are checked before import.',
  '例如：530070000600195000…': 'Example: 530070000600195000…',
  '从剪贴板导入': 'Import from Clipboard',
  '建议 81 位': '81 characters recommended',
  '检测到未完成的对局': 'Unfinished Game Found',
  '可继续上次对局，或开始新局（将覆盖上次进度）':
      'Resume your last game or start a new one, which will overwrite it.',
  '继续上次对局': 'Resume Last Game',
  '开始新局（将覆盖）': 'Start New Game (Overwrite)',
  '单击空白区域继续': 'Click the empty area to resume',
  '已暂停': 'Paused',
  '用时 {time}': 'Time {time}',
  '自动核验发现 {count} 格错误（已标红）':
      'Automatic check found {count} incorrect cells (marked in red).',
  '有 {count} 格填错（已标红）': '{count} cells are incorrect (marked in red).',
  '当前已填数全部正确': 'All entered digits are correct.',
  '放弃挑战？': 'Give Up the Challenge?',
  '放弃本局？': 'Give Up This Game?',
  '离线挑战暂不保存中途盘面，放弃后需用挑战码重新开始。':
      'Offline duels do not save an in-progress grid. You will need the challenge code to restart.',
  '放弃后将清除本局进度，且不可恢复。':
      'Giving up clears this game\'s progress and cannot be undone.',
  '暂停': 'Pause',
  '离线同题竞速': 'Offline Same-Puzzle Race',
  '提示、核对和自动笔记已关闭；手动笔记可用。填满后自动核验，每个错误格罚时 5 秒。':
      'Hints, answer checks, and auto notes are disabled; manual notes remain '
          'available. The grid is checked when full, with a 5-second penalty '
          'for each incorrect cell.',
  '点击「提示」查看技巧讲解': 'Select Hint to view a technique explanation',
  '{level}提示': '{level} hint',
  '外观': 'Appearance',
  '当前主题': 'Current Theme',
  '棋盘主题': 'Board Theme',
  '当前：{theme} · 做题与教学棋盘同步切换': 'Current: {theme} · applies to games and lessons',
  '玩法': 'Gameplay',
  '自动候选数': 'Automatic Candidates',
  '标记错误': 'Mark Errors',
  '显示计时': 'Show Timer',
  '相同数字高亮': 'Highlight Matching Digits',
  '提示次数': 'Hint Limit',
  '自由练习每局可用提示次数': 'Hints available in each Free Play game',
  '反馈': 'Feedback',
  '音效': 'Sound Effects',
  '默认关闭（桌面端不可用）': 'Off by default (unavailable on desktop)',
  '震动': 'Haptics',
  '移动端默认开启': 'On by default on mobile',
  '数据': 'Data',
  '导出存档': 'Export Progress',
  '桌面选路径 / 移动端分享': 'Choose a path on desktop / share on mobile',
  '导入存档': 'Import Progress',
  '导入前自动备份当前进度': 'Current progress is backed up before import',
  '清空错题本': 'Clear Mistake Book',
  '删除全部错题记录': 'Delete every mistake record',
  '重置全部进度': 'Reset All Progress',
  '删除所有进度与设置，不可恢复': 'Delete all progress and settings permanently',
  '导出日志': 'Export Logs',
  '崩溃日志（最近 20 条）': 'Crash logs (latest 20)',
  'JSON 存档': 'JSON progress file',
  '已导出存档': 'Progress exported',
  '数独教学存档': 'Sudoku Tutor progress',
  '导入存档？': 'Import Progress?',
  '导入将覆盖当前进度（导入前会自动备份当前存档）。':
      'Importing will overwrite current progress after creating a backup.',
  '导入成功': 'Import successful',
  '导入失败：{message}': 'Import failed: {message}',
  '请将「数独教学存档 JSON」粘贴到对话框后确认导入':
      'Paste the Sudoku Tutor progress JSON into the dialog, then confirm the import.',
  '移动端导入失败：{error}': 'Mobile import failed: {error}',
  '清空错题本？': 'Clear the Mistake Book?',
  '将删除全部错题记录。': 'This will delete every mistake record.',
  '错题本已清空': 'Mistake Book cleared',
  '重置全部进度？': 'Reset All Progress?',
  '将删除全部关卡进度、设置与对局断点，此操作不可恢复。':
      'This permanently deletes all lesson progress, settings, and saved games.',
  '将删除全部进度与设置，此操作不可恢复。': 'This permanently deletes all progress and settings.',
  '已重置全部进度': 'All progress reset',
  '已导出日志': 'Logs exported',
  '崩溃日志': 'Crash logs',
  '关于': 'About',
  '版本 {version}': 'Version {version}',
  '语言': 'Language',
  '简体中文': '简体中文',
  '英文': 'English',
  '隐私说明': 'Privacy',
  '完全离线运行，本地存档，无网络上报':
      'Runs fully offline, stores data locally, and sends no network reports',
  '开发者模式已开启': 'Developer mode enabled',
  '设置加载失败：{error}': 'Could not load Settings: {error}',
  '原理演示': 'Tutorial Demo',
  '首次进入须完整观看本关（看完最后一步即可退出）':
      'On your first visit, watch the complete lesson before leaving.',
  '首次进入须完整观看本关（看完最后一步即可进入下一关）':
      'On your first visit, finish the lesson before continuing to the next one.',
  '本步技巧：{technique}': 'Technique: {technique}',
  '暂停自动播放': 'Pause Autoplay',
  '自动播放': 'Autoplay',
  '速度：每秒两步': 'Speed: 2 steps per second',
  '速度：每 2 秒一步（点击切换每秒两步）':
      'Speed: 1 step every 2 seconds (select for 2 steps per second)',
  '技巧进度': 'Technique Progress',
  '点击技巧节点快速跳转': 'Select a technique marker to jump to that step',
  '{technique}：第 {step} 步': '{technique}: step {step}',
  '{technique} · 重点': '{technique} · Focus',
  '跳到第 {step} 步': 'Jump to step {step}',
  '引导实操': 'Guided Practice',
  '教学进度保存失败，请重试': 'Could not save lesson progress. Please try again.',
  '已恢复上次保存的盘面': 'Your saved grid was restored',
  '点击「提示」按钮，提示将逐级解锁：一级→二级→三级。':
      'Select Hint to reveal guidance progressively: Level 1 → Level 2 → Level 3.',
  '第 {order} 级': 'Level {order}',
  '尚未解锁': 'Locked',
  '继续使用上一级提示后解锁': 'Use the previous hint level to unlock this one',
  '这一步有问题': 'There Is a Problem with This Move',
  '错在哪': 'What Went Wrong',
  '正确思路': 'Better Approach',
  '明白了': 'Got It',
  '挑战通过！': 'Trial Passed!',
  '用时': 'Time',
  '错误次数': 'Mistakes',
  '{count} 次': '{count}',
  '返回章节': 'Back to Chapter',
  '下一关': 'Next Lesson',
  '连续失败 {count} 次': '{count} Unsuccessful Attempts',
  '要不要先回看一遍「{technique}」的原理演示，再回来挑战？':
      'Would you like to review the {technique} demo before trying again?',
  '继续挑战': 'Keep Trying',
  '回看原理演示': 'Review Tutorial Demo',
  '验收试炼': 'Mastery Trial',
  '本关需用到：{technique}': 'Required technique: {technique}',
  '试炼关不提供提示：请自主识别并运用目标技巧解完整盘。':
      'Hints are unavailable in trials. Identify and apply the target technique '
          'to solve the full grid yourself.',
  '正在加载下一关': 'Loading the next lesson',
  '已经是最后一关': 'This is the final lesson',
  '下一关：{title}': 'Next: {title}',
  '开发者模式': 'Developer Mode',
  '开发者工具': 'Developer Tools',
  '全解锁': 'Unlock All',
  '重置进度': 'Reset Progress',
  '跳关（解锁指定关卡 ID）': 'Unlock a Specific Lesson ID',
  '如 ch0_l01': 'Example: ch0_l01',
  '关卡元信息（读取已存进度）': 'Lesson Metadata (Saved Progress)',
  '暂无已存关卡进度（完成教学关或跳关后出现）':
      'No saved lesson progress yet. Complete or unlock a lesson first.',
  '已全解锁全部已有关卡': 'All existing lessons unlocked',
  '请输入关卡 ID': 'Enter a lesson ID',
  '已解锁关卡 {id}': 'Lesson {id} unlocked',
  '加载失败：{error}': 'Loading failed: {error}',
  '状态：{status} · 用时 {time} · 提示 {hints} · 错误 {errors} · 尝试 {attempts} 次':
      'Status: {status} · Time {time} · Hints {hints} · Mistakes {errors} · Attempts {attempts}',
};

// Wiki content is also part of the central visible-copy catalog.
const Map<String, String> _englishWikiText = <String, String>{
  '某个空格排除同行、同列和同宫已有数字后，只剩一个合法候选数。':
      'After excluding digits already present in its row, column, and box, a cell has only one legal candidate.',
  '先补全候选数，寻找只有一个候选的格子，直接把该候选填入，再更新相关行、列、宫。':
      'Fill in candidates, find a cell with only one candidate, place it, and update the related row, column, and box.',
  '判断依据是“这个格只剩一个候选”，不要与某个数字在一个单元中只剩一个位置混淆。':
      'The cell itself must have one candidate; do not confuse this with a digit having one position in a unit.',
  '在某一行、列或宫中，某个数字虽然藏在多候选格里，但只有一个格子能够放置它。':
      'Within a row, column, or box, a digit has only one possible cell even though that cell has several candidates.',
  '按数字逐个扫描每个单元；若一个数字只在一个空格的候选中出现，就把它填入该格。':
      'Scan each unit digit by digit. If a digit appears in only one cell’s candidates, place it there.',
  '目标格自身可能有多个候选，关键是该数字在整个单元中只有这一个位置。':
      'The target cell may have several candidates; what matters is that the digit has only one position in the unit.',
  '同一行、列或宫内，两格的候选都恰好是相同的两个数字，这两个数字必定占据这两格。':
      'Two cells in one row, column, or box contain exactly the same two candidates, so those digits must occupy the pair.',
  '找到相同的双候选格后，从该单元其他空格中删除这两个候选。':
      'Find the matching bivalue cells, then remove both candidates from every other cell in the unit.',
  '两格都必须恰好只有这两个候选，并且处在同一个要执行删数的单元中。':
      'Both cells must contain exactly those two candidates and share the unit where eliminations are made.',
  '同一单元中，两个数字都只出现在相同的两格里，即使这两格还带有其他候选，它们也只能承载这两个数字。':
      'Two digits appear only in the same two cells of a unit; even with extra candidates, those cells must hold the pair.',
  '按候选数字的位置扫描单元，找到共享同两格的两个数字，删除这两格中的其他候选。':
      'Scan candidate positions, find two digits sharing the same two cells, and remove other candidates from those cells.',
  '看的是“两个数字只出现于两格”，不是两格当前的候选集合完全相同。':
      'Look for two digits restricted to two cells, not necessarily two cells with identical candidate sets.',
  '某数字在一个宫内的候选全部落在同一行或列，或在一行/列内的候选全部落在同一宫。':
      'A digit’s candidates in a box all lie on one row or column, or its candidates in a line all lie in one box.',
  '宫内集中时，从同一行或列的宫外格删除该候选；行列内集中时，从交叉宫的其他格删除该候选。':
      'For pointing, eliminate outside the box along the line; for claiming, eliminate elsewhere in the intersecting box.',
  '先确认目标数字在来源单元中的所有候选都被交叉单元锁定，不能遗漏第三个位置。':
      'Confirm every candidate for the digit in the source unit is locked into the intersecting unit.',
  '同一单元的三格候选并集恰好只有三个数字，且每格候选都是这三个数字的子集。':
      'Three cells in one unit have a combined candidate set of exactly three digits, and each cell uses only that set.',
  '锁定这三格后，从该单元其余空格中删除这三个候选。':
      'Lock those three cells and remove the three digits from all other cells in the unit.',
  '三格不必拥有完全相同的候选，但候选并集必须恰好为三个数字。':
      'The cells need not have identical candidates, but their union must contain exactly three digits.',
  '同一单元中，三个数字只分布在相同的三格内，这三格必定由它们占据。':
      'Three digits are restricted to the same three cells in a unit, so those cells must contain them.',
  '找到仅覆盖三格的三个数字，删除这三格中不属于该三数组合的其他候选。':
      'Find three digits covering only three cells, then remove all other candidates from those cells.',
  '应按数字的出现位置判断；三格原本可以各自含有更多候选。':
      'Judge by where the digits appear; each of the three cells may initially contain extra candidates.',
  '某数字在两行中都恰好只出现在相同的两列，四个候选形成矩形；行列角色也可以互换。':
      'A digit appears exactly twice in each of two rows, in the same two columns, forming a rectangle; rows and columns may swap roles.',
  '以两行为基底时，从那两列的其他行删除该候选；以两列为基底时反向操作。':
      'With rows as bases, remove the digit from other cells in the cover columns; reverse the logic for column bases.',
  '两个基底单元都必须恰好有两个候选位置，而且覆盖单元必须完全一致。':
      'Each base unit must have exactly two positions, and both bases must use the same cover units.',
  '近似 X 翼的结构中，一个基底单元多出位于同宫的“鳍”候选，使删数范围被限制在鳍所在宫。':
      'In a near X-Wing, one base has an extra fin candidate in the same box, restricting eliminations to that box.',
  '先定位主体 X 翼与鳍，再从同时受对角主体候选和鳍约束的宫内格删除目标候选。':
      'Locate the main X-Wing and fin, then eliminate from box cells that see both the opposite corner and the fin.',
  '不能像标准 X 翼一样整列或整行删除；被删格必须落在鳍的宫内并满足双重可见。':
      'Do not eliminate along the entire line as in a standard X-Wing; targets must lie in the fin’s box and see both constraints.',
  '某数字在三行中的候选总共只落在相同的三列，形成三阶鱼；行列角色可以互换。':
      'A digit’s candidates in three rows are confined to the same three columns, forming a size-three fish; roles may be reversed.',
  '以三行为基底时，从三条覆盖列的其他行删除该候选；列基底时反向操作。':
      'With three base rows, remove the digit from other cells in the three cover columns; reverse for column bases.',
  '每个基底单元通常有二至三个候选，三者的覆盖位置并集必须恰好是三个单元。':
      'Each base usually has two or three candidates, and their cover-unit union must contain exactly three units.',
  '一个双候选枢轴 XY 分别看到双候选夹翼 XZ 与 YZ，两个夹翼共享候选 Z。':
      'A bivalue pivot XY sees bivalue pincers XZ and YZ; both pincers share candidate Z.',
  '从所有同时能看到两个夹翼的格子中删除候选 Z。':
      'Remove candidate Z from every cell that sees both pincers.',
  '两个夹翼不必互相可见，但都必须看到枢轴；枢轴和夹翼都应是双候选格。':
      'The pincers need not see each other, but each must see the pivot, and all three cells must be bivalue.',
  '三候选枢轴 XYZ 同时看到夹翼 XZ 与 YZ，三格都共享候选 Z。':
      'A trivalue pivot XYZ sees pincers XZ and YZ, with all three cells sharing candidate Z.',
  '从同时能看到枢轴和两个夹翼的格子中删除候选 Z。':
      'Remove candidate Z from cells that see the pivot and both pincers.',
  '被删格必须同时看到三格；只看到两个夹翼但看不到枢轴时不能删除。':
      'An elimination cell must see all three pattern cells; seeing only the pincers is not enough.',
  '两个互相不必可见的相同双候选格 XY，通过数字 X 的共轭对强链连接，使两端至少有一个取 Y。':
      'Two identical bivalue cells XY are connected through a conjugate strong link on X, forcing at least one endpoint to be Y.',
  '确认强链两端分别能看到两个双候选格后，从同时看到这两个双候选格的位置删除候选 Y。':
      'Confirm each strong-link endpoint sees one bivalue cell, then remove Y from cells that see both bivalue cells.',
  '连接数字必须形成真正的共轭对，也就是所在单元中该数字恰好只有两个候选位置。':
      'The linking digit must form a true conjugate pair: exactly two candidate positions in its unit.',
  '四个非给定格构成跨两行、两列和两个宫的唯一矩形；其中三格只有候选 AB，第四格还有额外候选。':
      'Four non-given cells form a rectangle across two rows, columns, and boxes; three contain only AB while the fourth has extras.',
  '为避免 AB 在矩形中互换产生双解，从第四格删除候选 A 和 B，保留其额外候选。':
      'To avoid a deadly interchangeable AB pattern, remove A and B from the fourth cell and keep its extra candidates.',
  '唯一矩形依赖题目唯一解前提，且四格必须分布在恰好两个宫内，给定数字不能作为矩形角。':
      'Unique Rectangles rely on a unique solution; the four cells must occupy exactly two boxes and cannot include givens.',
  '唯一矩形中，同一侧的两个角除共同候选 AB 外，还共享同一个额外候选 C。':
      'In a Unique Rectangle, two corners on one side share an extra candidate C in addition to AB.',
  '为避免形成可交换的双解结构，从所有同时看到这两个额外候选格的位置删除候选 C。':
      'To avoid an interchangeable double solution, remove C from every cell that sees both extra-candidate corners.',
  '两个角的额外候选必须是同一个数字，被删格也必须同时看到这两个角。':
      'Both corners must share the same extra digit, and each elimination cell must see both corners.',
  '针对同一数字，沿共轭对强链交替使用两种颜色，所有同色节点代表同一真假状态。':
      'For one digit, alternate two colors along conjugate strong links; nodes of one color share the same truth state.',
  '若同色节点互相冲突，删除该颜色全部候选；若链外候选同时看到两种颜色，则删除该链外候选。':
      'If same-color nodes conflict, remove that color; if an outside candidate sees both colors, remove the outside candidate.',
  '连线只能来自共轭对强链；不同颜色只是逻辑标记，并不预先代表真或假。':
      'Links must be conjugate strong links. Colors are logical labels and do not initially mean true or false.',
};
