# 数独教学跨端游戏（Sudoku Tutor）

> 跨端数独**教学**游戏：Windows 桌面 + Android，简体中文。本期 scope = **T2**（默认 16 项技巧全量）。
> 架构分层：纯 Dart 算法层 `packages/sudoku_core` → Dart CLI `packages/sudoku_cli` → Flutter 应用 `app`。

---

## 1. 仓库结构

```
.
├── pubspec.yaml                 # 仓库根占位包（CI 脚本上下文，不参与打包）
├── packages/
│   ├── sudoku_core/             # 纯 Dart 算法层（无 Flutter 依赖）⛔ 分层铁律
│   │   └── lib/src/{util,model,engine,visual,narrative,techniques,grading,puzzle}
│   └── sudoku_cli/              # 离线出题工具（Dart CLI，仅复用 sudoku_core）
├── app/                         # Flutter 应用（Windows / Android）
│   └── lib/{app,core,ui,features,data}
├── tools/ci/                    # 分层门禁 + CI 一键脚本
│   ├── check_layering.dart      # R1–R6 静态分层扫描（CI 门禁）
│   └── run_gates.ps1            # pub get → 分层 → analyze → test → 覆盖率
├── scripts/                     # Windows 工具链安装/验证
│   ├── setup_windows.ps1
│   └── verify_env.ps1
└── docs/                        # 设计文档（00 开工确认表 … 07 任务分解）
```

## 2. 技术栈

| 层 | 技术 | 约束 |
|----|------|------|
| 算法层 | Dart 3.5+（纯 Dart） | 禁 `flutter` / `dart:ui` / `dart:io` / `print` |
| CLI | Dart 3.5+（`args`/`path`/`yaml`） | 禁 `flutter` / `dart:ui`，仅透传算法层 |
| 应用 | Flutter 3.24+ / Dart 3.5+ | Riverpod + go_router，Material 3 |
| 测试 | `test` + `coverage` | sudoku_core 行覆盖率门槛 90% |

## 3. 环境准备（客户机执行）

> ⚠️ **本仓库的 M0 代码在「无 Flutter/Dart SDK 的沙箱」中完成手写**，未执行任何 `flutter`/`dart`
> 命令（生成、解析、分析、测试、构建均需在具备 SDK 的机器上运行）。下列步骤请在你的开发机执行。

**Windows：**

```powershell
# 1. 以管理员身份运行，安装 Flutter / VS C++ / JDK17 / Android SDK
powershell -ExecutionPolicy Bypass -File .\scripts\setup_windows.ps1

# 2. 关闭并重新打开终端，验证环境（生成 env_report_*.txt）
powershell -ExecutionPolicy Bypass -File .\scripts\verify_env.ps1

# 3. 三个包分别解析依赖
dart pub get --directory packages/sudoku_core
dart pub get --directory packages/sudoku_cli
flutter pub get --directory app
```

**macOS / Linux：** 直接安装 Flutter 3.24+，然后执行上面的第 3 步（`flutter`/`dart pub get`）。

## 4. 分层铁律（CI 门禁 `tools/ci/check_layering.dart`）

| 规则 | 受检目录 | 禁止 |
|------|----------|------|
| R1 | `packages/sudoku_core/lib` | `package:flutter`、`package:flutter_test`、`dart:ui`、`dart:io` |
| R2 | `packages/sudoku_cli/{lib,bin}` | `package:flutter`、`dart:ui` |
| R3 | `app/lib/core` | `package:flutter`、`dart:ui` |
| R4 | `app/lib/domain` | Flutter Widget 库、`app/lib/ui/**` |
| R5 | `packages/sudoku_core/lib` | 直接使用 `print(` |
| R6 | 所有包 | 相对路径跨包 import（`../../packages/`、`../../app/`） |

UI 一律经 `app/lib/core/core.dart` → `package:sudoku_core/sudoku_core.dart` 访问算法层，
**不得**直接写 `package:sudoku_core/...` 深层路径。

## 5. 测试与 CI

```powershell
# Windows 一键门禁（含覆盖率门槛）
pwsh -File tools/ci/run_gates.ps1

# 跳过覆盖率（批次 A 允许）
pwsh -File tools/ci/run_gates.ps1 -SkipCoverage

# 仅跑分层扫描
dart run tools/ci/check_layering.dart
```

算法层核心链路自检（生成 → 唯一解校验 → 回溯求解 → 比对终局解）：

```bash
dart run sudoku_cli:sudoku_cli selftest
```

## 6. 批次进度

| 批次 | 内容 | 状态 |
|------|------|------|
| **A** | M0 工程基建 + 三层骨架（三包 + barrel + 分层门禁 + app 冒烟页） | ✅ 完成 |
| **B** | 算法层基础设施（model/validator/candidate/solver/generator/move/undo/sanity/visual/narrative/techniques 框架/puzzle 值对象） | ✅ 完成 |
| C | 16 项技巧识别器 + 求解器 + 难度评级 | ⏳ 待启动 |
| D | CLI 出题子命令（generate/annotate/filter/export*/verify） | ⏳ 待启动 |
| E | 数据层（存档/关卡/题库 codec） | ⏳ 待启动 |
| F | UI 页面（学习地图/演示/实操/试炼/对局/设置） | ⏳ 待启动 |

## 7. 关键设计约定

- **`givenMask` 全链路携带**：题面给定格永不可变，UR/W 翼判定强依赖此掩码（PRD C-11）。
- **候选集位掩码**：`1 << (digit - 1)`，全集 `0x1FF`，`extension type const CandidateSet` 零开销（SDK ≥ 3.3）。
- **可复现随机**：全部随机走 `Rng(seed)`，禁用全局随机（CLI 同 seed 可复现）。
- **SanityGuard**：`E_TECH_001` 断言删数/填数不违背终局解，逐级求解器每一步必经 `SanityGuard.checkResult`；
  唯一允许的可变全局态 `SanityGuard.enabled`（架构 §7.1 例外）。
- **错误码**：`E_BOARD_` / `E_SOLVE_` / `E_TECH_` / `E_IO_` / `E_SCHEMA_` / `E_IMPORT_`，统一 `CoreException`。

详见 `docs/` 下的设计文档（`06-架构设计.md`、`07-任务分解.md`）。
