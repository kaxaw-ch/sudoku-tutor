/// 只读求解上下文：盘面 + givenMask + 唯一解标志 + 规则集 + peers 缓存。
///
/// 铁律：识别器**不得修改 [board]**；需要试算请自行 `board.snapshot()`。
library;

import '../model/board.dart';
import '../model/candidate_set.dart';
import '../model/coord.dart';
import '../model/peers.dart';
import '../techniques/rule_set.dart';
import '../techniques/technique_id.dart';

/// 一次识别/求解扫描的只读上下文。
class SolveContext {
  /// 构造上下文。
  ///
  /// - [solution] 为终局解（81 个 1..9），供 `SanityGuard` 断言与教学误操作检测使用；
  ///   玩家文本导入等场景可能没有，此时传 `null`。
  /// - [uniqueSolutionGuaranteed] 为 `false` 时，唯一矩形族（UR）**整族必须返回空**
  ///   （doc 06 风险 A-07）。
  SolveContext({
    required this.board,
    required this.ruleSet,
    this.uniqueSolutionGuaranteed = true,
    List<int>? solution,
  }) : solution = solution == null ? null : List<int>.unmodifiable(solution);

  /// 当前盘面（只读使用）。
  final Board board;

  /// 启用的规则集。
  final RuleSet ruleSet;

  /// 谜题是否保证唯一解。
  final bool uniqueSolutionGuaranteed;

  /// 终局解，可为空。
  final List<int>? solution;

  /// 原始题面给定掩码（等同 `board.givenMask`，为对齐类图单列一个访问器）。
  List<bool> get givenMask => board.givenMask;

  /// 是否携带终局解。
  bool get hasSolution => solution != null;

  /// [id] 是否被当前规则集启用。
  bool allows(TechniqueId id) => ruleSet.allows(id);

  /// 格 [index] 的候选集（转发 `board`，便于识别器少写一层）。
  CandidateSet candidatesAt(int index) => board.candidatesAt(index);

  /// 格 [index] 的 20 个 peer（静态预计算表，零分配）。
  List<int> peersOf(int index) => Peers.peersOf(index);

  /// 两格是否互相可见。
  bool sees(int a, int b) => Peers.sees(a, b);

  /// 全部空格索引（升序）。
  List<int> blankCells() => board.blankCells();

  /// 候选集中含 [digit] 的空格索引（升序）。
  List<int> cellsWithCandidate(int digit) => board.cellsWithCandidate(digit);

  /// 终局解中格 [index] 的正确数字；无终局解时返回 0。
  int solutionAt(int index) {
    Coord.requireIndex(index);
    final List<int>? values = solution;
    return values == null ? 0 : values[index];
  }

  /// 以新盘面派生一个上下文（规则集与唯一解标志沿用）。
  SolveContext withBoard(Board next) => SolveContext(
        board: next,
        ruleSet: ruleSet,
        uniqueSolutionGuaranteed: uniqueSolutionGuaranteed,
        solution: solution,
      );

  /// 以新规则集派生一个上下文。
  SolveContext withRuleSet(RuleSet next) => SolveContext(
        board: board,
        ruleSet: next,
        uniqueSolutionGuaranteed: uniqueSolutionGuaranteed,
        solution: solution,
      );

  @override
  String toString() => 'SolveContext(blanks=${board.blankCount()},'
      'rules=${ruleSet.length},unique=$uniqueSolutionGuaranteed)';
}
