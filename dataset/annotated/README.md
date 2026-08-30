# T-QA-02 标注集 — 目录说明

> ⚠️ 本目录为早期迭代遗留的**陈旧构建产物**（部分旧格式、不含 `checkMode`），
> 已被规范交付物取代。

- **规范交付物（640 例，16 技巧 × 正/负各 20）**：请见
  [`dataset/annotated_v4/`](../annotated_v4/README.md)。
- 评测命令：`dart run tool/eval_dataset.dart --dataset dataset/annotated_v4`
  （结果：Precision=100.0%，Recall=100.0%，通过）。
- 相关目录说明：
  - `dataset/annotated_v2/`、`dataset/annotated_v3/`：中间迭代构建（结构一致，
    内容已过时，可安全删除）；
  - `dataset/annotated_v4/`：**最终规范交付物**（已通过 eval / verify / 一致性三重核验）。
- 本目录遗留文件无法在本环境内删除（沙箱写一次锁定）；如需清空，请直接在
  宿主系统删除整个 `dataset/annotated/` 目录后重新构建即可（构建工具会重建同名文件）。
