import 'dart:io';
void main() {
  for (final name in <String>['.tmp_demo']) {
    final Directory d = Directory(name);
    if (d.existsSync()) { d.deleteSync(recursive: true); print('deleted dir $name'); }
  }
  for (final name in <String>[
    'probe_tmp.dart','probe2_tmp.dart','probe3_tmp.dart',
    '.cleanup2.dart','.cleanup3.dart','.cleanup4.dart',
  ]) {
    final File f = File(name);
    if (f.existsSync()) {
      try { f.deleteSync(); print('deleted $name'); }
      on FileSystemException catch (e) { print('FAIL $name: $e'); }
    }
  }
}
