/// Project-wide English localization coverage.
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/technique_wiki.dart';
import 'package:sudoku_tutor/domain/hint/hint_level.dart';
import 'package:sudoku_tutor/domain/hint/hint_service.dart';
import 'package:sudoku_tutor/domain/hint/hint_state.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_detector.dart';
import 'package:sudoku_tutor/domain/teaching/mistake_message_repository.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

void main() {
  const AppLocalizations english = AppLocalizations(Locale('en'));
  final RegExp han = RegExp(r'[\u3400-\u9fff]');

  test('Chinese is the fallback and English is explicitly selectable', () {
    expect(AppLocalizations.fallback.languageCode, AppLanguages.chinese);
    expect(AppLanguages.normalize(null), AppLanguages.chinese);
    expect(AppLanguages.normalize('unsupported'), AppLanguages.chinese);
    expect(AppLanguages.normalize('en'), AppLanguages.english);
    expect(english.text('设置'), 'Settings');
  });

  test('every literal l10n.text call in UI and app has an English entry', () {
    final RegExp call = RegExp(
      r"l10n\.text\(\s*'((?:\\.|[^'])*)'",
      multiLine: true,
    );
    final List<File> files = <File>[
      ...Directory('lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart')),
      ...Directory('lib/app')
          .listSync(recursive: true)
          .whereType<File>()
          .where((File file) => file.path.endsWith('.dart')),
    ];

    for (final File file in files) {
      final String source = file.readAsStringSync();
      for (final RegExpMatch match in call.allMatches(source)) {
        final String text = match.group(1)!;
        if (han.hasMatch(text)) {
          expect(
            english.hasEnglishTranslation(text),
            isTrue,
            reason: '${file.path} has no English entry for: $text',
          );
        }
      }
    }
  });

  test('all technique and Wiki teaching copy has English content', () {
    for (final TechniqueId technique in TechniqueId.values) {
      final String name = english.techniqueName(technique);
      expect(name.trim(), isNotEmpty, reason: technique.id);
      expect(han.hasMatch(name), isFalse, reason: technique.id);
    }
    for (final TechniqueWikiEntry entry in techniqueWikiEntries) {
      for (final String paragraph in <String>[
        entry.definition,
        entry.usage,
        entry.tip,
      ]) {
        expect(
          english.hasEnglishTranslation(paragraph),
          isTrue,
          reason: '${entry.id.id} Wiki paragraph has no English entry',
        );
        expect(
          han.hasMatch(english.text(paragraph)),
          isFalse,
          reason: '${entry.id.id} Wiki paragraph still contains Chinese',
        );
      }
    }
  });

  test('structured hints and mistake coaching render in English', () {
    final HintState hint = HintState(
      level: HintLevel.level2,
      scope: HintScope.teaching,
      techniqueId: TechniqueId.nakedPair,
      narration: '中文提示不应泄漏到英文界面',
      highlightedCells: const <int>[0, 1],
      eliminations: const <Elimination>[],
      visual: VisualHint.empty(),
    );
    expect(han.hasMatch(english.hintNarration(hint)), isFalse);
    for (final HintUnavailableReason reason in HintUnavailableReason.values) {
      expect(
        han.hasMatch(english.hintUnavailable(reason)),
        isFalse,
        reason: reason.name,
      );
    }

    const MistakeEvent event = MistakeEvent(
      type: MistakeType.prematureFill,
      cellIndex: 10,
      digit: 5,
      techniqueId: TechniqueId.hiddenSingle,
      fingerprint: 'prematureFill:10:5:hiddenSingle',
    );
    final MistakeMessage message = english.mistakeMessage(
      event,
      const MistakeMessage(what: '中文错误', how: '中文建议'),
    );
    expect(han.hasMatch(message.what), isFalse);
    expect(han.hasMatch(message.how), isFalse);
  });
}
