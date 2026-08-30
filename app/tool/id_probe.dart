// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'project_paths.dart';

void main() {
  final String root = findProjectRoot();
  for (final int ch in <int>[0, 1, 2, 3]) {
    final Directory dir = Directory('$root/dataset/level_candidates/ch$ch');
    final Map<String, String> seen = <String, String>{};
    for (final File f in dir.listSync().whereType<File>()) {
      final String name = f.uri.pathSegments.last;
      final Map<String, Object?> json =
          jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      seen[name] = '${json['id']}@${json['order']}';
    }
    final List<String> keys = seen.keys.toList()..sort();
    for (final String k in keys) {
      print('$k -> ${seen[k]}');
    }
  }
}
