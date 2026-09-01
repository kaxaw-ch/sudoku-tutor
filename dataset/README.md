# dataset/ —— 离线题库生产与质量评测数据

本目录保存开发期数据；应用运行时资产位于 `app/assets/`，并已在
`app/pubspec.yaml` 中登记。当前有效内容如下：

- `annotated_v4/`：T-QA-02 规范标注集，16 项技巧各 20 个正例与 20 个负例，共 640 例；
- `level_candidates/`：34 个正式教学关卡的候选盘面与筛选报告；
- `gen_no_naked_single_pool.json`：唯一余数负例边界研究所用的可复现题源。

`annotated/`、`annotated_v2/` 与 `annotated_v3/` 是早期迭代产物，不被当前评测工具读取。
规范评测默认使用 `annotated_v4/`：

```powershell
cd packages/sudoku_cli
dart run tool/eval_dataset.dart
dart run tool/check_annotated_integrity.dart
dart run bin/sudoku_cli.dart verify --dataset dataset/annotated_v4
```

题库、课程和试炼池的最终运行时副本以 `app/assets/` 为准。
