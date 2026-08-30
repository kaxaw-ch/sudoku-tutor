/// 应用入口：`runApp` + 全局错误捕获（架构文档 §3.3.1）。
///
/// 本文件保持极薄，所有初始化逻辑集中在 `app/bootstrap.dart`，
/// 便于集成测试直接调用 `bootstrap()` 而不经过 `main()`。
library;

import 'package:sudoku_tutor/app/bootstrap.dart';

/// 程序入口。
void main() => bootstrap();
