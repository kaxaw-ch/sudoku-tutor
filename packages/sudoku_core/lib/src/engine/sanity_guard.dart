/// **删数结论安全断言**：任何删数不得等于终局解（P0-QA-03 底座）。
///
/// 这是全项目**最重要的一条正确性护栏**：技巧识别器一旦误删了某格的正确候选，
/// 玩家将被引入死局，属 P0 缺陷。故逐级求解器与提示扫描的**每一步**都必须
/// 经过 [SanityGuard.checkResult]。
///
/// 开销控制（doc 07 T-CORE-06 验收项「生产路径 < 5%」）：
/// - 断言复杂度为 O(删数条数)，通常 ≤ 10；
/// - 无终局解时直接短路返回，不做任何分配；
/// - 通过 [SanityGuard.enabled] 可在极端性能场景整体关闭（默认开启）。
library;

import '../model/coord.dart';
import '../model/digit.dart';
import '../techniques/solve_context.dart';
import '../techniques/technique_result.dart';
import '../util/core_error.dart';

/// 一处断言失败的详情。
class SanityViolation {
  /// 构造一处违规。
  const SanityViolation({
    required this.cellIndex,
    required this.digit,
    required this.isPlacement,
  });

  /// 出问题的格索引。
  final int cellIndex;

  /// 出问题的数字。
  final int digit;

  /// `true` = 填错数字；`false` = 删掉了正确候选。
  final bool isPlacement;

  /// 简体中文描述。
  String get zhDescription => isPlacement
      ? '${Coord.label(cellIndex)} 被填入 $digit，与终局解不符'
      : '${Coord.label(cellIndex)} 的候选 $digit 被删除，但它正是终局解';

  @override
  String toString() => 'SanityViolation($zhDescription)';
}

/// 删数/填数安全断言（静态工具）。
abstract final class SanityGuard {
  /// 全局开关。
  ///
  /// ⚠️ 默认 `true`，**生产环境不得关闭**；仅允许在专项性能基准测试中临时置 `false`。
  /// 这是本层唯一的可变全局状态，已在架构评审中作为例外记录（§7.1）。
  static bool enabled = true;

  /// 断言一处删数是安全的：`solution[cellIndex] != digit`。
  ///
  /// [solution] 为空（未知终局解）时直接放行。
  /// 违规抛 `E_TECH_001`。
  static void assertEliminationSafe(
    List<int>? solution,
    int cellIndex,
    int digit, {
    String? source,
  }) {
    if (!enabled || solution == null) {
      return;
    }
    Coord.requireIndex(cellIndex);
    Digit.requireDigit(digit);
    if (solution[cellIndex] == digit) {
      throw CoreException(
        CoreErrorCode.techEliminationHitsSolution,
        _withSource(
          '${Coord.label(cellIndex)} 的候选 $digit 被删除，但它正是终局解',
          source,
        ),
      );
    }
  }

  /// 断言一处填数是正确的：`solution[cellIndex] == digit`。
  ///
  /// [solution] 为空时直接放行。违规抛 `E_TECH_001`。
  static void assertPlacementSafe(
    List<int>? solution,
    int cellIndex,
    int digit, {
    String? source,
  }) {
    if (!enabled || solution == null) {
      return;
    }
    Coord.requireIndex(cellIndex);
    Digit.requireDigit(digit);
    if (solution[cellIndex] != digit) {
      throw CoreException(
        CoreErrorCode.techEliminationHitsSolution,
        _withSource(
          '${Coord.label(cellIndex)} 被填入 $digit，终局解为 ${solution[cellIndex]}',
          source,
        ),
      );
    }
  }

  /// 校验一个技巧结果的全部结论；任一违规抛 `E_TECH_001`。
  ///
  /// 这是逐级求解器与提示扫描的**统一入口**。
  static void checkResult(SolveContext ctx, TechniqueResult result) {
    if (!enabled || !ctx.hasSolution) {
      return;
    }
    final List<int>? solution = ctx.solution;
    final String source = result.techniqueId.zhName;
    for (final Elimination e in result.eliminations) {
      assertEliminationSafe(solution, e.cellIndex, e.digit, source: source);
    }
    for (final Placement p in result.placements) {
      assertPlacementSafe(solution, p.cellIndex, p.digit, source: source);
    }
  }

  /// 只收集不抛出的版本，供批量模糊测试统计使用（doc 07 T-QA-03）。
  ///
  /// 返回空列表表示该结果完全安全。
  static List<SanityViolation> collectViolations(
    List<int>? solution,
    TechniqueResult result,
  ) {
    if (solution == null) {
      return const <SanityViolation>[];
    }
    final List<SanityViolation> violations = <SanityViolation>[];
    for (final Elimination e in result.eliminations) {
      if (solution[e.cellIndex] == e.digit) {
        violations.add(
          SanityViolation(cellIndex: e.cellIndex, digit: e.digit, isPlacement: false),
        );
      }
    }
    for (final Placement p in result.placements) {
      if (solution[p.cellIndex] != p.digit) {
        violations.add(
          SanityViolation(cellIndex: p.cellIndex, digit: p.digit, isPlacement: true),
        );
      }
    }
    return violations;
  }

  /// 结果是否完全安全（不抛异常）。
  static bool isResultSafe(List<int>? solution, TechniqueResult result) =>
      collectViolations(solution, result).isEmpty;

  static String _withSource(String message, String? source) =>
      source == null ? message : '[$source] $message';
}
