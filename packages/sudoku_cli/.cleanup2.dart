import 'dart:io';
void main() {
  for (final f in ['.cleanup.dart']) {
    final File file = File(f);
    if (file.existsSync()) { file.deleteSync(); print('deleted $f'); }
  }
}
