# 08-QA 批次 A+B 独立审查报告

> ## ⚠️ 勘误（2026-08-07 追加）
> 本报告 §0 / §8 的"沙箱无法运行 flutter/dart"是 **2026-08-05~06 环境未就绪时的实测记录**，
> **现已全部解除**：Flutter 3.44.8 / Dart 3.12.2 已可用（需在命令内 `export PATH=/c/dev/flutter/bin:$PATH` 或
> 直接用 `/c/dev/flutter/bin/cache/dart-sdk/bin/dart.exe` 全路径）。已于 2026-08-06 实际跑通：
> `dart analyze`（零告警）、`dart test packages/sudoku_core`（202 用例全绿）、
> `dart test packages/sudoku_cli`（44 用例全绿）、`flutter build apk --debug`、`flutter build windows --debug`（均成功出包）。
> 本节"写文件未执行"的测试现均已实跑通过；§8 清单已可全部在本机执行。

| 项 | 内容 |
|---|---|
| 审查人 | 严过关（Yan，QA 工程师，独立 fresh-eyes） |
| 团队 | software-sudoku-tutor-sop |
| 阶段 | SOP 第四阶段：批次 A（M0 三包骨架 + 三层架构）+ 批次 B（算法层基础设施） |
| 审查对象 | `packages/sudoku_core`（纯 Dart 算法层，禁 import flutter）为主，含 `app/`、`packages/sudoku_cli/`、`tools/ci/`、`docs/` |
| 工程师自报 | `IS_PASS: YES`（**未直接采信**，独立复核） |
| 审查手段 | 通读源码 + 算法正确性推理 + 审查/补强单测（写文件，**未执行**）+ 客户机验证清单 |
| 环境约束 | **执行沙箱无 Flutter/Dart SDK**（`flutter`/`dart` 均 `command not found`，已实测）。**全程未执行任何 `flutter`/`dart` 命令**。验证手段仅限静态分析 + Python 辅助核算字符串/逻辑，可执行的断言统一交由客户端 CI。（⚠️ 此条已被上方勘误覆盖，仅保留历史原貌） |

> 标记约定：**【静态已完成】** = 本次已静态判定；**【需客户机执行】** = 必须在装好 SDK 的机器上运行验证。

---

## §0 执行约束与判定口径声明

本沙箱无法运行 `flutter test` / `dart test` / `flutter analyze`，因此：

1. **源码正确性** 通过逐行通读 + 算法推演 + Python 精确核算（字符串长度、计数、位运算）完成，结论为静态判定。
2. **单元测试** 以"写文件但不执行"的方式补强，并修正了工程师既有的两处测试缺陷（见 §6）。
3. 所有"覆盖率 ≥90%"、"零告警"、"10,000 题模糊测试"等**量化门槛**列于 §8 客户机验证清单，由 CI 在客户端落地。

**智能路由判定口径**（SOP 要求）：
- 断言**期望正确**（符合 PRD/设计）但实现给错 → 源码 bug → 转工程师（Engineer）。
- 断言**本身错误**（测试写错）→ 测试 bug → QA 自行修正（self）。
- 源码与测试均 OK → 报告成功（NoOne）。

---

## §1 逐模块审查结论表

> 结论枚举：**通过** / **通过(有建议)** / **有疑问** / **有 bug**。本批次**未发现任何阻断级或严重级源码 bug**。

### 批次 A — 工程基建与三层骨架（M0）

| 模块 / 文件 | 结论 | 说明 |
|---|---|---|
| 三包骨架 `packages/sudoku_core`、`sudoku_cli`、`app` | 通过 | pubspec 依赖方向正确，core 仅 re-export sudoku_core，无反向依赖 |
| barrel `sudoku_core/lib/sudoku_core.dart` | 通过 | 统一导出全部 `src/*`；注释明确禁 flutter/ui/io |
| `app/lib/core/core.dart` | 通过 | 仅 re-export sudoku_core barrel，满足"lib/core 禁 import flutter" |
| `app/lib/main.dart` / `app.dart` | 通过 | UI 入口，未触及算法层 |
| CLI 入口 `sudoku_cli/bin/*` | 通过 | selftest 逻辑正常，未引入 flutter/ui |
| 分层校验脚本 `tools/ci/check_layering.dart` | 通过 | R1–R6 规则齐全（见 §5） |
| CI 门禁 `tools/ci/run_gates.ps1` | 通过 | pub get→分层→analyze→test→覆盖率≥90% 序列完整 |
| 配置 `.fvmrc` / `analysis_options.yaml` / `pubspec.yaml` | 通过 | 锁定 `stable`；lint 规则完备 |

### 批次 B — 算法层基础设施（M1-1，T-CORE-01~06）

| 模块 / 文件 | 结论 | 说明 |
|---|---|---|
| `model/board.dart` | 通过(有建议) | clone/snapshot 深拷贝正确；givenMask 全链路携带正确；`operator==` 比 candidateMasks（见建议 S4） |
| `model/board_codec.dart` | 通过 | 81 字符串编解码正确 |
| `model/candidate_set.dart` | 通过 | `extension type const CandidateSet(int)` 位运算 O(1)，API 完备 |
| `model/coord/cell/peers/unit` | 通过 | `kCellCount=81`、`Peers.peerCount=20`、`sees` O(1)，正确 |
| `model/digit.dart` | 通过 | `parseChar` 接受 `.`/`0`/` `/`_`/`*`；`requireDigit` 抛 E_BOARD_005 |
| `engine/validator.dart` | 通过 | isValidPlacement/findConflicts/isComplete/isValidSolution 正确 |
| `engine/candidate_calculator.dart` | 通过 | 增量 `syncAfterPlace/syncAfterClear` 与 `recomputeAll` 逻辑一致（§3 已深挖） |
| `engine/backtracking_solver.dart` | 通过 | MRV + used 掩码，递归深度 ≤81，无死循环/栈溢出风险；`countSolutions(stopAt:2)` 唯一解判定正确 |
| `engine/uniqueness_checker.dart` | 通过 | `verdictOf/isUnique/uniqueSolutionOf/requireUnique` 口径统一收敛到回溯计数 |
| `engine/generator.dart` | 通过 | 唯一解保证成立（§3 深挖）；可复现性铁律成立 |
| `engine/rng.dart` | 通过 | 种子驱动可复现；禁全局随机；`derive(salt)` 派生稳定 |
| `engine/move.dart` | 通过 | 值对象；`clear` 的 digit 必须为 0；toJson/fromJson 正确 |
| `engine/move_applier.dart` | 通过 | `canApply` 拦截给定格与幂等；`apply/revert/reapply` 快照本格+20 peer 掩码，回滚逐字段相等 |
| `engine/undo_stack.dart` | 通过 | `kUndoDepth=100` FIFO 淘汰；`undo/redo/undoAll/resetGame` 正确 |
| `engine/sanity_guard.dart` | 通过 | 误删/误填拦截正确（§4 深挖）；`solution==null` 短路放行系设计 |
| `puzzle/puzzle.dart` | 通过 | `@immutable`；`givenCount` 按非空统计；`toGivenBoard`/`copyWith` 正确 |
| `techniques/*`（7 文件） | 通过 | `RuleSet.t1()/t2()=13/16` 与文档一致；`TechniqueRegistry._defaultTechniques()` 返回空壳 `<Technique>[]`（扩展点，属批次 C 接入）；`TechniqueResult.operator==` 依赖 fingerprint 完备（见建议 S2） |
| `util/*`（bit_ops/core_error/fingerprint/result） | 通过 | 错误码枚举与 `CoreException.code` 映射正确（见 §6 修正依据） |
| `grading/difficulty.dart`、`visual/*`、`narrative/*` | 通过 | 枚举与值对象完备；强制携带不破坏"零 Flutter 依赖" |

---

## §2 问题分级清单

| 级别 | 编号 | 模块 | 描述 | 路由 |
|---|---|---|---|---|
| **阻断** | — | — | 无 | — |
| **严重** | — | — | 无 | — |
| **一般** | G1 | `test/board_test.dart` | `kSample` 实际 30 个非空数字，但两处断言写 `equals(29)`；`raw` 测试字符串实际长 **82**（含非标准字符），`fromPuzzleString` 因 `cleaned.length(82)!=81` 抛 `E_BOARD_001`，测试会报错而非通过。**属测试代码缺陷，非源码 bug** | QA 已自行修正（self） |
| **一般** | G2 | `engine/generator.dart` | `generate(requireExactTarget:false)` 仅尝试 1 轮；CLI 层若不同步置 `requireExactTarget:true` 或自行换 seed，则 17–29 提示数区间不可达。此为设计约定，但**需 CLI 管线明确承接**，否则是隐性能力缺口 | 建议（见 §7） |
| **建议** | S1 | `model/board.dart:38` | `fromPuzzleString` 正则 `RegExp(r'[\s|\-+]')` 中 `\|` 在字符类内为字面量竖线（非"或"），可接受但未去除逗号 `,` 等分隔符；建议补注释或追加 `,` | 建议 |
| **建议** | S2 | `techniques/technique_result.dart:206` | `operator==` 仅比 `techniqueId + fingerprint`；正确性依赖 `computeFingerprint` 内容完备（当前含 E/P 列表，已完备）。批次 C 接入新技巧时需保证指纹覆盖全部结论字段 | 建议 |
| **建议** | S3 | `engine/sanity_guard.dart:52` | `enabled` 是全局可变静态状态，并发/并行测试场景需谨慎（已写入 `setUp/tearDown` 复位）。架构评审已记例外 | 已知 |
| **建议** | S4 | `model/board.dart:332` | `operator==` 比较 `candidateMasks`。两个逻辑相等但候选掩码暂未同步的棋盘会判不等（如一个已 `recomputeAll`、一个未）。undo/redo 与 clone 路径已正确保持候选一致，但业务层比对需知此语义 | 建议 |
| **建议** | S5 | `util/fingerprint.dart` | `Fingerprint.of` 仅做数字重标 + 转置同构识别（不覆盖行/列带置换）；文档已说明由批次 D 加强 | 已知 |

> 结论：**源码层面 = NoOne（无阻断/严重 bug）**；唯一"一般"级缺陷 G1 是工程师现有测试代码的断言错误，已按智能路由规则由 QA 自行修正（见 §6）。

---

## §3 深挖一：生成器唯一解保证

**结论：【静态已完成】判定为正确。**

### 3.1 算法链路

```
generate(rng)
  └─ generateFullSolution(rng)        // 随机回溯终盘（必然有解，无解抛 E_SOLVE_001）
  └─ digHoles(solution, target, rng)  // 逐格挖洞
        └─ 每挖一组格 → _checker.isUniqueValues(working)   // countSolutions(stopAt:2)==1
              ├─ 唯一 → 保留挖空
              └─ 非唯一 → 回填（backup 还原）
  └─ 返回 Puzzle{given, solution, seed}
```

### 3.2 唯一解保证的静态论证

1. **初始状态**：`solution` 本身是合法终盘（唯一解，因终盘填满），`digHoles` 起点 `working = solution` 唯一解。
2. **单调性**：每次只"尝试挖空一组格"。挖空**减少**约束，只可能 **增加** 解的数量（不会减少）。因此：
   - 若挖空后 `isUniqueValues==true`（仍唯一），安全保留；
   - 若 `isUniqueValues==false`（出现第二解），立即用 `backup` 回填整组，**撤销本次挖空**，恢复上一刻的唯一解状态。
3. **终止性**：最多挖到 `remaining <= floor`（floor = max(targetGivens, 17)）即停止；`_digOrder` 有限（81 组），循环必然终止，无死循环风险。
4. **最终保证**：循环结束时 `working` 的每一处"已挖空"都通过了 `isUniqueValues` 复验；任何会破坏唯一解的挖空都已被回填。故返回题面**必然唯一解**。

### 3.3 可复现性

全部随机走传入的 `Rng`：`generateFullSolution` 用 `Rng` 驱动回溯数字顺序；`digHoles` 用 `rng.shuffled`/`rng.shuffle` 决定挖洞顺序；`generate` 重试轮用 `rng.derive(attempt)`。同 seed → 同一 `Rng` 序列 → 同一道题（已写 `同 seed 可复现` 测试钉死）。

### 3.4 对称与兜底

- `SymmetryMode.central`：按 `index / 80-index` 成对挖，成对破坏则整对回填，更美观且抖动更小。
- `requireExactTarget=true`：最多 `kMaxRestart=8` 轮换终盘重试，仍不达目标则返回最优（不抛异常）。`requireExactTarget=false` 仅 1 轮（见 G2）。

### 3.5 风险点核查

- **会不会"看似唯一实际多解"？** 不会——`isUniqueValues` 走 `countSolutions(stopAt:2)`，第二解一旦存在即返回计数 2，判定为非唯一。计数口径与 `UniquenessChecker` 收敛到同一回溯实现，无口径分裂。
- **回溯会不会栈溢出？** 递归深度 ≤ 空格数 ≤ 81，远在 Dart 栈安全范围内；`_SolverState` 用 used 掩码 + MRV，无无限递归（每次递归必填一格或剪枝）。

---

## §4 深挖二：SanityGuard（删数 ≠ 终局解）

**结论：【静态已完成】判定为正确，是项目 P0 正确性底座。**

### 4.1 职责

任何技巧识别器/逐级求解器的**每一步结论**（eliminations/placements）都必须经 `SanityGuard.checkResult(ctx, result)`。一旦"删掉了某格的正确候选"或"填了错误数字"，玩家将被引入死局（P0 缺陷），必须抛 `E_TECH_001`。

### 4.2 断言逻辑

- `assertEliminationSafe(solution, cell, digit)`：`solution[cell] == digit` → 抛（删掉了终局解该有的候选）。
- `assertPlacementSafe(solution, cell, digit)`：`solution[cell] != digit` → 抛（填错数字）。
- `checkResult`：遍历 `result.eliminations`/`result.placements`，逐个调用上述断言。

### 4.3 "短路放行"争议点（非 bug）

`if (!enabled || solution == null) return;` —— 当 `ctx.hasSolution == false`（玩家文本导入等无终局解场景）时整体放行。**这是设计而非缺陷**：没有终局解时无法做"是否等于解"的判定，护栏的语义前提不存在。此行为已在源码注释与架构文档中显式说明。

### 4.4 `enabled` 全局开关

`static bool enabled = true`，默认开启，生产环境不得关闭（仅专项性能基准可临时置 false）。本层唯一可变全局状态，架构评审已记例外（见 S3）。测试中以 `setUp/tearDown` 复位，避免相互污染。

### 4.5 补强断言

已写 `sanity_guard_block_test.dart`：误删抛 `E_TECH_001`、误填抛、安全不抛、null 放行、关闭放行、`checkResult` 统一入口、批量 `collectViolations` 统计。

---

## §5 分层门禁 / lint / 依赖核查

**结论：【静态已完成】全部通过。**

| 规则 | 检查项 | 结果 |
|---|---|---|
| R1 | `sudoku_core` 禁 `flutter`/`ui`/`io`/`print` | ✅ 经 grep + 通读确认，源码零 Flutter 依赖；`grep "print\("` 在 `technique_result.dart` 的两处为 **fingerprint/computeFingerprint 假阳性**（正则 `(^|[^\w.])print\s*\(` 不匹配 "fingerprint" 中的 "print"），无真实违规 |
| R2 | `sudoku_cli` 禁 `flutter`/`ui` | ✅ |
| R3 | `app/lib/core` 禁 `flutter`/`ui` | ✅ 仅 re-export |
| R4 | `app/lib/domain` 禁 widget | ✅（本批次尚未引入 domain/widget 深层耦合） |
| R5 | `sudoku_core` 禁 `print` | ✅ 无真实 `print(` 调用 |
| R6 | 禁相对路径跨包 import | ✅ 全部 `package:` 绝对导入 |

> 说明：R5 的"假阳性"已在源码通读中排除，未计入问题清单。如需 100% 确定性，客户机执行 `check_layering.dart` 即可（§8）。

---

## §6 现有测试缺陷发现与修复（QA 自行修正）

通过 Python 精确核算 `board_test.dart` 的字符串与计数，发现**两处测试代码缺陷**（非源码 bug，按智能路由规则由 QA 自行修正）：

### 缺陷 1：给定数断言错误（30 vs 29）

`kSample = '530070000600195000098000060800060003400803001700020006060000280000419005000080079'`：
- Python 核算：`len == 81`，非空格(1–9)字符数 == **30**。
- 测试断言：`expect(board.givenCount(), equals(29))`（第 48 行）与 `expect(puzzle.givenCount, equals(29))`（第 74 行）。
- 后果：实际返回 30，断言失败 → CI 红灯。
- 修正：两处均改为 `equals(30)`。

### 缺陷 2：`raw` 字符串长度 82 触发 `E_BOARD_001`

原测试 `'非标准空格字符被正确归一并往返'`：
- `raw` 实测长度 **82**（53 个 `.` + 29 个非点字符）；
- `fromPuzzleString(raw.replaceAll('.','0').replaceAll('0','.'))` 等价于 `fromPuzzleString(raw)`；
- `fromPuzzleString` 先 `cleaned = s81.replaceAll(RegExp(r'[\s|\-+]'),'')`，`cleaned.length(82) != 81` → 抛 `E_BOARD_001`（code `E_BOARD_001` 对应 `CoreErrorCode.boardStringLength`）。
- 后果：测试期望成功（`expect(...equals(raw))`），实际抛异常 → 测试报错。
- 修正：改为 `final String raw = kSample.replaceAll('.', ' ');`（空格归一，长度恰 81），断言 `board.toPuzzleString() == kSample`，既验证空白归一又保证长度合法。

### 修正依据（错误码映射）

`core_error.dart`：`CoreErrorCode.boardStringLength('E_BOARD_001', …)`、`techEliminationHitsSolution('E_TECH_001', …)`。原 `board_test.dart` 断言 `'E_BOARD_001'` 与 `fromPuzzleString` 实际抛出码一致——故缺陷 2 是**字符串长度问题**，非错误码不匹配。

---

## §7 补强单元测试说明（写文件，**未执行**）

新增 4 个测试文件于 `packages/sudoku_core/test/`，均不依赖随机 SDK 之外的特殊环境，**客户端 `dart test` 直接可跑**：

| 文件 | 覆盖点 | 关键断言 |
|---|---|---|
| `generator_uniqueness_stress_test.dart` | 生成器唯一解 + 可解性 | 100 个随机 seed 均唯一解、可解且解==终局解；同 seed 可复现；中心对称唯一解；`requireExactTarget` 不抛 |
| `candidate_sync_consistency_test.dart` | 候选增量同步一致性 | 10,000 步随机 place/clear 后 `syncAfterX` 与 `recomputeAll` 候选逐格相等、无死格 |
| `undo_redo_roundtrip_test.dart` | 撤销/重做快照完整性 + 100 步上限 | 50 步 undo 回初始、redo 回各中间态；栈深 ≤100，超出 FIFO 淘汰最早记录 |
| `sanity_guard_block_test.dart` | 误删/误填拦截（P0 底座） | 误删/误填抛 `E_TECH_001`；安全不抛；null/关闭放行；`checkResult` 统一入口；`collectViolations` 计数 |

此外，既有 6 个测试文件（`board_test`/`generator_test`/`move_test`/`sanity_guard_test`/`validator_test`/`uniqueness_checker_test`）已通过通读确认逻辑合理；其中 `board_test.dart` 的两处缺陷由 QA 在 §6 修正。

> **G2 提示**：`generator.generate(requireExactTarget:false)` 默认仅 1 轮，`sudoku_cli` 出题管线应使用 `requireExactTarget:true` 或自行换 seed 重试，才能稳定产出 17–29 提示数题目。建议批次 D 在 CLI 层补一段"达不成目标提示数则换 seed"的循环并加测试。

---

## §8 客户机验证清单（精确命令序列 + 预期结果 + 覆盖率 ≥90%）

> 下列命令**必须在安装 Flutter/Dart SDK 的机器上执行**。本沙箱无法运行。
> ⚠️（勘误：2026-08-07 起本机即为该"客户机"，下列命令已可全部在本机直接执行，见文首勘误。）

### 8.1 分层门禁 + 静态分析（R1–R6）

```powershell
cd <repo>
# 分层检查（含 R5 的 print 校验，已排除 fingerprint 假阳性）
dart run tools/ci/check_layering.dart
# 期望：全部规则 PASS，exit 0
```

```powershell
cd packages/sudoku_core
flutter pub get          # 或 dart pub get（纯 Dart 包）
flutter analyze .        # 期望：No issues found!（零告警，满足 P0-QA-07）
```

```powershell
cd packages/sudoku_cli
flutter pub get
flutter analyze .        # 期望：No issues found!
```

```powershell
cd app
flutter pub get
flutter analyze .        # 期望：No issues found!（R3/R4 口径）
```

### 8.2 运行全部单测（含本次补强 4 个 + 修正后的 board_test）

```powershell
cd packages/sudoku_core
flutter test --reporter expanded
# 期望：ALL PASS（含新增 generator_uniqueness_stress / candidate_sync_consistency /
#        undo_redo_roundtrip / sanity_guard_block，以及修正后的 board_test）
# 注：本批次属算法层，dart test 亦可：dart test --reporter expanded
```

### 8.3 行覆盖 ≥90%（P0-QA-01）

```powershell
cd packages/sudoku_core
flutter test --coverage
# 生成 coverage/lcov.info
# 查看概要：
genhtml coverage/lcov.info -o coverage/html   # 需 lcov；或用
dart tool 或 `lcov`/`coverdeco` 解析
# 期望：sudoku_core 行覆盖率 >= 90%
# 重点确认被覆盖：generator.dart / backtracking_solver.dart / sanity_guard.dart /
#                  candidate_calculator.dart / undo_stack.dart / move_applier.dart
```

> 若覆盖率未达 90%：本批次补强测试已覆盖生成器唯一解、候选同步、undo/redo、SanityGuard 四大高风险面；剩余缺口通常在 `visual/*`、`narrative/*`（纯值对象，可补轻量构造测试）与 `techniques/*` 空壳（批次 C 接入后自然覆盖）。

### 8.4 模糊测试（P0-QA-03 部分，建议最低 10,000 题）

```powershell
cd packages/sudoku_core
# 借助 generator_uniqueness_stress_test 的"100 次循环"放大：
# 临时把循环上限改为 10000（或新增 fuzz 组），运行：
flutter test test/generator_uniqueness_stress_test.dart --reporter expanded
# 期望：10000 题全部唯一解 + 可解 + 解==终局解，0 失败
```

### 8.5 CLI 自检（批次 D 接入后）

```powershell
cd packages/sudoku_cli
dart run bin/sudoku_cli.dart selftest   # 期望：selftest PASS
```

### 8.6 预期结果汇总

| 检查 | 预期 |
|---|---|
| `check_layering.dart` | R1–R6 全 PASS |
| `flutter analyze`（三包） | 0 issues |
| `flutter test`（sudoku_core） | ALL PASS |
| 行覆盖率 | ≥ 90% |
| 模糊测试（≥10,000 题） | 唯一解率 100%、可解率 100% |

---

## §9 路由结论与严重问题清单

### 9.1 智能路由结论

| 维度 | 结论 | 说明 |
|---|---|---|
| **生产源码（批次 A+B）** | **NoOne** | 静态通读 + 算法推演 + Python 核算，**未发现阻断/严重级源码 bug**；生成器唯一解保证、SanityGuard、回溯、候选增量、undo/redo、RuleSet、分层约束均成立 |
| **工程师现有测试缺陷（board_test.dart ×2）** | **QA 自行修正（self）** | G1：两处 `givenCount==29` 应为 30；`raw` 82 字符触发 E_BOARD_001。已按智能路由规则由 QA 修正（§6） |
| **补强单测** | **QA 自产（self）** | 4 个新测试文件（§7），未执行，待客户机 CI 落地 |
| **是否需要工程师介入** | **否（本批次）** | 唯一"一般"缺陷 G1 已自行修复；G2/S1–S5 均为建议级，不阻塞放行 |

### 9.2 严重问题清单

- **阻断级：无**
- **严重级：无**
- **一般级**：G1（已修）、G2（建议 CLI 承接）
- **建议级**：S1–S5（均不阻塞）

---

## §10 结论与放行建议

1. **批次 A+B 算法层源码质量达到放行门槛**：核心算法（唯一解生成、SanityGuard、回溯、候选增量、undo/redo、技巧框架扩展点、三层分层）静态判定正确，无阻断/严重 bug。
2. **测试面已由 QA 补强**：4 个高风险面补强测试已落盘，待客户端执行；既有 `board_test.dart` 两处断言错误已修正。
3. **放行前提（客户机）**：§8 的 analyze 零告警、test 全绿、覆盖率 ≥90%、模糊测试唯一解率 100% 四项必须全部满足后方可合入。
4. **建议跟踪**：G2（CLI 出题重试策略）、S2（指纹完备性）、S5（Fingerprint 加强）列入批次 C/D 验收 checklist。

> 本报告全部为**静态判定**；可执行断言与量化门槛（覆盖率、模糊测试规模）的最终确认以 §8 客户机执行为准。
