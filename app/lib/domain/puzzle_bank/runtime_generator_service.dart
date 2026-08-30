/// 运行时补充生成服务 —— 入门/简单/中等档在 Isolate 内补充出题（P0-PRA-01）。
///
/// 设计要点（T-DOM-03 验收）：
/// - **困难/大师档只用预置题库**（高级技巧命中率极低，架构风险 A-06），
///   本服务对这两档返回 `null`，绝不运行时生成；
/// - 入门/简单/中等档走 [EngineFacade.generatePuzzle]（独立 Isolate 内
///   生成 + 唯一解保持），同 seed 必可复现（架构 §7.1）；
/// - 生成函数在构造时注入（Provider 装配传 `engineFacade.generatePuzzle`），
///   测试可注入假生成器验证调度逻辑，不依赖真实 Isolate。
library;

import 'package:sudoku_tutor/core/core.dart';

/// 生成函数签名（默认注入 `EngineFacade.generatePuzzle`，测试可注入假实现）。
typedef RuntimeGenerateFn = Future<Puzzle> Function({
  required int seed,
  int targetGivens,
  String symmetryId,
  bool requireExactTarget,
});

/// 运行时补充生成服务。
class RuntimeGeneratorService {
  /// 构造服务；[generate] 为实际生成实现（Provider 装配时传
  /// `ref.watch(engineFacadeProvider).generatePuzzle`）。
  RuntimeGeneratorService({required RuntimeGenerateFn generate})
      : _generate = generate;

  final RuntimeGenerateFn _generate;

  /// 该档是否允许运行时补充生成。
  ///
  /// 入门/简单/中等 = 允许；困难/大师 = 只用预置题库（返回 `false`）。
  static bool canGenerate(Difficulty difficulty) => switch (difficulty) {
        Difficulty.beginner || Difficulty.easy || Difficulty.medium => true,
        Difficulty.hard || Difficulty.master => false,
      };

  /// 为 [difficulty] 补充生成一题；不允许的档位返回 `null`。
  ///
  /// [seed] 保证同种子可复现；[targetGivens] 为目标提示数。
  /// 生成产物统一标注为请求档位（生成器本身不评级）。
  Future<Puzzle?> generate(
    Difficulty difficulty, {
    required int seed,
    int targetGivens = 30,
  }) async {
    if (!canGenerate(difficulty)) {
      return null;
    }
    final Puzzle puzzle = await _generate(
      seed: seed,
      targetGivens: targetGivens,
      symmetryId: 'none',
      requireExactTarget: false,
    );
    return puzzle.difficulty == null || puzzle.difficulty != difficulty
        ? puzzle.copyWith(difficulty: difficulty)
        : puzzle;
  }
}
