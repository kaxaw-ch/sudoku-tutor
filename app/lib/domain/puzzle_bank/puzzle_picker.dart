/// 选题服务 —— 五档随机选题 + 已玩去重 + 试炼池抽取（P0-PRA-01，T-DOM-03）。
///
/// 职责：
/// - 从 [PuzzleBankRepository] 加载一档题库后**随机抽取**；
/// - 借助 [seenFingerprints]（调用方维护的已玩指纹集合）做**已玩去重**；
/// - 题库全部玩过时按「循环玩」语义忽略去重再抽一题（不抛异常）；
/// - 试炼池抽取（教学章节用，P0-CLI-06）直接透传仓库结果。
///
/// 随机源可注入（测试用固定 seed 的 [Random]），生产默认系统随机。
library;

import 'dart:math';

import 'package:sudoku_tutor/core/core.dart';

import 'puzzle_bank_repository.dart';

/// 选题服务。
class PuzzlePicker {
  /// 构造选题服务；[random] 缺省用系统随机。
  PuzzlePicker({
    required PuzzleBankRepository repository,
    Random? random,
  })  : _repository = repository,
        _random = random ?? Random();

  final PuzzleBankRepository _repository;
  final Random _random;

  /// 从 [difficulty] 题库随机抽一题，避开 [seenFingerprints]（已玩去重）。
  ///
  /// 若全部题目都在已玩集合中，则忽略去重、从全题库随机抽一题
  /// （「循环玩」语义，不抛异常）。
  Future<Puzzle> pick(
    Difficulty difficulty, {
    Set<String> seenFingerprints = const <String>{},
  }) async {
    final DifficultyBank bank = await _repository.loadBank(difficulty);
    if (bank.puzzles.isEmpty) {
      throw StateError('题库「${difficulty.zhName}」为空');
    }
    final List<Puzzle> pool = List<Puzzle>.of(bank.puzzles)..shuffle(_random);
    for (final Puzzle puzzle in pool) {
      if (!seenFingerprints.contains(puzzle.fingerprint)) {
        return puzzle;
      }
    }
    // 全部已玩 → 循环玩。
    return pool.first;
  }

  /// 加载章节试炼池（透传仓库）。
  Future<TrialPool> loadPool(int chapter) => _repository.loadPool(chapter);
}
