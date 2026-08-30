/// 题库 / 对局 / 存储 的 Riverpod Providers（架构 §7.1：集中在 `*_providers.dart`）。
///
/// 手写 Provider（不用 codegen）：
/// - `progressRepositoryProvider` —— 存档仓储（Future：path_provider 解析）；
/// - `puzzleBankRepositoryProvider` / `puzzlePickerProvider` —— 题库与选题；
/// - `runtimeGeneratorProvider` —— Isolate 内补充生成（走 engineFacade）；
/// - `puzzleImportServiceProvider` —— 81 串/剪贴板导入；
/// - `gameSessionControllerProvider` —— 对局状态机（T-DOM-04）。
///
/// 测试注入：override 对应 Provider 即可替换真实实现
/// （如 `progressRepositoryProvider.overrideWith((ref) async => fake)`）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sudoku_tutor/domain/engine/engine_providers.dart';
import 'package:sudoku_tutor/domain/storage/atomic_file.dart';
import 'package:sudoku_tutor/domain/storage/json_progress_repository.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';
import 'package:sudoku_tutor/domain/storage/schema_migration.dart';
import 'package:sudoku_tutor/domain/storage/storage_paths.dart';

import '../puzzle_bank/puzzle_bank_repository.dart';
import '../puzzle_bank/puzzle_import_service.dart';
import '../puzzle_bank/puzzle_picker.dart';
import '../puzzle_bank/runtime_generator_service.dart';
import '../storage/models/session_snapshot.dart';
import 'game_session.dart';
import 'game_session_controller.dart';

/// 存档仓储（异步装配：path_provider 目录解析）。
final FutureProvider<ProgressRepository> progressRepositoryProvider =
    FutureProvider<ProgressRepository>((Ref ref) async {
  final StoragePaths paths = await StoragePaths.resolve();
  await paths.ensureDirectories();
  return JsonProgressRepository(
    paths: paths,
    io: const AtomicFile(),
    migration: SchemaMigration(),
  );
});

/// 题库仓库（rootBundle 读 assets + GZip 解压）。
final Provider<PuzzleBankRepository> puzzleBankRepositoryProvider =
    Provider<PuzzleBankRepository>(
  (Ref ref) => PuzzleBankRepository(),
);

/// 五档选题 / 试炼池抽取。
final Provider<PuzzlePicker> puzzlePickerProvider = Provider<PuzzlePicker>(
  (Ref ref) =>
      PuzzlePicker(repository: ref.watch(puzzleBankRepositoryProvider)),
);

/// Isolate 内补充生成（入门/简单/中等档；困难/大师返回 null）。
final Provider<RuntimeGeneratorService> runtimeGeneratorProvider =
    Provider<RuntimeGeneratorService>(
  (Ref ref) => RuntimeGeneratorService(
    generate: ref.watch(engineFacadeProvider).generatePuzzle,
  ),
);

/// 81 串/剪贴板导入（格式 + 唯一解校验）。
final Provider<PuzzleImportService> puzzleImportServiceProvider =
    Provider<PuzzleImportService>(
  (Ref ref) => PuzzleImportService(),
);

/// 对局状态机（`null` = 无对局）。
final NotifierProvider<GameSessionController, GameSession?>
    gameSessionControllerProvider =
    NotifierProvider<GameSessionController, GameSession?>(
  GameSessionController.new,
);

/// 断点存在性（`null` = 尚未加载完成）。
///
/// ⚠️ 依赖"页面进入时"的最新存档：对局退出保存断点后，
/// 须 `ref.invalidate(hasSessionProvider)` 强制重算（见 free_play_page 退出处）。
final FutureProvider<bool?> hasSessionProvider = FutureProvider<bool?>(
  (Ref ref) async {
    final ProgressRepository repo =
        await ref.watch(progressRepositoryProvider.future);
    final SessionSnapshot? snapshot = await repo.loadSession();
    return snapshot != null;
  },
);
