/// T-UI-04 · 文本导入对话框测试（S-07 / P0-PRA-10）。
///
/// 覆盖：
/// - 81 串导入成功 → 对话框返回 `Puzzle`；
/// - 空输入 → 本地提示「请输入 81 位题目字符串」；
/// - 长度非法 → `E_IMPORT_001` 中文报错（有效字符数）；
/// - 非唯一解 → `E_IMPORT_002` 中文报错（导入题目非唯一解）；
/// - 取消 → 返回 `null`。
///
/// 注入假唯一解校验器（`checker`），不触发真实 Isolate。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart' hide UniquenessChecker;
import 'package:sudoku_tutor/domain/puzzle_bank/puzzle_import_service.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/ui/features/free_play/import_dialog.dart';
import 'package:sudoku_tutor/ui/theme/app_theme.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  /// 假唯一解校验器：返回配置好的 `(解数, 唯一解)`。
  UniquenessChecker checkerReturning(int count, List<int>? solution) =>
      (List<int> values) async => (count, solution);

  /// 打开导入对话框；[onOpen] 在对话框打开后收到其结果 Future。
  Future<void> pumpDialog(
    WidgetTester tester, {
    required UniquenessChecker checker,
    required void Function(Future<Puzzle?>) onOpen,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          puzzleImportServiceProvider.overrideWithValue(
            PuzzleImportService(checker: checker),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => Center(
                child: TextButton(
                  onPressed: () {
                    onOpen(ImportDialog.show(context));
                  },
                  child: const Text('打开导入'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开导入'));
    await tester.pump();
    expect(find.text('从文本导入题目'), findsOneWidget, reason: '对话框应弹出');
  }

  testWidgets('81 串导入成功：返回唯一解 Puzzle', (WidgetTester tester) async {
    final Puzzle puzzle = buildTestPuzzle();
    late Future<Puzzle?> result;
    await pumpDialog(
      tester,
      checker: checkerReturning(1, puzzle.solution),
      onOpen: (Future<Puzzle?> f) => result = f,
    );

    await tester.enterText(find.byType(TextField), puzzle.givenString);
    await tester.tap(find.text('导入'));
    await tester.pump(); // 异步校验 + pop。

    final Puzzle? imported = await result;
    expect(imported, isNotNull, reason: '导入成功应返回题目');
    expect(imported!.solution.join(), puzzle.solution.join());
  });

  testWidgets('空输入：本地提示不校验', (WidgetTester tester) async {
    await pumpDialog(
      tester,
      checker: checkerReturning(1, const <int>[]),
      onOpen: (Future<Puzzle?> f) {},
    );
    await tester.tap(find.text('导入'));
    await tester.pump();
    expect(find.text('请输入 81 位题目字符串'), findsOneWidget);
  });

  testWidgets('长度非法：E_IMPORT_001 报错', (WidgetTester tester) async {
    await pumpDialog(
      tester,
      checker: checkerReturning(1, const <int>[]),
      onOpen: (Future<Puzzle?> f) {},
    );
    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('导入'));
    await tester.pump();
    expect(find.textContaining('有效字符数 2，期望 81'), findsOneWidget);
    expect(find.textContaining('导入内容格式非法'), findsOneWidget);
  });

  testWidgets('非唯一解：E_IMPORT_002 报错', (WidgetTester tester) async {
    final Puzzle puzzle = buildTestPuzzle();
    await pumpDialog(
      tester,
      checker: checkerReturning(2, null),
      onOpen: (Future<Puzzle?> f) {},
    );
    await tester.enterText(find.byType(TextField), puzzle.givenString);
    await tester.tap(find.text('导入'));
    await tester.pump();
    expect(find.text('[E_IMPORT_002] 导入题目非唯一解'), findsOneWidget);
  });

  testWidgets('取消：返回 null', (WidgetTester tester) async {
    late Future<Puzzle?> result;
    await pumpDialog(
      tester,
      checker: checkerReturning(1, const <int>[]),
      onOpen: (Future<Puzzle?> f) => result = f,
    );
    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(await result, isNull);
  });
}
