import 'dart:io';
void main() {
  for (final f in ['probe_tmp.dart','probe2_tmp.dart','probe3_tmp.dart','.cleanup2.dart','.cleanup3.dart']) {
    final File file = File(f);
    if (file.existsSync()) { file.deleteSync(); print('deleted $f'); }
  }
}
