// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'project_paths.dart';

void main() {
  final String root = findProjectRoot();
  for (final String f in <String>[
    'ch0/ch0_l05_candidate_2.json',
    'ch1/ch1_l01_candidate_1.json',
    'ch2/ch2_l01_candidate_1.json',
    'ch3/ch3_l03_candidate_4.json',
    'ch0/ch0_l02_candidate_1.json'
  ]) {
    final Map<String, Object?> json =
        jsonDecode(File('$root/dataset/level_candidates/$f').readAsStringSync())
            as Map<String, Object?>;
    final Map<String, Object?> script = json['script']! as Map<String, Object?>;
    final List<Object?> steps = script['steps'] as List<Object?>;
    print('=== $f ===');
    for (final Object? s in steps) {
      final Map<String, Object?> step = s! as Map<String, Object?>;
      final String tid = step['techniqueId']! as String;
      if (tid == 'nakedSingle' || tid == 'hiddenSingle') continue;
      print('  #${step['order']} [$tid] ${step['narration']}');
    }
  }
}
