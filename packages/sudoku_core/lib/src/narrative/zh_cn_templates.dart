/// 16 项技巧的简体中文结论句模板表（doc 06 §6.5）。
///
/// **唯一文案源**：演示旁白、三级提示、CLI 标注报告全部走这张表，
/// 修改措辞只需改本文件；新增技巧须在此追加一条模板。
library;

import '../techniques/technique_id.dart';
import '../util/core_error.dart';
import 'narration_params.dart';
import 'narration_template.dart';

/// 16 项技巧的中文结论句模板。
const Map<TechniqueId, String> zhCnTemplates = <TechniqueId, String>{
  TechniqueId.nakedSingle:
      '{cellLabel} 的候选只剩下 {digit} 一个，因此这格只能填 {digit}。',
  TechniqueId.hiddenSingle:
      '{unitLabel} 中数字 {digit} 只能落在 {cellLabel} 这一格，因此这格填 {digit}。',
  TechniqueId.nakedPair:
      '{unitLabel} 的 {cellsLabel} 两格候选都恰好是 {pairDigits}，构成裸对；'
      '因此该单元其余格的 {pairDigits} 可以删除（{elimList}）。',
  TechniqueId.hiddenPair:
      '{unitLabel} 中数字 {pairDigits} 只出现在 {cellsLabel} 两格，构成隐对；'
      '因此这两格的其余候选可以删除（{elimList}）。',
  TechniqueId.lockedCandidates:
      '{unitLabel} 中数字 {digit} 的候选全部集中在 {cellsLabel}（{mode}）；'
      '因此 {targetUnitLabel} 中其余格的 {digit} 可以删除（{elimList}）。',
  TechniqueId.nakedTriple:
      '{unitLabel} 的 {cellsLabel} 三格候选都是 {tripleDigits} 的子集，构成裸三；'
      '因此该单元其余格的 {tripleDigits} 可以删除（{elimList}）。',
  TechniqueId.hiddenTriple:
      '{unitLabel} 中数字 {tripleDigits} 只出现在 {cellsLabel} 三格，构成隐三；'
      '因此这三格的其余候选可以删除（{elimList}）。',
  TechniqueId.xWing:
      '{baseUnits} 的候选 {digit} 都只落在 {coverUnits} 两{coverType}，构成 X 翼；'
      '因此 {coverUnits} 中其余格的 {digit} 可以删除（{elimList}）。',
  TechniqueId.finnedXWing:
      '{baseUnits} 的候选 {digit} 构成 X 翼，但 {finUnit} 多出一个鳍格 {finCell}；'
      '同时能看到 {oppositeCorner} 与 {finCell} 的 {elimList} 仍可删去 {digit}。',
  TechniqueId.swordfish:
      '{baseUnits} 的候选 {digit} 都只落在 {coverUnits} 三{coverType}，构成剑鱼；'
      '因此 {coverUnits} 中其余格的 {digit} 可以删除（{elimList}）。',
  TechniqueId.xyWing:
      '枢轴格 {pivotCell} 的候选是 {pivotDigits}，与夹翼格 {pincerCells} 构成 XY 翼；'
      '同时看到这两个夹翼格的 {elimList} 可以删去 {digit}。',
  TechniqueId.xyzWing:
      '枢轴格 {pivotCell} 的候选是 {pivotDigits}，与夹翼格 {pincerCells} 构成 XYZ 翼；'
      '同时看到枢轴格与两个夹翼格的 {elimList} 可以删去 {digit}。',
  TechniqueId.wWing:
      '{pairCells} 两格候选同为 {pairDigits}，{strongUnit} 中数字 {linkDigit} 的'
      '共轭对 {strongCells} 分别与它们相连，构成 W 翼；'
      '因此同时看到 {pairCells} 的 {elimList} 可以删去 {digit}。',
  TechniqueId.urType1:
      '{cellsLabel} 四格构成 2 行×2 列×2 宫且均非题面给定，'
      '若 {pairDigits} 互换仍成立将产生双解；因此 {extraCell} 的 {pairDigits} 必须删除。',
  TechniqueId.urType2:
      '{cellsLabel} 四格构成 2 行×2 列×2 宫且均非题面给定，'
      '{extraCells} 两格同时多出候选 {extraDigit}；为避免双解，'
      '同时看到这两格的 {elimList} 可以删去 {extraDigit}。',
  TechniqueId.simpleColouring:
      '对数字 {digit} 沿共轭对强链双色染色后，{ruleLabel} 成立（{colourCells}）；'
      '因此 {elimList} 可以删去 {digit}。',
};

/// 取 [id] 对应的中文模板；未登记抛 `E_TECH_003`。
///
/// [NarrationTemplate] 是仅持有一个字符串的轻量值对象，
/// 且占位符正则为类级静态常量，故此处不做缓存（§7.1 禁全局可变状态）。
NarrationTemplate zhCnTemplateOf(TechniqueId id) {
  final String? pattern = zhCnTemplates[id];
  if (pattern == null) {
    throw CoreException(CoreErrorCode.techNotRegistered, '中文模板表缺少 ${id.id}');
  }
  return NarrationTemplate(pattern);
}

/// 用中文模板渲染 [params]。
String renderZhCn(NarrationParams params) =>
    params.render(zhCnTemplateOf(params.techniqueId));
