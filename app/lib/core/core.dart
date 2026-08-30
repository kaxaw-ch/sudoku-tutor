/// App 侧访问算法层的**唯一 barrel**。
///
/// 作用（架构文档 §3.3.1 / PRD P0-QA-04）：
/// - `lib/core/` 目录**禁止 import flutter**，由 `tools/ci/check_layering.dart` 静态校验；
/// - domain 层一律 `import 'package:sudoku_tutor/core/core.dart';`，
///   不直接写 `package:sudoku_core/...`，这样将来若算法包改名或拆分，
///   只需改本文件一行。
library;

export 'package:sudoku_core/sudoku_core.dart';
