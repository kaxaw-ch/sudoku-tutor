# F-5 精选报告（T-CNT-04 + T-CNT-05）

> 生成批次：F-5（寇豆码 / Kou）｜生成时间：2026-08-08
> 说明：31 个非试炼关从 T-CNT-03 每关 6 个候选中精选 1 个；3 个试炼关从 T-CNT-02 题池抽取并用引擎重生成解题脚本。

## 一、34 关精选对齐总表

| 关 | 候选数 | 选定候选 | 目标技巧 | 最高技巧 | 步数 | kind |
|---|---|---|---|---|---|---|
| ch0_l01 | 6 | ch0_l01_candidate_1.json | basic | basic | 55 | demo |
| ch0_l02 | 6 | ch0_l02_candidate_1.json | basic | basic | 55 | demo |
| ch0_l03 | 6 | ch0_l03_candidate_1.json | basic | basic | 55 | demo |
| ch0_l04 | 6 | ch0_l04_candidate_1.json | basic | basic | 55 | demo |
| ch0_l05 | 6 | ch0_l05_candidate_2.json | nakedPair | nakedPair | 56 | demo |
| ch0_l06 | 6 | ch0_l06_candidate_1.json | nakedPair | nakedPair | 56 | guidedPractice |
| ch0_l07 | 6 | ch0_l07_candidate_2.json | hiddenPair | hiddenPair | 56 | demo |
| ch0_l08 | 6 | ch0_l08_candidate_2.json | hiddenPair | hiddenPair | 56 | guidedPractice |
| ch0_l09 | 6 | ch0_l09_candidate_4.json | lockedCandidates | lockedCandidates | 57 | demo |
| ch0_l10 | 6 | ch0_l10_candidate_3.json | lockedCandidates | lockedCandidates | 56 | guidedPractice |
| ch1_l01 | 6 | ch1_l01_candidate_1.json | nakedTriple | nakedTriple | 58 | demo |
| ch1_l02 | 6 | ch1_l02_candidate_1.json | hiddenTriple | hiddenTriple | 60 | demo |
| ch1_l03 | 6 | ch1_l03_candidate_6.json | nakedTriple | nakedTriple | 59 | guidedPractice |
| ch1_l04 | 6 | ch1_l04_candidate_1.json | hiddenTriple | hiddenTriple | 58 | guidedPractice |
| ch1_l05 | 6 | ch1_l05_candidate_2.json | xWing | xWing | 57 | demo |
| ch1_l06 | 6 | ch1_l06_candidate_1.json | xWing | xWing | 57 | guidedPractice |
| ch2_l01 | 6 | ch2_l01_candidate_1.json | finnedXWing | finnedXWing | 57 | demo |
| ch2_l02 | 6 | ch2_l02_candidate_2.json | swordfish | swordfish | 59 | demo |
| ch2_l03 | 6 | ch2_l03_candidate_1.json | finnedXWing | finnedXWing | 56 | guidedPractice |
| ch2_l04 | 6 | ch2_l04_candidate_3.json | finnedXWing | finnedXWing | 57 | guidedPractice |
| ch2_l05 | 6 | ch2_l05_candidate_6.json | swordfish | swordfish | 58 | guidedPractice |
| ch2_l06 | 6 | ch2_l06_candidate_2.json | swordfish | swordfish | 58 | guidedPractice |
| ch3_l01 | 6 | ch3_l01_candidate_6.json | xyWing | xyWing | 56 | demo |
| ch3_l02 | 6 | ch3_l02_candidate_3.json | xyWing | xyWing | 56 | demo |
| ch3_l03 | 6 | ch3_l03_candidate_4.json | xyzWing | xyzWing | 56 | demo |
| ch3_l04 | 6 | ch3_l04_candidate_1.json | xyWing | xyWing | 57 | guidedPractice |
| ch3_l05 | 6 | ch3_l05_candidate_2.json | xyWing | xyWing | 56 | guidedPractice |
| ch3_l06 | 6 | ch3_l06_candidate_2.json | xyWing | xyWing | 57 | guidedPractice |
| ch3_l07 | 6 | ch3_l07_candidate_6.json | xyzWing | xyzWing | 57 | guidedPractice |
| ch3_l08 | 6 | ch3_l08_candidate_4.json | xyzWing | xyzWing | 57 | guidedPractice |
| ch3_l09 | 6 | ch3_l09_candidate_6.json | xyzWing | xyzWing | 61 | guidedPractice |
| ch1_l07 | 6 | pools/ch1.json.gz(seed=330092) | xWing | xWing | 56 | trial |
| ch2_l07 | 6 | pools/ch2.json.gz(seed=140092) | finnedXWing | finnedXWing | 58 | trial |
| ch3_l10 | 6 | pools/ch3.json.gz(seed=150232) | xyzWing | xyzWing | 57 | trial |

## 二、三处 kind 与 PRD 预期差异说明（以候选现有 kind 为准）

1. `ch0_l03` / `ch0_l04`：PRD 期望「唯一余数/隐性唯一数」为实操（guidedPractice），但 T-CNT-03 候选全部生成为 demo；按任务指示以候选现有 kind 为准，两关均为 demo。
2. `ch1_l05`：PRD 期望为 X 翼实操，但候选全部为 demo；以候选为准，本关为 demo。（第 1 章因此为 3 演示 + 3 实操 + 1 试炼。）
3. `ch1_l07` / `ch2_l07` / `ch3_l10`：候选盘面 kind 为 guidedPractice，但任务要求这三关为试炼关（trial）；不采用候选盘面，改从对应章节题池抽取。

## 三、步数说明

所有候选脚本为 T-CNT-03 生成的完整解题脚本（55~72 步），为保证 ScriptReplayer 终态校验通过（脚本须解满整盘），**未做截断**；各关已在候选中优先选取步数较短者。「优先步数适中（10~30 步）」在候选产物约束下无法满足，已向主理人报告。

## 四、试炼关来源

| 关 | 池文件 | 池内 seed | 目标技巧 | 生成脚本步数 |
|---|---|---|---|---|
| ch1_l07 | pools/ch1.json.gz | 330092 | xWing | 56 |
| ch2_l07 | pools/ch2.json.gz | 140092 | finnedXWing | 58 |
| ch3_l10 | pools/ch3.json.gz | 150232 | xyzWing | 57 |

## 五、产出文件

- 非试炼关：`app/assets/curriculum/ch0_l01.json` ~ `ch3_l09.json`（31 个）
- 试炼关：`app/assets/curriculum/ch1_l07.json` / `ch2_l07.json` / `ch3_l10.json`
- 课程索引：`app/assets/curriculum/index.json`（登记 34 关，`ch0_l01_test` 不再引用）
- 校验脚本：`app/tool/verify_curriculum.dart`
