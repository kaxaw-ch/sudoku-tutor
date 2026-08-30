# 音效资产说明（T-UI-06）

本目录为「3–5 个 CC0 音效素材」的**占位符**，当前均为最小占位文件，
实际音效素材（CC0 授权、单文件 <300KB、.ogg 格式）请在 P1 前替换：

- click.ogg     —— 落子/按钮点击
- success.ogg   —— 正确反馈（核对通过/完成）
- error.ogg     —— 错误反馈（冲突/核对出错）
- hint.ogg      —— 提示出牌
- toggle.ogg    —— 笔记/擦除等模式切换

替换方式：将真实 CC0 素材同名覆盖本目录文件，无需改动代码
（SoundService 按固定文件名加载）。素材来源建议：OpenGameArt / freesound
（须确认为 CC0 或 CC-BY 且注明出处）。

⚠️ 当前为占位符，且 `SettingsState.soundOn` 默认 `false`，
即使误开启，SoundService 也会对加载/播放失败做 no-op 降级，不影响交付。
