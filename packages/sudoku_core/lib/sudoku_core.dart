/// `sudoku_core` —— 数独教学游戏的**纯 Dart 算法层**唯一对外 barrel。
///
/// 铁律（架构文档 §2.1 / §3.1 / §7.6）：
/// - 本包**禁止**依赖 `package:flutter`、`dart:ui`、`dart:io`；
///   由 `tools/ci/check_layering.dart` 静态校验，违规即阻断合入；
/// - `lib/src/` 下所有文件一律私有，外部只能 `import 'package:sudoku_core/sudoku_core.dart';`；
/// - App 层通过 `app/lib/core/core.dart` 再导出本 barrel，保证
///   「`lib/core/` 禁 import flutter」口径成立（PRD P0-QA-04）。
///
/// 当前批次：A（工程基建）+ B（算法层基础设施）+ C（16 项识别器 / 逐级求解 / 难度分级）。
/// 批次 D 起新增的 `puzzle/*_codec`、`replay/` 等文件
/// **必须同步追加到本文件的 export 列表**，否则外部不可见。
library;

// ---------------------------------------------------------------- util
export 'src/util/bit_ops.dart';
export 'src/util/core_error.dart';
export 'src/util/fingerprint.dart';
export 'src/util/result.dart';
export 'src/util/rng.dart';

// ---------------------------------------------------------------- model
export 'src/model/board.dart';
export 'src/model/board_codec.dart';
export 'src/model/candidate_set.dart';
export 'src/model/cell.dart';
export 'src/model/coord.dart';
export 'src/model/digit.dart';
export 'src/model/peers.dart';
export 'src/model/unit.dart';

// ---------------------------------------------------------------- engine
export 'src/engine/backtracking_solver.dart';
export 'src/engine/candidate_calculator.dart';
export 'src/engine/generator.dart';
export 'src/engine/move.dart';
export 'src/engine/move_applier.dart';
export 'src/engine/sanity_guard.dart';
export 'src/engine/stepwise_solver.dart';
export 'src/engine/undo_stack.dart';
export 'src/engine/uniqueness_checker.dart';
export 'src/engine/validator.dart';

// ---------------------------------------------------------------- visual（P0-ENG-09）
export 'src/visual/candidate_mark.dart';
export 'src/visual/cell_mark.dart';
export 'src/visual/link_mark.dart';
export 'src/visual/mark_role.dart';
export 'src/visual/mark_style.dart';
export 'src/visual/region_mark.dart';
export 'src/visual/shape_code.dart';
export 'src/visual/visual_hint.dart';

// ---------------------------------------------------------------- narrative（P0-ENG-10）
export 'src/narrative/narration_params.dart';
export 'src/narrative/narration_template.dart';
export 'src/narrative/zh_cn_templates.dart';

// ---------------------------------------------------------------- techniques 框架
export 'src/techniques/rule_set.dart';
export 'src/techniques/solve_context.dart';
export 'src/techniques/technique.dart';
export 'src/techniques/technique_id.dart';
export 'src/techniques/technique_rank.dart';
export 'src/techniques/technique_registry.dart';
export 'src/techniques/technique_result.dart';

// ---------------------------------------------------------------- techniques 公共支撑（批次 C）
export 'src/techniques/conjugate_pairs.dart';
export 'src/techniques/fish_support.dart';
export 'src/techniques/technique_support.dart';
export 'src/techniques/ur_support.dart';

// ---------------------------------------------------------------- techniques 16 项识别器（批次 C）
export 'src/techniques/finned_x_wing.dart';
export 'src/techniques/hidden_single.dart';
export 'src/techniques/hidden_subset.dart';
export 'src/techniques/locked_candidates.dart';
export 'src/techniques/naked_single.dart';
export 'src/techniques/naked_subset.dart';
export 'src/techniques/simple_colouring.dart';
export 'src/techniques/swordfish.dart';
export 'src/techniques/ur_type1.dart';
export 'src/techniques/ur_type2.dart';
export 'src/techniques/w_wing.dart';
export 'src/techniques/x_wing.dart';
export 'src/techniques/xy_wing.dart';
export 'src/techniques/xyz_wing.dart';

// ---------------------------------------------------------------- grading / puzzle
export 'src/grading/difficulty.dart';
export 'src/grading/difficulty_grader.dart';
export 'src/puzzle/puzzle.dart';
export 'src/puzzle/solution_script.dart';
export 'src/puzzle/level_model.dart';
export 'src/puzzle/puzzle_codec.dart';
export 'src/puzzle/level_codec.dart';
export 'src/puzzle/level_index.dart';

// ---------------------------------------------------------------- solver（T-CORE-09 脚本回放）
export 'src/solver/script_replayer.dart';
