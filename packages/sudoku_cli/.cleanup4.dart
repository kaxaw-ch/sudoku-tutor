import 'dart:io';
void main() {
  for (final f in ['probe_tmp.dart','probe2_tmp.dart','probe3_tmp.dart']) {
    final File file = File(f);
    if (file.existsSync()) {
      try { file.deleteSync(); print('deleted $f'); }
      on FileSystemException catch (e) { print('FAIL $f: $e'); }
    }
  }
}
