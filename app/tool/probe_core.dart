// ignore_for_file: avoid_print

import 'package:sudoku_core/sudoku_core.dart';

void main() {
  final lv = LessonLevel(
      id: 'x',
      chapter: 0,
      order: 1,
      kind: LevelKind.demo,
      title: 't',
      puzzle81: '',
      solution81: '');
  print('core ok: ${TechniqueId.values.length} techniques, ${lv.kind.id}');
}
