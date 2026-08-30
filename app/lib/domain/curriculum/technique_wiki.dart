/// 数独技巧百科的中文定义与使用说明。
library;

import 'package:sudoku_tutor/core/core.dart';

/// 一条技巧百科内容。
class TechniqueWikiEntry {
  /// 构造百科条目。
  const TechniqueWikiEntry({
    required this.id,
    required this.definition,
    required this.usage,
    required this.tip,
  });

  /// 对应算法层技巧标识。
  final TechniqueId id;

  /// 技巧的判定条件。
  final String definition;

  /// 在盘面上的查找与使用方法。
  final String usage;

  /// 容易误判的边界条件。
  final String tip;

  /// 引擎难度档。
  Difficulty get difficulty => TechniqueRank.difficultyOf(id);

  /// 引擎求解顺序（1 起）。
  int get rank => TechniqueRank.of(id) ~/ 10;
}

/// 全部技巧，顺序与引擎求解 rank 一致。
const List<TechniqueWikiEntry> techniqueWikiEntries = <TechniqueWikiEntry>[
  TechniqueWikiEntry(
    id: TechniqueId.nakedSingle,
    definition: '某个空格排除同行、同列和同宫已有数字后，只剩一个合法候选数。',
    usage: '先补全候选数，寻找只有一个候选的格子，直接把该候选填入，再更新相关行、列、宫。',
    tip: '判断依据是“这个格只剩一个候选”，不要与某个数字在一个单元中只剩一个位置混淆。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.hiddenSingle,
    definition: '在某一行、列或宫中，某个数字虽然藏在多候选格里，但只有一个格子能够放置它。',
    usage: '按数字逐个扫描每个单元；若一个数字只在一个空格的候选中出现，就把它填入该格。',
    tip: '目标格自身可能有多个候选，关键是该数字在整个单元中只有这一个位置。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.nakedPair,
    definition: '同一行、列或宫内，两格的候选都恰好是相同的两个数字，这两个数字必定占据这两格。',
    usage: '找到相同的双候选格后，从该单元其他空格中删除这两个候选。',
    tip: '两格都必须恰好只有这两个候选，并且处在同一个要执行删数的单元中。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.hiddenPair,
    definition: '同一单元中，两个数字都只出现在相同的两格里，即使这两格还带有其他候选，它们也只能承载这两个数字。',
    usage: '按候选数字的位置扫描单元，找到共享同两格的两个数字，删除这两格中的其他候选。',
    tip: '看的是“两个数字只出现于两格”，不是两格当前的候选集合完全相同。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.lockedCandidates,
    definition: '某数字在一个宫内的候选全部落在同一行或列，或在一行/列内的候选全部落在同一宫。',
    usage: '宫内集中时，从同一行或列的宫外格删除该候选；行列内集中时，从交叉宫的其他格删除该候选。',
    tip: '先确认目标数字在来源单元中的所有候选都被交叉单元锁定，不能遗漏第三个位置。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.nakedTriple,
    definition: '同一单元的三格候选并集恰好只有三个数字，且每格候选都是这三个数字的子集。',
    usage: '锁定这三格后，从该单元其余空格中删除这三个候选。',
    tip: '三格不必拥有完全相同的候选，但候选并集必须恰好为三个数字。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.hiddenTriple,
    definition: '同一单元中，三个数字只分布在相同的三格内，这三格必定由它们占据。',
    usage: '找到仅覆盖三格的三个数字，删除这三格中不属于该三数组合的其他候选。',
    tip: '应按数字的出现位置判断；三格原本可以各自含有更多候选。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.xWing,
    definition: '某数字在两行中都恰好只出现在相同的两列，四个候选形成矩形；行列角色也可以互换。',
    usage: '以两行为基底时，从那两列的其他行删除该候选；以两列为基底时反向操作。',
    tip: '两个基底单元都必须恰好有两个候选位置，而且覆盖单元必须完全一致。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.finnedXWing,
    definition: '近似 X 翼的结构中，一个基底单元多出位于同宫的“鳍”候选，使删数范围被限制在鳍所在宫。',
    usage: '先定位主体 X 翼与鳍，再从同时受对角主体候选和鳍约束的宫内格删除目标候选。',
    tip: '不能像标准 X 翼一样整列或整行删除；被删格必须落在鳍的宫内并满足双重可见。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.swordfish,
    definition: '某数字在三行中的候选总共只落在相同的三列，形成三阶鱼；行列角色可以互换。',
    usage: '以三行为基底时，从三条覆盖列的其他行删除该候选；列基底时反向操作。',
    tip: '每个基底单元通常有二至三个候选，三者的覆盖位置并集必须恰好是三个单元。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.xyWing,
    definition: '一个双候选枢轴 XY 分别看到双候选夹翼 XZ 与 YZ，两个夹翼共享候选 Z。',
    usage: '从所有同时能看到两个夹翼的格子中删除候选 Z。',
    tip: '两个夹翼不必互相可见，但都必须看到枢轴；枢轴和夹翼都应是双候选格。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.xyzWing,
    definition: '三候选枢轴 XYZ 同时看到夹翼 XZ 与 YZ，三格都共享候选 Z。',
    usage: '从同时能看到枢轴和两个夹翼的格子中删除候选 Z。',
    tip: '被删格必须同时看到三格；只看到两个夹翼但看不到枢轴时不能删除。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.wWing,
    definition: '两个互相不必可见的相同双候选格 XY，通过数字 X 的共轭对强链连接，使两端至少有一个取 Y。',
    usage: '确认强链两端分别能看到两个双候选格后，从同时看到这两个双候选格的位置删除候选 Y。',
    tip: '连接数字必须形成真正的共轭对，也就是所在单元中该数字恰好只有两个候选位置。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.urType1,
    definition: '四个非给定格构成跨两行、两列和两个宫的唯一矩形；其中三格只有候选 AB，第四格还有额外候选。',
    usage: '为避免 AB 在矩形中互换产生双解，从第四格删除候选 A 和 B，保留其额外候选。',
    tip: '唯一矩形依赖题目唯一解前提，且四格必须分布在恰好两个宫内，给定数字不能作为矩形角。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.urType2,
    definition: '唯一矩形中，同一侧的两个角除共同候选 AB 外，还共享同一个额外候选 C。',
    usage: '为避免形成可交换的双解结构，从所有同时看到这两个额外候选格的位置删除候选 C。',
    tip: '两个角的额外候选必须是同一个数字，被删格也必须同时看到这两个角。',
  ),
  TechniqueWikiEntry(
    id: TechniqueId.simpleColouring,
    definition: '针对同一数字，沿共轭对强链交替使用两种颜色，所有同色节点代表同一真假状态。',
    usage: '若同色节点互相冲突，删除该颜色全部候选；若链外候选同时看到两种颜色，则删除该链外候选。',
    tip: '连线只能来自共轭对强链；不同颜色只是逻辑标记，并不预先代表真或假。',
  ),
];
