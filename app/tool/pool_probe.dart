// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'project_paths.dart';

void main() {
  final String projectRoot = findProjectRoot();
  final List<int> bytes =
      File('$projectRoot/app/assets/pools/ch1.json.gz').readAsBytesSync();
  final Map<String, Object?> pool =
      jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, Object?>;
  print('顶层键: ${pool.keys}');
  final List<Object?> puzzles = pool['puzzles'] as List<Object?>;
  print('count=${puzzles.length}');
  final Map<String, Object?> p0 = puzzles[0] as Map<String, Object?>;
  print('p0 键: ${p0.keys}');
  print('p0.hardestTechnique=${p0['hardestTechnique']}');
  print('p0.stepCount=${p0['stepCount']}');
  print('p0.script=${p0['script']}');
}
