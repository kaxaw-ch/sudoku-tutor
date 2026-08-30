import 'dart:io';
void main() {
  final Directory d = Directory('.tmp_demo');
  if (d.existsSync()) {
    var ok = true;
    for (final FileSystemEntity e in d.listSync(recursive: true)) {
      try { e.deleteSync(); } on FileSystemException { ok = false; }
    }
    try { d.deleteSync(); print('deleted .tmp_demo'); } on FileSystemException { ok = false; }
    if (!ok) print('tmp_demo partial');
  }
  var all = true;
  for (final name in <String>[
    'probe_tmp.dart','probe2_tmp.dart','probe3_tmp.dart',
    '.cleanup2.dart','.cleanup3.dart','.cleanup4.dart',
    '.cleanup_final.dart','.cleanup_final2.dart','.last_clean.dart',
  ]) {
    final File f = File(name);
    if (f.existsSync()) {
      try { f.deleteSync(); } on FileSystemException { print('locked: $name'); all = false; }
    }
  }
  if (all) print('all files cleaned');
}
