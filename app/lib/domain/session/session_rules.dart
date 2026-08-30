/// 对局玩法规则（P0-PRA-05~07，T-DOM-04）。
///
/// 集中表达本游戏的交互规则，UI/控制器只调用这里暴露的判断方法，
/// 不内联业务口径：
/// - **自动候选数与手动笔记互斥**：切换自动候选时清空手动笔记
///   （[mustClearNotesOnAutoSwitch]，交互提示由 UI 层在事件回调中做）；
/// - **相同数字高亮两级**：已填同数=强高亮（实底）、候选同数=弱高亮
///   （加粗着色），由 [SameDigitHighlight] 表达；
/// - **错误标红**：只描边不填底（渲染口径在 BoardPainter，规则在此）。
library;

import 'package:sudoku_tutor/core/core.dart';

/// 相同数字高亮级别（P0-PRA-07 两级）。
enum SameDigitHighlight {
  /// 不参与高亮（该格没有命中目标数字）。
  none,

  /// 弱高亮：候选数含目标数字（加粗着色）。
  weakCandidate,

  /// 强高亮：已填数字等于目标数字（实底）。
  strongFilled,
}

/// 对局玩法规则（静态工具）。
abstract final class SessionRules {
  /// 自动候选数与手动笔记是否互斥（本项目恒为 true）。
  static const bool candidatesAndNotesExclusive = true;

  /// 切换自动候选时是否需要清空手动笔记。
  ///
  /// 从「手动笔记模式」切回「自动候选」时必须清空全部手动笔记
  /// （自动候选会全量重算，二者共用候选槽位，混用会产生歧义）。
  static bool mustClearNotesOnAutoSwitch({required bool noteMode}) =>
      noteMode && candidatesAndNotesExclusive;

  /// 判断格 [index] 相对目标数字 [digit] 的高亮级别。
  ///
  /// - 格值 == [digit]（已填同数）→ 强高亮；
  /// - 格为空格且候选含 [digit]（候选同数）→ 弱高亮；
  /// - 其余 → 无高亮。
  ///
  /// 参数为**纯数据**（值表 / 候选掩码表），供 UI 层渲染数据装配使用，
  /// 避免 UI 层直接 import core 的 `Board`。
  static SameDigitHighlight sameDigitLevel({
    required List<int> values,
    required List<int> candidateMasks,
    required int index,
    required int digit,
  }) {
    final int value = values[index];
    if (value == digit) {
      return SameDigitHighlight.strongFilled;
    }
    if (value == kEmptyValue &&
        (candidateMasks[index] & (1 << (digit - 1))) != 0) {
      return SameDigitHighlight.weakCandidate;
    }
    return SameDigitHighlight.none;
  }
}
