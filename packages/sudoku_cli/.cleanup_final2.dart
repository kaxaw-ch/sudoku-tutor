import 'dart:io';
void main() {
  final Directory d = Directory('.tmp_demo');
  if (d.existsSync()) {
    for (final FileSystemEntity e in d.listSync(recursive: true)) {
      try { e.deleteSync(); } on FileSystemException {}
    }
    try { d.deleteSync(); print('deleted .tmp_demo'); }
    on FileSystemException catch (e) { print('dir delete fail: $e'); }
  }
  for (final name in <String>[
    'probe_tmp.dart','probe2_tmp.dart','probe3_tmp.dart',
    '.cleanup2.dart','.cleanup3.dart','.cleanup4.dart',
  ]) {
    final File f = File(name);
    if (f.existsSync()) {
      try { f.deleteSync(); print('deleted $name'); }
      on FileSystemException catch (e) { print('FAIL $name'); }
    }
  }
}
