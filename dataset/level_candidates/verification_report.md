# T-CNT-03 教学关候选盘面技巧验证报告

> 生成时间：2026-08-07T05:44:19.659486Z
> 来源：`packages/sudoku_cli` 的 `generate`+`export-level` 管线（T-CNT-03 / P0-CLI-07），并已通过 `verify --dataset dataset/level_candidates` 全量回放校验。

## 1. 总览

| 章 | 关数 | 候选数 | 目标技巧 | 逐关候选≥5 | 全部含目标技巧 | 指纹去重 | CLI verify |
|---|--:|--:|---|---|---|---|---|
| ch0 | 10 | 60 | 唯一余数、隐性唯一数、裸对、隐对、区块排除 | ✅ | ✅ | ✅ | 通过（回放校验） |
| ch1 | 7 | 42 | 裸三、隐三、X 翼 | ✅ | ✅ | ✅ | 通过（回放校验） |
| ch2 | 7 | 42 | 鳍形 X 翼（含 Sashimi）、剑鱼（标准） | ✅ | ✅ | ✅ | 通过（回放校验） |
| ch3 | 10 | 60 | XY 翼、XYZ 翼 | ✅ | ✅ | ✅ | 通过（回放校验） |
| **合计** | **34** | **204** | — | — | — | 全局唯一 204（重复 0） | — |

## 2. 逐关候选明细

> 每候选格式：`<编号>:<难度档>/<最高技巧><标记>(<脚本步数>步)`，标记 `★`=目标技巧为最高技巧（教学峰值明确）；`✓`=含目标技巧但非最高；`✗`=不含（不应出现）。

### ch0

| 关 | 类型 | 目标技巧 | 候选数 | 候选详情 |
|---|---|---|---|---|
| ch0_l01 | demo | 唯一余数 | 6 | 1:beginner/nakedSingle★(55步)<br/>2:beginner/nakedSingle★(55步)<br/>3:beginner/nakedSingle★(55步)<br/>4:beginner/nakedSingle★(55步)<br/>5:beginner/nakedSingle★(55步)<br/>6:beginner/nakedSingle★(55步) |
| ch0_l02 | demo | 隐性唯一数 | 6 | 1:beginner/hiddenSingle★(55步)<br/>2:beginner/hiddenSingle★(55步)<br/>3:beginner/hiddenSingle★(55步)<br/>4:beginner/hiddenSingle★(55步)<br/>5:beginner/hiddenSingle★(55步)<br/>6:beginner/hiddenSingle★(55步) |
| ch0_l03 | demo | 唯一余数 | 6 | 1:beginner/nakedSingle★(55步)<br/>2:beginner/nakedSingle★(55步)<br/>3:beginner/nakedSingle★(55步)<br/>4:beginner/nakedSingle★(55步)<br/>5:beginner/nakedSingle★(55步)<br/>6:beginner/nakedSingle★(55步) |
| ch0_l04 | demo | 隐性唯一数 | 6 | 1:beginner/hiddenSingle★(55步)<br/>2:beginner/hiddenSingle★(55步)<br/>3:beginner/hiddenSingle★(55步)<br/>4:beginner/hiddenSingle★(55步)<br/>5:beginner/hiddenSingle★(55步)<br/>6:beginner/hiddenSingle★(55步) |
| ch0_l05 | demo | 裸对 | 6 | 1:easy/nakedPair★(57步)<br/>2:easy/nakedPair★(56步)<br/>3:easy/nakedPair★(56步)<br/>4:easy/nakedPair★(57步)<br/>5:easy/nakedPair★(56步)<br/>6:easy/nakedPair★(56步) |
| ch0_l06 | guidedPractice | 裸对 | 6 | 1:easy/nakedPair★(56步)<br/>2:easy/nakedPair★(58步)<br/>3:easy/nakedPair★(57步)<br/>4:easy/nakedPair★(56步)<br/>5:easy/nakedPair★(56步)<br/>6:easy/nakedPair★(56步) |
| ch0_l07 | demo | 隐对 | 6 | 1:easy/hiddenPair★(62步)<br/>2:easy/hiddenPair★(56步)<br/>3:easy/hiddenPair★(59步)<br/>4:easy/hiddenPair★(57步)<br/>5:easy/hiddenPair★(56步)<br/>6:easy/hiddenPair★(57步) |
| ch0_l08 | guidedPractice | 隐对 | 6 | 1:easy/hiddenPair★(63步)<br/>2:easy/hiddenPair★(56步)<br/>3:easy/hiddenPair★(57步)<br/>4:easy/hiddenPair★(58步)<br/>5:easy/hiddenPair★(58步)<br/>6:easy/hiddenPair★(57步) |
| ch0_l09 | demo | 区块排除 | 6 | 1:easy/lockedCandidates★(59步)<br/>2:easy/lockedCandidates★(59步)<br/>3:easy/lockedCandidates★(60步)<br/>4:easy/lockedCandidates★(57步)<br/>5:easy/lockedCandidates★(57步)<br/>6:easy/lockedCandidates★(58步) |
| ch0_l10 | guidedPractice | 区块排除 | 6 | 1:easy/lockedCandidates★(58步)<br/>2:easy/lockedCandidates★(59步)<br/>3:easy/lockedCandidates★(56步)<br/>4:easy/lockedCandidates★(56步)<br/>5:easy/lockedCandidates★(57步)<br/>6:easy/lockedCandidates★(60步) |

### ch1

| 关 | 类型 | 目标技巧 | 候选数 | 候选详情 |
|---|---|---|---|---|
| ch1_l01 | demo | 裸三 | 6 | 1:medium/nakedTriple★(58步)<br/>2:medium/nakedTriple★(63步)<br/>3:medium/nakedTriple★(65步)<br/>4:medium/nakedTriple★(58步)<br/>5:medium/nakedTriple★(61步)<br/>6:medium/nakedTriple★(61步) |
| ch1_l02 | demo | 隐三 | 6 | 1:medium/hiddenTriple★(60步)<br/>2:medium/hiddenTriple★(60步)<br/>3:medium/hiddenTriple★(61步)<br/>4:medium/hiddenTriple★(63步)<br/>5:medium/hiddenTriple★(63步)<br/>6:medium/hiddenTriple★(61步) |
| ch1_l03 | guidedPractice | 裸三 | 6 | 1:medium/nakedTriple★(61步)<br/>2:medium/nakedTriple★(63步)<br/>3:medium/nakedTriple★(60步)<br/>4:medium/nakedTriple★(60步)<br/>5:medium/nakedTriple★(65步)<br/>6:medium/nakedTriple★(59步) |
| ch1_l04 | guidedPractice | 隐三 | 6 | 1:medium/hiddenTriple★(58步)<br/>2:medium/hiddenTriple★(60步)<br/>3:medium/hiddenTriple★(66步)<br/>4:medium/hiddenTriple★(63步)<br/>5:medium/hiddenTriple★(62步)<br/>6:medium/hiddenTriple★(59步) |
| ch1_l05 | demo | X 翼 | 6 | 1:medium/xWing★(62步)<br/>2:medium/xWing★(57步)<br/>3:medium/xWing★(58步)<br/>4:medium/xWing★(62步)<br/>5:medium/xWing★(61步)<br/>6:medium/xWing★(57步) |
| ch1_l06 | guidedPractice | X 翼 | 6 | 1:medium/xWing★(57步)<br/>2:medium/xWing★(58步)<br/>3:medium/xWing★(68步)<br/>4:medium/xWing★(59步)<br/>5:medium/xWing★(61步)<br/>6:medium/xWing★(58步) |
| ch1_l07 | trial | 裸三、隐三、X 翼 | 6 | 1:medium/hiddenTriple★(64步)<br/>2:medium/hiddenTriple★(62步)<br/>3:medium/hiddenTriple★(59步)<br/>4:medium/xWing★(60步)<br/>5:medium/xWing★(57步)<br/>6:medium/xWing★(60步) |

### ch2

| 关 | 类型 | 目标技巧 | 候选数 | 候选详情 |
|---|---|---|---|---|
| ch2_l01 | demo | 鳍形 X 翼（含 Sashimi） | 6 | 1:hard/finnedXWing★(57步)<br/>2:hard/finnedXWing★(57步)<br/>3:hard/finnedXWing★(58步)<br/>4:hard/finnedXWing★(59步)<br/>5:hard/finnedXWing★(62步)<br/>6:hard/finnedXWing★(62步) |
| ch2_l02 | demo | 剑鱼（标准） | 6 | 1:hard/swordfish★(62步)<br/>2:hard/swordfish★(59步)<br/>3:hard/swordfish★(61步)<br/>4:hard/swordfish★(63步)<br/>5:hard/swordfish★(61步)<br/>6:hard/swordfish★(65步) |
| ch2_l03 | guidedPractice | 鳍形 X 翼（含 Sashimi） | 6 | 1:hard/finnedXWing★(56步)<br/>2:hard/finnedXWing★(61步)<br/>3:hard/finnedXWing★(61步)<br/>4:hard/finnedXWing★(62步)<br/>5:hard/finnedXWing★(67步)<br/>6:hard/finnedXWing★(57步) |
| ch2_l04 | guidedPractice | 鳍形 X 翼（含 Sashimi） | 6 | 1:hard/finnedXWing★(64步)<br/>2:hard/finnedXWing★(58步)<br/>3:hard/finnedXWing★(57步)<br/>4:hard/finnedXWing★(64步)<br/>5:hard/finnedXWing★(63步)<br/>6:hard/finnedXWing★(60步) |
| ch2_l05 | guidedPractice | 剑鱼（标准） | 6 | 1:hard/swordfish★(59步)<br/>2:hard/swordfish★(59步)<br/>3:hard/swordfish★(59步)<br/>4:hard/swordfish★(62步)<br/>5:hard/swordfish★(62步)<br/>6:hard/swordfish★(58步) |
| ch2_l06 | guidedPractice | 剑鱼（标准） | 6 | 1:hard/swordfish★(70步)<br/>2:hard/swordfish★(58步)<br/>3:hard/swordfish★(61步)<br/>4:hard/swordfish★(62步)<br/>5:hard/swordfish★(60步)<br/>6:hard/swordfish★(62步) |
| ch2_l07 | trial | 鳍形 X 翼（含 Sashimi）、剑鱼（标准） | 6 | 1:hard/finnedXWing★(61步)<br/>2:hard/finnedXWing★(56步)<br/>3:hard/finnedXWing★(58步)<br/>4:hard/swordfish★(66步)<br/>5:hard/swordfish★(62步)<br/>6:hard/swordfish★(62步) |

### ch3

| 关 | 类型 | 目标技巧 | 候选数 | 候选详情 |
|---|---|---|---|---|
| ch3_l01 | demo | XY 翼 | 6 | 1:hard/xyWing★(61步)<br/>2:hard/xyWing★(61步)<br/>3:hard/xyWing★(60步)<br/>4:hard/xyWing★(64步)<br/>5:hard/xyWing★(57步)<br/>6:hard/xyWing★(56步) |
| ch3_l02 | demo | XY 翼 | 6 | 1:hard/xyWing★(60步)<br/>2:hard/xyWing★(57步)<br/>3:hard/xyWing★(56步)<br/>4:hard/xyWing★(63步)<br/>5:hard/xyWing★(57步)<br/>6:hard/xyWing★(60步) |
| ch3_l03 | demo | XYZ 翼 | 6 | 1:hard/xyzWing★(62步)<br/>2:hard/xyzWing★(69步)<br/>3:hard/xyzWing★(67步)<br/>4:hard/xyzWing★(56步)<br/>5:hard/xyzWing★(63步)<br/>6:hard/xyzWing★(62步) |
| ch3_l04 | guidedPractice | XY 翼 | 6 | 1:hard/xyWing★(57步)<br/>2:hard/xyWing★(60步)<br/>3:hard/xyWing★(65步)<br/>4:hard/xyWing★(65步)<br/>5:hard/xyWing★(64步)<br/>6:hard/xyWing★(69步) |
| ch3_l05 | guidedPractice | XY 翼 | 6 | 1:hard/xyWing★(61步)<br/>2:hard/xyWing★(56步)<br/>3:hard/xyWing★(59步)<br/>4:hard/xyWing★(59步)<br/>5:hard/xyWing★(58步)<br/>6:hard/xyWing★(59步) |
| ch3_l06 | guidedPractice | XY 翼 | 6 | 1:hard/xyWing★(59步)<br/>2:hard/xyWing★(57步)<br/>3:hard/xyWing★(66步)<br/>4:hard/xyWing★(61步)<br/>5:hard/xyWing★(71步)<br/>6:hard/xyWing★(58步) |
| ch3_l07 | guidedPractice | XYZ 翼 | 6 | 1:hard/xyzWing★(58步)<br/>2:hard/xyzWing★(63步)<br/>3:hard/xyzWing★(72步)<br/>4:hard/xyzWing★(63步)<br/>5:hard/xyzWing★(61步)<br/>6:hard/xyzWing★(57步) |
| ch3_l08 | guidedPractice | XYZ 翼 | 6 | 1:hard/xyzWing★(62步)<br/>2:hard/xyzWing★(60步)<br/>3:hard/xyzWing★(64步)<br/>4:hard/xyzWing★(57步)<br/>5:hard/xyzWing★(57步)<br/>6:hard/xyzWing★(66步) |
| ch3_l09 | guidedPractice | XYZ 翼 | 6 | 1:hard/xyzWing★(62步)<br/>2:hard/xyzWing★(64步)<br/>3:hard/xyzWing★(65步)<br/>4:hard/xyzWing★(67步)<br/>5:hard/xyzWing★(62步)<br/>6:hard/xyzWing★(61步) |
| ch3_l10 | trial | XY 翼、XYZ 翼 | 6 | 1:hard/xyWing★(60步)<br/>2:hard/xyWing★(61步)<br/>3:hard/xyWing★(57步)<br/>4:hard/xyzWing★(67步)<br/>5:hard/xyzWing★(67步)<br/>6:hard/xyzWing★(58步) |

## 3. 目标技巧命中与教学峰值

- 候选总数：204
- 含目标技巧的候选：204（100.0%）——目标技巧为最高技巧（★）：204（100.0%）。
- 无越章技巧：生成时 `--banned` 屏蔽高于本章范围的技巧（wWing / 唯一矩形 / 简单涂色等教学范围外技巧一律不出现），保证每个候选都可用「已学技巧」完整解出。

## 4. 生成参数摘要

- 每关候选数：6（34 关 × 6 = 204，全局指纹唯一 204）。
- 生成策略：每个目标技巧**单次** `generate --annotate --count 关数×6` 产出大集合（避免多关独立运行因有效盘面稀疏而扫到相同种子），再用 `tool/split_gen_collection.dart` 切成各关子集合，`export-level` 导出后重命名。
- 试炼关候选：ch1_l07=3 隐三+3 X翼、ch2_l07=3 鳍形 X 翼+3 剑鱼、ch3_l10=3 XY翼+3 XYZ翼，直接取自各技巧集合（保证全局去重）。
- 越章屏蔽：`--banned` 屏蔽高于本章范围的技巧（wWing / 唯一矩形 / 简单涂色等教学范围外技巧一律不出现），保证目标技巧为最高技巧且每个候选都可用「已学技巧」完整解出。
- 并发：`--concurrency 4`；低命中技巧加大 `--max-attempts`（swordfish 150000、xWing/hiddenTriple 100000 等，实测剑鱼在屏蔽后命中率约 0.02%）。
- 复现：每技巧固定 `--seed`（ch0=300000001…、ch1=310000001…、ch2=320000001…、ch3=330000001…），同参可复现。
