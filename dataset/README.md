# dataset/ —— 题库与关卡数据集占位目录

本目录用于存放**批次 D（题库导出）与批次 F（34 关关卡）**产出的离线数据：

- `dataset/curriculum/` —— 章节/关卡定义（JSON，对应 `assets/curriculum/`）
- `dataset/puzzles/` —— 标注完成的题目库（对应 `assets/puzzles/`）
- `dataset/pools/` —— 按难度分桶的题源池（对应 `assets/pools/`）
- `dataset/text/` —— 讲解模板与文案（对应 `assets/text/`）

> ⚠️ 本目录在批次 A/B 阶段仅为占位；`app/pubspec.yaml` 的 `flutter.assets`
> 条目已注释，待本目录填充真实数据后再解除注释，否则 `flutter pub get` 会因目录缺失失败。
> 本目录不纳入版本控制的二进制资产，仅保留生成脚本与 schema。
