/// 文本导入服务 —— 81 字符串 / 剪贴板粘贴导入，含格式校验与唯一解校验
/// （P0-PRA-10，T-DOM-03；**不做 OCR**）。
///
/// 校验链路（与架构 §7.3 错误码约定一致）：
/// 1. 文本清理（容忍多行、竖线、空格、破折号）→ 有效字符数 ≠ 81
///    → `E_IMPORT_001`（格式非法）；
/// 2. 逐字符合法性（仅 `1..9` 与空格符）→ `E_IMPORT_001`；
/// 3. 初始盘面自洽性（行/列/宫无重复）→ 冲突抛 `E_IMPORT_001`；
/// 4. **唯一解校验**（`BacktrackingSolver.countSolutions(stopAt:2)`）
///    → 无解抛 `E_IMPORT_001`；多解抛 `E_IMPORT_002`；唯一解则取终局解。
///
/// 重计算（唯一解校验/回溯求解）默认在独立 Isolate 执行（架构 §2.3），
/// [checker] 可注入以便测试使用同步实现。
library;

import 'dart:isolate';

import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/domain_error.dart';

/// 唯一解校验函数签名：接收 81 个格值（0=空），返回 `(解数, 唯一解或 null)`。
///
/// 返回的 `count`：0 = 无解；1 = 唯一解（[List<int>?] 为该解）；≥2 = 多解。
typedef UniquenessChecker = Future<(int, List<int>?)> Function(
  List<int> values,
);

/// 默认校验器：`Isolate.run` 内执行回溯求解（PC <5ms，低端安卓 20–50ms，
/// 不阻塞 UI 帧；架构 §2.3）。
Future<(int, List<int>?)> defaultUniquenessChecker(List<int> values) =>
    Isolate.run<(int, List<int>?)>(() {
      final Board board = Board.fromValues(values);
      const BacktrackingSolver solver = BacktrackingSolver();
      final int count = solver.countSolutions(board, stopAt: 2);
      final List<int>? solution = count == 1 ? solver.solveFirst(board) : null;
      return (count, solution);
    });

/// 文本导入服务。
class PuzzleImportService {
  /// 构造服务；[checker] 缺省用 [defaultUniquenessChecker]（Isolate 执行）。
  PuzzleImportService({UniquenessChecker? checker})
      : _checker = checker ?? defaultUniquenessChecker;

  final UniquenessChecker _checker;

  /// 导入一道题（81 字符串 / 多行粘贴文本）。
  ///
  /// 成功返回 [Puzzle]（题面 givenMask 固化 + 唯一终局解）；
  /// 失败抛 [AppError]：`E_IMPORT_001` 格式非法 / `E_IMPORT_002` 非唯一解。
  Future<Puzzle> import(String raw) async {
    final Board board = _parseBoard(raw);
    final List<int> values = board.toValueList();
    final (int count, List<int>? solution) = await _checker(values);
    if (count == 0) {
      throw AppError.importFormat('题目无解');
    }
    if (count > 1) {
      throw AppError.importNotUnique();
    }
    return Puzzle(
      given: values,
      solution: solution ?? <int>[],
      givenMask: List<bool>.of(board.givenMask),
    );
  }

  /// 解析并做格式/自洽性校验；任何问题抛 `E_IMPORT_001`。
  Board _parseBoard(String raw) {
    // 与 `Board.fromPuzzleString` 同一清理口径：去掉空白/竖线/破折号/加号。
    final String cleaned = raw.replaceAll(RegExp(r'[\s|\-+]'), '');
    if (cleaned.length != kCellCount) {
      throw AppError.importFormat('有效字符数 ${cleaned.length}，期望 $kCellCount');
    }
    final Board board;
    try {
      // markGivens:true —— 导入题的非空格即题面给定格（C-11 全链路携带）。
      board = Board.fromPuzzleString(cleaned, markGivens: true);
    } on CoreException catch (e) {
      throw AppError.importFormat(e.detail ?? e.errorCode.message);
    }
    // 初始盘面自洽性：行/列/宫不得有重复数字。
    final List<Conflict> conflicts = Validator.findConflicts(board);
    if (conflicts.isNotEmpty) {
      final Conflict first = conflicts.first;
      throw AppError.importFormat('初始盘面自相矛盾：${first.zhDescription}');
    }
    return board;
  }
}
