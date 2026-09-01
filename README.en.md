<h1 align="center">Sudoku Tutor（数独学堂）</h1>

<p align="center">
An offline Sudoku learning app for beginners through advanced players on Windows and Android.
</p>

<div align="center">
<img alt="Tests" src="https://img.shields.io/badge/tests-passing-brightgreen"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"><img alt="Version" src="https://img.shields.io/badge/version-0.1.0%2B1-informational"><img alt="Language" src="https://img.shields.io/badge/Dart-%3E%3D3.5-0175C2">
</div>

<p align="center">
🇨🇳 <a href="./README.md">简体中文</a> | 🇺🇸 <a href="./README.en.md">English</a>
</p>

## Table of Contents

- [Overview](#overview)
- [Highlights](#highlights)
- [Learning Content](#learning-content)
- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
- [How to Use](#how-to-use)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Technology Stack](#technology-stack)
- [API and CLI Reference](#api-and-cli-reference)
- [Configuration and Local Data](#configuration-and-local-data)
- [Testing and Quality Gates](#testing-and-quality-gates)
- [Building Release Artifacts](#building-release-artifacts)
- [Contributing](#contributing)
- [Current Limitations](#current-limitations)
- [License](#license)

## Overview

Sudoku Tutor is more than a Sudoku board: it is a complete offline learning experience. It organizes 16 human-solving techniques into a progressive curriculum in which players first understand a concept, practise with guidance, and then complete an independent trial before reinforcing their skills in five free-play difficulty levels.

The project targets Windows and Android. Lessons, puzzle banks, hints, and save data all work locally, with no account, backend, or online service required. The application interface can switch between Simplified Chinese and English; bundled lesson narration and teaching content remain in Simplified Chinese.

The repository currently includes:

- 34 production lessons covering Chapters 0–3;
- five compressed free-play puzzle banks: Beginner, Easy, Medium, Hard, and Master;
- four chapter-based comprehensive trial pools;
- a pure-Dart Sudoku engine, an offline content CLI, and a Flutter application;
- a technique wiki, developer mode, and asynchronous challenge-code duels.

> [!IMPORTANT]
> English covers navigation, settings, and game controls. Lesson narration and technique explanations currently remain in Simplified Chinese.

## Highlights

| Capability | Description |
|---|---|
| Three-stage teaching | Read-only principle demonstrations with step-by-step narration, guided practice with three progressive hint levels, and comprehensive trials with hints disabled |
| 16-technique engine | Covers techniques from Naked Single through Unique Rectangles, W-Wing, and Simple Colouring, with unified conclusions, narration parameters, and visual markers |
| Five free-play levels | Difficulty is based on the hardest technique required by the logical solving path |
| Hints without answer leakage | Free play has two hint levels and guided practice has three; hints never directly reveal the digit for a cell |
| Full game controls | Candidates/notes, automatic candidates, undo, redo, reset, pause, timer, and answer checking |
| Session resume | Saves the board, notes, elapsed time, undo history, and redo history when leaving free play |
| Teaching visualization | Cell highlights, region outlines, strong/weak links, and candidate eliminations are structured data produced by the engine rather than inferred by the UI |
| Fully offline | Bundled lessons and compressed puzzle banks, local JSON persistence, no account, no database, and no network service |
| Cross-device input | Keyboard controls on desktop and a persistent number pad on mobile |
| Offline content toolchain | The CLI generates, annotates, filters, verifies, and exports puzzle/lesson data using the same engine as the app |

## Learning Content

### 16 Solving Techniques

| Difficulty | Techniques |
|---|---|
| Beginner | Naked Single（唯一余数）, Hidden Single（隐性唯一数） |
| Easy | Naked Pair（裸对）, Hidden Pair（隐对）, Pointing & Claiming（区块排除） |
| Medium | Naked Triple（裸三）, Hidden Triple（隐三）, X-Wing（X 翼） |
| Hard | Finned X-Wing including Sashimi（鳍形 X 翼）, standard Swordfish（剑鱼）, XY-Wing, XYZ-Wing, W-Wing |
| Master | Unique Rectangle Type 1, Unique Rectangle Type 2, Simple Colouring using Rule 2 + Rule 4 |

### Learning Flow

1. **Principle demonstration**: follow a read-only board with step animation, technique milestones, and parameterized narration.
2. **Guided practice**: operate the board yourself and progressively unlock three hint levels: technique area, key cells, and elimination conclusion.
3. **Comprehensive trial**: solve a board containing the target technique with hints disabled; continue trying or return to the demonstration when needed.

### Curriculum and Puzzle Banks

| Content | Current size | Location |
|---|---:|---|
| Production lessons for Chapters 0–3 | 34 lessons | `app/assets/curriculum/` |
| Free-play puzzle banks | 5 levels | `app/assets/puzzles/*.json.gz` |
| Chapter trial pools | 4 pools | `app/assets/pools/*.json.gz` |
| Teaching correction copy | 1 set | `app/assets/text/` |

## Supported Platforms

| Platform | Status | Distribution | Notes |
|---|---|---|---|
| Windows 10 1809 x64 or later | ✅ | Portable ZIP; optional Inno Setup installer | Current builds are unsigned and may trigger SmartScreen |
| Android 8.0 / API 26 or later | ✅ | Debug-signed APK | Targets arm64-v8a and armeabi-v7a |
| macOS / iOS | ⛔ | No current artifact | No deliverable package is provided in the current scope |
| Web | ⛔ | Unsupported | Web is explicitly outside the current project scope |

## Installation

### For Players

#### Windows

Obtain either artifact from the project distributor:

- `SudokuTutor-windows-x64.zip`: extract it and run `sudoku_tutor.exe` from the extracted directory.
- `Setup-SudokuTutor-0.1.0.exe`: run the installer. This file is created only when Inno Setup 6 is installed on the build machine.

> [!WARNING]
> The current Windows build has no Authenticode signature. SmartScreen may show “Windows protected your PC.” Continue only after verifying that the file came from a trusted source.

#### Android

Open the provided `app-debug.apk` on a device that permits installation from a trusted source. Developers with the Android SDK may use:

~~~bash
adb install -r app-debug.apk
~~~

> [!NOTE]
> The current APK is debug-signed for testing or controlled distribution; it is not a production app-store package.

### Running from Source

<details>
<summary>Expand development prerequisites and commands</summary>

#### Prerequisites

- Flutter `>=3.24.0`;
- Dart `>=3.5.0 <4.0.0`;
- Visual Studio Desktop development with C++ tools for Windows;
- Android SDK, a device/emulator, and JDK 17 for Android;
- Windows PowerShell 5.1 or PowerShell 7+.

This README was verified with Flutter `3.44.8`, Dart `3.12.2`, and PowerShell `7.6.4`.

#### Resolve Dependencies

Run from the repository root:

~~~powershell
dart pub get --directory packages/sudoku_core
dart pub get --directory packages/sudoku_cli
flutter pub get --directory app
~~~

#### Run the Windows App

~~~powershell
cd app
flutter run -d windows
~~~

#### Run the Android App

~~~powershell
cd app
flutter devices
flutter run -d <DEVICE_ID>
~~~

`<DEVICE_ID>` is the identifier printed by `flutter devices`. No API key or backend URL is required.

</details>

## How to Use

### Scenario 1: Learn Through the Curriculum

1. Complete or skip onboarding on the first launch.
2. Select a chapter and lesson on the learning map; every registered lesson can be opened freely.
3. Study the principle demonstration to see the pattern, key cells, candidate eliminations, and narration.
4. Move to guided practice and request hints progressively when needed.
5. Complete the full board in the comprehensive trial with hints disabled.

### Scenario 2: Practise Freely

1. Open free play and choose Beginner, Easy, Medium, Hard, or Master.
2. Use digit entry, notes/candidates, automatic notes, undo, redo, and pause to solve the board.
3. Request two-level technique hints when stuck; hints explain the reasoning without revealing a placement answer.
4. Use “Check answer” to mark only incorrect filled cells; it neither fixes them nor reveals empty cells.
5. Leave the game to save a checkpoint, then choose to resume it next time.

### Desktop Shortcuts

| Action | Shortcut |
|---|---|
| Move the selected cell | Arrow keys |
| Enter a digit | `1`–`9` |
| Mark a candidate | `Shift` + `1`–`9` |
| Clear the selected cell | `Delete` |

## Architecture

The project uses one-way layering. Flutter UI handles rendering and input, the Domain layer manages sessions, curriculum, storage, and Isolate dispatch, and all Sudoku algorithms live in the pure-Dart `sudoku_core` package. The offline CLI reuses that package directly, keeping in-app hints and content production on the same rule implementation.

<!-- Experimental: if rendering fails, preview on GitHub -->
~~~mermaid
graph TD
    UI["Flutter UI<br/>Pages · Board · Input · Teaching overlays"] --> DOMAIN["App Domain<br/>Curriculum · Sessions · Hints · Storage"]
    DOMAIN --> CORE["sudoku_core<br/>Pure-Dart Sudoku engine"]
    CLI["sudoku_cli<br/>Generate · Annotate · Filter · Export · Verify"] --> CORE
    CLI --> ASSETS["Offline JSON / JSON.gz assets"]
    ASSETS --> DOMAIN
    CI["Quality gates<br/>Layering · Analysis · Tests · Coverage"] --> CORE
~~~

Key design principles:

- `sudoku_core` has no dependency on Flutter, UI, the filesystem, or networking.
- UI renders `VisualHint` data and does not infer technique coordinates.
- Expensive generation, grading, and technique scans run through Isolates.
- Random operations use explicit seeds for reproducibility.
- `givenMask` travels through the solving pipeline to preserve prerequisites for techniques such as Unique Rectangles.
- Every elimination is checked by `SanityGuard` to prevent removal of a true solution candidate.

## Repository Structure

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

## Technology Stack

| Area | Technology / dependency |
|---|---|
| Application framework | Flutter `>=3.24.0`, Dart `>=3.5.0 <4.0.0` |
| State management | Riverpod `^2.6.1` without code generation |
| Routing | go_router `^14.6.0` |
| Local persistence | JSON, path_provider, shared_preferences |
| File import/sharing | file_selector, share_plus |
| Board and teaching rendering | CustomPaint / CustomPainter |
| Core package | Pure Dart; meta, collection |
| CLI | args, path, yaml |
| Testing | test, flutter_test, integration_test, coverage, Golden tests |
| Windows installer | Inno Setup 6, optional |

## API and CLI Reference

### Public `sudoku_core` Entry Point

External packages should import only the public barrel:

~~~dart
import "package:sudoku_core/sudoku_core.dart";
~~~

| API family | Main capabilities |
|---|---|
| `model` | `Board`, candidate bitsets, coordinates, units, and codecs |
| `engine` | Validation, candidate synchronization, backtracking, uniqueness, generation, Move, undo/redo, and safety checks |
| `techniques` | Rule sets, technique registry, 16 detectors, and `TechniqueResult` |
| `visual` / `narrative` | Highlights, regions, links, candidate marks, and parameterized Chinese narration |
| `grading` | Five-level grading from the logical solving path |
| `puzzle` / `solver` | Puzzle, lesson, and solution-script codecs plus script replay |

Do not deep-import `package:sudoku_core/src/...` from another package.

### CLI

~~~powershell
cd packages/sudoku_cli
dart run sudoku_cli:sudoku_cli --help
dart run sudoku_cli:sudoku_cli selftest
~~~

| Command | Purpose |
|---|---|
| `selftest` | Generate a puzzle, verify uniqueness, and compare the backtracking solution |
| `generate` | Generate unique puzzles in batches, optionally annotate them, and report hit rates |
| `annotate` | Produce difficulty, technique sequence, solution script, and visualization data |
| `filter` | Filter annotated collections by technique, difficulty, or range |
| `export-bank` | Export five compressed free-play JSON.gz banks |
| `export-pool` | Export comprehensive trial pools organized by chapter |
| `export-level` | Export annotated records as individual lesson JSON files |
| `verify` | Verify uniqueness, annotation replay, and solution scripts |

CLI exit codes are `0` for success, `1` when a business or quality target is not met, and `2` for usage, format, IO, or core errors. Run `dart run sudoku_cli:sudoku_cli help <COMMAND>` for command-specific options.

## Configuration and Local Data

The application requires no `.env`, API key, account, or backend endpoint.

| Type | Description |
|---|---|
| Player settings | Automatic candidates, error highlighting, timer, matching-digit highlight, hint quota, sound, and board theme |
| Progress save | Pure JSON with a schema version, migration chain, and backups |
| Session checkpoint | Board, candidates/notes, elapsed time, undo/redo, and difficulty |
| Curriculum | `app/assets/curriculum/index.json` plus one JSON file per lesson |
| Puzzle/trial banks | JSON.gz files bundled in the application assets |
| CLI profiles | `packages/sudoku_cli/profiles/t1.yaml` and `t2.yaml` |

> [!CAUTION]
> Save imports validate both schema and content. Data with a newer schema, corrupted content, or an invalid puzzle is rejected; keep the original backup.

## Testing and Quality Gates

### One-Command Gate

~~~powershell
pwsh -File tools/ci/run_gates.ps1
~~~

The gate resolves dependencies, checks R1–R6 layering rules, performs static analysis, runs core/CLI/app tests, and checks that `sudoku_core` line coverage reaches the default 90% threshold. For faster local feedback:

~~~powershell
pwsh -File tools/ci/run_gates.ps1 -SkipCoverage
~~~

> [!WARNING]
> `-SkipCoverage` is intended for quick local feedback and should not replace the complete delivery gate.

### Verification Performed for This README

| Scope | Command | Result |
|---|---|---:|
| `sudoku_core` | `dart test` | 255 passed |
| `sudoku_cli` | `dart test` | 51 passed |
| Flutter app | `flutter test` | 350 passed |
| Total | — | **656 passed** |

The core suite includes a 10,000-puzzle sanity fuzz test. This run triggered all 16 techniques and reported no invalid-elimination assertion. These results are a local verification snapshot from 2026-09-01, not the status of a connected continuous-integration service.

## Building Release Artifacts

On a Windows host configured with Flutter and the Windows/Android toolchains, run:

~~~powershell
pwsh ./scripts/build_release.ps1
~~~

The script:

1. builds the Windows Release application;
2. creates `dist/SudokuTutor-windows-x64/` and a portable ZIP;
3. builds the Android debug APK;
4. creates a Setup installer when Inno Setup 6 is available.

<details>
<summary>Build flags and artifact paths</summary>

| Flag | Effect |
|---|---|
| `-SkipWindows` | Skip the Windows build and portable package |
| `-SkipAndroid` | Skip the Android APK build |
| `-SkipInnoSetup` | Skip Setup creation even when ISCC is installed |

~~~text
dist/
├── SudokuTutor-windows-x64/
├── SudokuTutor-windows-x64.zip
└── Setup-SudokuTutor-0.1.0.exe       # 仅安装了 Inno Setup 时

app/build/app/outputs/flutter-apk/
└── app-debug.apk
~~~

</details>

See [`docs/10-T-PKG01-打包说明.md`](./docs/10-T-PKG01-打包说明.md) for the full packaging guide.

## Contributing

Keep the following layering rules intact:

| Rule | Constraint |
|---|---|
| R1 | `packages/sudoku_core/lib` may not use Flutter, `dart:ui`, or `dart:io` |
| R2 | `packages/sudoku_cli` may not use Flutter or `dart:ui` |
| R3 | `app/lib/core` may not use Flutter or `dart:ui` |
| R4 | `app/lib/domain` may not depend on the Widget layer or `app/lib/ui` |
| R5 | `sudoku_core` may not call `print` directly |
| R6 | No package may use relative imports to cross package boundaries |

Recommended workflow:

1. Work on an isolated branch.
2. When adding or changing a technique, update the detector, Chinese template, visual data, and positive/negative tests together.
3. Add a lesson as a JSON file and register it in the curriculum index without changing generic lesson logic.
4. Run `pwsh -File tools/ci/run_gates.ps1`.
5. Document behavior changes, test results, and any data-schema impact.

See [`docs/05-PRD基线.md`](./docs/05-PRD基线.md) and [`docs/06-架构设计.md`](./docs/06-架构设计.md) for the product and architecture baselines.

## Current Limitations

- [x] Unified engine with all 16 techniques in the T2 scope
- [x] 34 production lessons across Chapters 0–3
- [x] Five free-play banks and four chapter trial pools
- [x] Windows and Android build pipeline
- [x] Technique wiki, session resume, and offline challenge-code duels
- [ ] Final brand icon, display name, and launch assets still need replacement
- [ ] Windows code signing and Android production signing are not configured
- [ ] English teaching content is not yet available; the application interface supports Simplified Chinese and English

## License

This project is licensed under the [MIT License](./LICENSE).

Copyright (c) 2026 kaxaw
