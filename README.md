<h1 align="center">数独学堂（Sudoku Tutor）</h1>

<p align="center">
面向零基础到进阶玩家的 Windows / Android 离线数独教学应用。
</p>

<div align="center">
<img alt="Tests" src="https://img.shields.io/badge/tests-passing-brightgreen"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"><img alt="Version" src="https://img.shields.io/badge/version-0.1.0%2B1-informational"><img alt="Language" src="https://img.shields.io/badge/Dart-%3E%3D3.5-0175C2">
</div>

<p align="center">
🇨🇳 <a href="./README.md">简体中文</a> | 🇺🇸 <a href="./README.en.md">English</a>
</p>

## 目录

- [项目简介](#项目简介)
- [核心特色](#核心特色)
- [教学内容](#教学内容)
- [支持平台](#支持平台)
- [安装](#安装)
- [使用方法](#使用方法)
- [架构](#架构)
- [仓库结构](#仓库结构)
- [技术栈](#技术栈)
- [API 与 CLI 参考](#api-与-cli-参考)
- [配置与本地数据](#配置与本地数据)
- [测试与质量门禁](#测试与质量门禁)
- [构建发布产物](#构建发布产物)
- [参与贡献](#参与贡献)
- [当前限制](#当前限制)
- [许可证](#许可证)

## 项目简介

数独学堂不是单纯的数独棋盘，而是一套完整的离线学习体验。它把 16 项人类解题技巧组织为渐进课程，让玩家依次经历“看懂原理、在引导下练习、独立完成试炼”，再通过五档自由练习巩固。

项目面向 Windows 与 Android，所有课程、题库、提示和存档均在本地运行：无需账号、无需后端，也不依赖联网服务。应用界面支持简体中文与 English 即时切换；内置课程旁白和教学内容仍为简体中文。

当前仓库包含：

- 34 个正式教学关卡，覆盖第 0–3 章；
- 5 个压缩自由练习题库，对应入门、简单、中等、困难、大师；
- 4 个章节综合试炼题池；
- 纯 Dart 数独核心引擎、离线题库 CLI 与 Flutter 应用；
- 技巧百科、开发者模式和挑战码异步对决等辅助功能。

> [!IMPORTANT]
> English 界面覆盖导航、设置与对局控件；课程旁白、技巧讲解等教学内容目前仍为简体中文。

## 核心特色

| 能力 | 说明 |
|---|---|
| 三阶段教学 | 原理演示使用只读棋盘和分步旁白；引导实操提供三级渐进提示；综合试炼关闭提示，要求独立解完整盘 |
| 16 项技巧引擎 | 从唯一余数到唯一矩形、W 翼和简单涂色，统一输出结论、讲解参数与可视化标记 |
| 五档自由练习 | 按求解过程所需最高技巧划分入门、简单、中等、困难、大师 |
| 不泄露答案的提示 | 自由练习提供两级技巧提示，引导实操提供三级提示；提示不会直接给出某格应填数字 |
| 完整对局工具 | 支持候选数/笔记、自动候选、撤销、重做、重置、暂停、计时和答案核对 |
| 断点续玩 | 退出自由练习时保存盘面、笔记、用时及撤销/重做状态，下次可继续 |
| 教学可视化 | 棋盘高亮、区域描边、强弱链和候选划除均由算法层生成结构化数据，UI 不自行猜测 |
| 完全离线 | 内置课程和压缩题库，使用本地 JSON 存储，无账号、无数据库、无网络服务 |
| 跨端输入 | 桌面端支持键盘操作，移动端使用常驻数字键盘 |
| 离线工具链 | CLI 可生成、标注、筛选、验证和导出题库/教学关数据，并与应用共用同一个核心引擎 |

## 教学内容

### 16 项解题技巧

| 难度 | 技巧 |
|---|---|
| 入门 | 唯一余数（Naked Single）、隐性唯一数（Hidden Single） |
| 简单 | 裸对（Naked Pair）、隐对（Hidden Pair）、区块排除（Pointing & Claiming） |
| 中等 | 裸三（Naked Triple）、隐三（Hidden Triple）、X 翼（X-Wing） |
| 困难 | 鳍形 X 翼（含 Sashimi）、剑鱼（标准）、XY 翼、XYZ 翼、W 翼 |
| 大师 | 唯一矩形 型一、唯一矩形 型二、简单涂色（Rule 2 + Rule 4） |

### 学习流程

1. **原理演示**：在只读盘面中查看逐步动画、技巧节点和参数化旁白。
2. **引导实操**：自己操作盘面；遇到困难时按顺序解锁“技巧区域 → 关键格 → 删数结论”三级提示。
3. **综合试炼**：提示关闭，独立完成包含目标技巧的盘面；失败后可继续挑战或返回演示复习。

### 课程与题库

| 内容 | 当前规模 | 位置 |
|---|---:|---|
| 第 0–3 章正式课程 | 34 关 | `app/assets/curriculum/` |
| 自由练习题库 | 5 档 | `app/assets/puzzles/*.json.gz` |
| 章节试炼题池 | 4 组 | `app/assets/pools/*.json.gz` |
| 教学纠错文案 | 1 组 | `app/assets/text/` |

## 支持平台

| 平台 | 当前支持 | 分发方式 | 备注 |
|---|---|---|---|
| Windows 10 1809 x64 及以上 | ✅ | 绿色版 ZIP；可选 Inno Setup 安装器 | 当前构建未签名，首次启动可能触发 SmartScreen |
| Android 8.0 / API 26 及以上 | ✅ | debug 签名 APK | 面向 arm64-v8a 与 armeabi-v7a |
| macOS / iOS | ⛔ | 无本期产物 | 当前仓库未提供对应交付包 |
| Web | ⛔ | 不支持 | 当前范围明确不包含 Web |

## 安装

### 普通玩家

#### Windows

从项目方获取以下任一产物：

- `SudokuTutor-windows-x64.zip`：解压后运行目录中的 `sudoku_tutor.exe`；
- `Setup-SudokuTutor-0.1.0.exe`：运行安装向导。该文件只有在构建机安装 Inno Setup 6 时才会生成。

> [!WARNING]
> Windows 版本目前没有 Authenticode 代码签名。SmartScreen 可能显示“Windows 已保护你的电脑”；请仅在确认文件来源可信时选择“更多信息 → 仍要运行”。

#### Android

获取 `app-debug.apk` 后，在允许安装可信来源 APK 的设备上打开该文件完成安装。开发者也可使用 Android SDK：

~~~bash
adb install -r app-debug.apk
~~~

> [!NOTE]
> 当前 APK 使用 debug 签名，定位为测试/受控分发产物，不是应用商店正式发布包。

### 从源码运行

<details>
<summary>展开开发环境与运行步骤</summary>

#### 环境要求

- Flutter `>=3.24.0`；
- Dart `>=3.5.0 <4.0.0`；
- Windows 开发需要 Visual Studio C++ 桌面工具链；
- Android 开发需要 Android SDK、可用设备/模拟器及 JDK 17；
- PowerShell 5.1 或 PowerShell 7+。

本次 README 验证环境为 Flutter `3.44.8`、Dart `3.12.2`、PowerShell `7.6.4`。

#### 解析依赖

在仓库根目录执行：

~~~powershell
dart pub get --directory packages/sudoku_core
dart pub get --directory packages/sudoku_cli
flutter pub get --directory app
~~~

#### 运行 Windows 应用

~~~powershell
cd app
flutter run -d windows
~~~

#### 运行 Android 应用

~~~powershell
cd app
flutter devices
flutter run -d <DEVICE_ID>
~~~

`<DEVICE_ID>` 是 `flutter devices` 输出的设备标识，不需要配置 API Key 或服务端地址。

</details>

## 使用方法

### 场景一：沿课程学习数独技巧

1. 首次启动后完成或跳过引导页。
2. 在学习地图中选择章节和关卡；所有已登记课程均可自由进入。
3. 先在原理演示关查看技巧形态、关键格、候选划除和旁白。
4. 进入引导实操关亲自操作；需要帮助时逐级请求提示。
5. 在综合试炼关关闭提示完成整盘，检验是否真正掌握。

### 场景二：进行自由练习

1. 进入自由练习并选择入门、简单、中等、困难或大师。
2. 使用填数、笔记/候选、自动笔记、撤销、重做和暂停完成盘面。
3. 卡住时请求两级技巧提示；提示只解释思路，不直接泄露填数答案。
4. 使用“核对答案”只标出错误的已填格，不自动纠正，也不展示空格答案。
5. 退出时保存断点，下次选择继续上次对局。

### 桌面端快捷键

| 操作 | 快捷键 |
|---|---|
| 移动选中格 | 方向键 |
| 填入数字 | `1`–`9` |
| 标记候选数 | `Shift` + `1`–`9` |
| 清除当前格 | `Delete` |

## 架构

项目采用单向分层：Flutter UI 只负责展示与输入，Domain 层负责对局、课程、存档和 Isolate 调度，所有数独算法集中在纯 Dart 的 `sudoku_core`。离线 CLI 直接复用该核心包，因此应用内提示与题库生产使用同一套规则。

<!-- Experimental: if rendering fails, preview on GitHub -->
~~~mermaid
graph TD
    UI["Flutter UI<br/>页面 · 棋盘 · 输入 · 教学叠层"] --> DOMAIN["App Domain<br/>课程 · 对局 · 提示 · 存档"]
    DOMAIN --> CORE["sudoku_core<br/>纯 Dart 数独引擎"]
    CLI["sudoku_cli<br/>生成 · 标注 · 筛选 · 导出 · 验证"] --> CORE
    CLI --> ASSETS["离线 JSON / JSON.gz 资产"]
    ASSETS --> DOMAIN
    CI["CI 门禁<br/>分层 · 分析 · 测试 · 覆盖率"] --> CORE
~~~

关键设计原则：

- `sudoku_core` 不依赖 Flutter、UI、文件系统或网络；
- UI 不推断技巧坐标，只渲染核心层提供的 `VisualHint`；
- 生成、难度评级和技巧扫描等重计算通过 Isolate 执行；
- 随机过程使用显式 seed，便于复现；
- `givenMask` 贯穿求解链路，确保唯一矩形等技巧的前提正确；
- 所有删数结论经 `SanityGuard` 校验，防止删掉终局真值。

## 仓库结构

~~~text
.
├── app/                       # Flutter 应用
│   ├── lib/app/               # 启动、路由、全局 Provider
│   ├── lib/domain/            # 课程、对局、提示、存储与业务服务
│   ├── lib/ui/                # 页面、棋盘绘制、输入与主题
│   └── assets/                # 课程、题库、试炼池、文案、图像、音频
├── packages/
│   ├── sudoku_core/           # 纯 Dart 核心引擎与 16 项技巧
│   └── sudoku_cli/            # 离线题库生产与验证 CLI
├── dataset/                   # 技巧标注集与候选数据
├── docs/                      # PRD、架构、QA、打包等文档
├── installer/                 # Inno Setup 配置
├── scripts/                   # 环境检查与发布构建脚本
└── tools/ci/                  # 分层扫描与一键质量门禁
~~~

## 技术栈

| 领域 | 技术/依赖 |
|---|---|
| 应用框架 | Flutter `>=3.24.0`、Dart `>=3.5.0 <4.0.0` |
| 状态管理 | Riverpod `^2.6.1`（不使用代码生成） |
| 路由 | go_router `^14.6.0` |
| 本地存储 | JSON、path_provider、shared_preferences |
| 文件导入/分享 | file_selector、share_plus |
| 棋盘与教学渲染 | CustomPaint / CustomPainter |
| 核心库 | 纯 Dart；meta、collection |
| CLI | args、path、yaml |
| 测试 | test、flutter_test、integration_test、coverage、Golden tests |
| Windows 安装器 | Inno Setup 6（可选） |

## API 与 CLI 参考

### `sudoku_core` 公共入口

外部包只应导入唯一公共 barrel：

~~~dart
import "package:sudoku_core/sudoku_core.dart";
~~~

| API 家族 | 主要能力 |
|---|---|
| `model` | `Board`、候选位集、坐标、单元与编解码 |
| `engine` | 校验、候选同步、回溯求解、唯一解、生成、Move、撤销/重做、安全校验 |
| `techniques` | 规则集、技巧注册表、16 项识别器、`TechniqueResult` |
| `visual` / `narrative` | 高亮、区域、连线、候选标记和参数化中文讲解 |
| `grading` | 根据逐级求解过程计算五档难度 |
| `puzzle` / `solver` | 题库、关卡、解题脚本编解码及脚本回放 |

不要从其他包深层导入 `package:sudoku_core/src/...`。

### CLI

~~~powershell
cd packages/sudoku_cli
dart run sudoku_cli:sudoku_cli --help
dart run sudoku_cli:sudoku_cli selftest
~~~

| 命令 | 用途 |
|---|---|
| `selftest` | 生成题面，检查唯一解，并用回溯求解比对终局 |
| `generate` | 批量生成唯一解盘面，可选逐级标注并输出命中率 |
| `annotate` | 生成难度、技巧序列、解题脚本与可视化数据 |
| `filter` | 按技巧标签、难度或范围筛选标注集合 |
| `export-bank` | 导出五档自由练习 JSON.gz 题库 |
| `export-pool` | 导出按章节组织的综合试炼题池 |
| `export-level` | 将标注集合导出为逐关教学 JSON |
| `verify` | 校验唯一解、标注回放和解题脚本 |

CLI 退出码：`0` 表示成功，`1` 表示业务/质量目标未达标，`2` 表示参数、格式、IO 或核心错误。使用 `dart run sudoku_cli:sudoku_cli help <COMMAND>` 查看子命令参数。

## 配置与本地数据

应用运行不需要 `.env`、API Key、账号或服务端端点。

| 类型 | 说明 |
|---|---|
| 玩家设置 | 自动候选、错误标红、计时、相同数字高亮、提示次数、音效、棋盘主题 |
| 进度存档 | 纯 JSON，包含 schema 版本并支持迁移与备份 |
| 对局断点 | 保存盘面、候选/笔记、用时、撤销/重做和难度 |
| 课程 | `app/assets/curriculum/index.json` + 每关一个 JSON |
| 题库/试炼池 | 打包在应用资产中的 JSON.gz 文件 |
| CLI Profile | `packages/sudoku_cli/profiles/t1.yaml`、`t2.yaml` |

> [!CAUTION]
> 存档导入会校验 schema 与内容。高于当前应用版本的 schema、损坏数据或非法题面会被拒绝；请保留原始备份。

## 测试与质量门禁

### 一键门禁

~~~powershell
pwsh -File tools/ci/run_gates.ps1
~~~

门禁依次执行依赖解析、R1–R6 分层扫描、静态分析、核心/CLI/应用测试，并检查 `sudoku_core` 行覆盖率是否达到默认 90%。快速检查可使用：

~~~powershell
pwsh -File tools/ci/run_gates.ps1 -SkipCoverage
~~~

> [!WARNING]
> `-SkipCoverage` 只适合本地快速反馈，不应代替完整交付门禁。

### 本次 README 生成时的验证结果

| 测试范围 | 命令 | 结果 |
|---|---|---:|
| `sudoku_core` | `dart test` | 255 项通过 |
| `sudoku_cli` | `dart test` | 51 项通过 |
| Flutter app | `flutter test` | 350 项通过 |
| 合计 | — | **656 项通过** |

核心测试包含 10,000 局健全性模糊测试；本轮统计真实触发全部 16 项技巧，未发生错误删数断言。这里记录的是 2026-09-01 的本地验证快照，不等同于持续集成服务状态。

## 构建发布产物

在已配置 Flutter、Windows 和 Android 工具链的 Windows 主机上执行：

~~~powershell
pwsh ./scripts/build_release.ps1
~~~

脚本将：

1. 构建 Windows Release；
2. 生成 `dist/SudokuTutor-windows-x64/` 和绿色版 ZIP；
3. 构建 Android debug APK；
4. 检测到 Inno Setup 6 时生成 Setup 安装器。

<details>
<summary>构建参数与产物路径</summary>

| 参数 | 作用 |
|---|---|
| `-SkipWindows` | 跳过 Windows 构建和绿色版打包 |
| `-SkipAndroid` | 跳过 Android APK 构建 |
| `-SkipInnoSetup` | 即使已安装 ISCC 也不生成 Setup |

~~~text
dist/
├── SudokuTutor-windows-x64/
├── SudokuTutor-windows-x64.zip
└── Setup-SudokuTutor-0.1.0.exe       # 仅安装了 Inno Setup 时

app/build/app/outputs/flutter-apk/
└── app-debug.apk
~~~

</details>

详细说明见 [`docs/10-T-PKG01-打包说明.md`](./docs/10-T-PKG01-打包说明.md)。

## 参与贡献

提交改动前请保持以下分层约束：

| 规则 | 约束 |
|---|---|
| R1 | `packages/sudoku_core/lib` 禁止 Flutter、`dart:ui`、`dart:io` |
| R2 | `packages/sudoku_cli` 禁止 Flutter、`dart:ui` |
| R3 | `app/lib/core` 禁止 Flutter、`dart:ui` |
| R4 | `app/lib/domain` 不依赖 Widget 层或 `app/lib/ui` |
| R5 | `sudoku_core` 禁止直接调用 `print` |
| R6 | 所有包禁止使用相对路径跨包导入 |

建议流程：

1. 从独立分支开始修改。
2. 新增/修改技巧时同步更新识别器、中文模板、可视化数据和正反例测试。
3. 新增课程时添加单关 JSON，并登记到课程索引，不修改通用关卡逻辑。
4. 运行 `pwsh -File tools/ci/run_gates.ps1`。
5. 在提交说明中写清行为变化、测试结果和数据 schema 影响。

架构与需求基线见 [`docs/05-PRD基线.md`](./docs/05-PRD基线.md) 和 [`docs/06-架构设计.md`](./docs/06-架构设计.md)。

## 当前限制

- [x] 16 项 T2 范围内技巧与统一核心引擎
- [x] 第 0–3 章 34 个正式课程关卡
- [x] 五档自由练习题库与四章试炼池
- [x] Windows / Android 构建链路
- [x] 技巧百科、断点续玩和离线挑战码对决
- [ ] 正式品牌图标、应用名与启动素材仍需替换
- [ ] Windows 代码签名与 Android 正式发布签名尚未配置
- [ ] 英文教学内容尚未提供；应用界面已支持简体中文 / English

## 许可证

本项目采用 [MIT License](./LICENSE)。

Copyright (c) 2026 kaxaw
