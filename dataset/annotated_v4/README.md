# T-QA-02 标注盘面集（Precision/Recall 评测）

> 交付物：本目录（`dataset/annotated_v4/`）——16 项技巧 × 20 正例 + 20 负例 = **640 例**。
> 结构：`<techniqueId>/{positive,negative}/<techniqueId>_<label>_<NNN>.json`。
>
> ⚠️ **为什么不是 `dataset/annotated`**：本环境（Windows 沙箱）对先前操作创建的
> 文件实行「写一次锁定」——无法删除/覆写 `dataset/annotated` 下早期迭代的遗留文件，
> 因此规范交付物落在全新目录 `dataset/annotated_v4/`（结构完全一致）。早期遗留目录
> 中的文件请人工清理后即可复用原名。

## 1. 规模

| 技巧 | 正例 | 负例 |
|---|--:|--:|
| 16 项（nakedSingle … simpleColouring） | 各 20 | 各 20 |
| **合计** | **320** | **320**（总计 **640**） |

每例 JSON 字段：

- `puzzle81`：题面 81 串（空格用 `.`）；`solution81`：终局解 81 串；
- `techniqueId` / `label`（`positive` / `negative`）；
- `checkMode`：`solve`（逐级求解全程）或 `initial`（初始盘面状态直接扫描）；
- `seed` / `source`：来源与可复现种子；`note`：构造说明（人工可核验）；
- `expected`（仅正例）：t2 求解中目标技巧首步的删数/填数结论（供评测核对）。

## 2. 构造方法与口径

**统一底座**：所有候选均来自既有产物——`app/assets/pools/ch0..3.json.gz`、
`app/assets/puzzles/*.json.gz`（五档自由题库）、`dataset/level_candidates/ch0..3/`
（204 个教学关候选）。每个候选在 **t2（16 项全量规则集）** 下用
`annotateOne`（100% 复用 `sudoku_core`）重新逐级标注，然后按技巧切分。

### positive（320 例，各技巧 20）

- 判定口径：t2 求解中该技巧被识别器**实际触发**（`usedTechniques` 含目标）；
- 素材优先级：教学关候选 > 题池 > 自由题库；同构指纹去重；
- `expected` 记录求解脚本中目标技巧**首步**的结论，评测时核对识别器确实产出该结论。

### negative（320 例，各技巧 20）

- **其余 15 项技巧**：判定口径 = t2 求解中该技巧**全程未触发**（强负例）；
  选取优先「近失/易混淆」盘面——最高技巧 rank 距目标最近、或使用了同家族
  相关技巧（如含 xWing 的剑鱼负例、含 xyWing 的 xyzWing 负例、含 wWing 的
  唯一矩形负例），从而覆盖「退化形态 / 仅差一步不成 / 其它技巧伪装」。
- **nakedSingle 特例（数学边界）**：任何完整求解的**收尾步必然出现唯一余数**
  ——最后剩一格时该格恰剩 1 个候选，识别器必命中。故「不含裸单」只能在
  **初始盘面状态**定义：选取初始盘面无任何单候选格的题（`checkMode=initial`）。
  其 `note` 中已注明这一数学事实。
- 同一题面不得同时充当同一技巧的正例与负例（指纹互斥）。

## 3. 评测口径（`tool/eval_dataset.dart`）

- **positive**：按 `solve` 判定——重新 t2 求解，目标技巧 ∈ `usedTechniques`
  且 `expected` 结论被对应技巧步骤确认 → **TP**；未触发 → **FN**；
  触发但结论不符 → **结论错误**（precision/recall 双失败）。
- **negative**：按 `checkMode` 判定——`solve` 模式重新求解不得触发；
  `initial` 模式识别器在初始盘面直接扫描不得命中；命中 → **FP**。
- **Precision = TP/(TP+FP+结论错)**，零容忍 100%；**Recall = TP/(TP+FN+结论错)**，≥95%。
- 评测算法 100% 复用 `sudoku_core`，本工具零算法实现。

## 4. 评测结果（2026-08-07）

- `dart run tool/eval_dataset.dart --dataset dataset/annotated_v4`：
  **Precision = 100.0%**（每技巧 100%，0 误报 / 0 结论错）、**Recall = 100.0%**
  （每技巧 100%，0 漏报）、异常 0 → **通过 ✅**。
- 独立结构校验 `dart run bin/sudoku_cli.dart verify --dataset dataset/annotated_v4`：
  640 文件、不一致 0（唯一解 + 终局解一致性）✅。
- 独立一致性 `dart run tool/check_annotated_integrity.dart dataset/annotated_v4`：
  640 例、326 个唯一指纹、0 解析失败、0 同格重复、0 正负冲突 ✅。

## 5. 复现命令

```bash
# 1) 重新构建标注集（来源可追加 pool.json 等）
cd packages/sudoku_cli
dart run tool/build_annotated_dataset.dart \
  --out dataset/annotated_v4 --per-tech 20 \
  app/assets/pools/ch0..3.json.gz app/assets/puzzles/*.json.gz \
  dataset/level_candidates/ch0..3

# 2) 评测（Precision/Recall）
dart run tool/eval_dataset.dart --dataset dataset/annotated_v4

# 3) 独立结构校验 / 一致性校验
dart run bin/sudoku_cli.dart verify --dataset dataset/annotated_v4
dart run tool/check_annotated_integrity.dart dataset/annotated_v4
```

> 注：`build_annotated_dataset.dart` 默认写确定性文件名并输出 `manifest.json`
> （`--manifest` 可选）。目录中存在无法清理的陈旧文件时，评测器优先读
> `manifest.json` 权威清单；干净目录（如本交付物）直接全量扫描即可。
