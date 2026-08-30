/// 数字口径常量与字符转换（架构文档 §7.1）。
///
/// 候选/填数一律 `1..9`；`0` 表示空格；位集内部用 `1 << (d - 1)`。
library;

import '../util/core_error.dart';

/// 最小合法数字。
const int kMinDigit = 1;

/// 最大合法数字。
const int kMaxDigit = 9;

/// 空格的数值表示。
const int kEmptyValue = 0;

/// 数字 1..9 的只读列表。
const List<int> kAllDigits = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9];

/// 81 字符串中表示空格的规范字符。
const String kEmptyChar = '.';

/// 数字相关的静态工具。
abstract final class Digit {
  /// 是否为合法数字 1..9。
  static bool isValid(int digit) => digit >= kMinDigit && digit <= kMaxDigit;

  /// 是否为合法单元格取值 0..9（0 = 空）。
  static bool isValidValue(int value) => value >= kEmptyValue && value <= kMaxDigit;

  /// 校验数字合法性，非法抛 `E_BOARD_005`。
  static void requireDigit(int digit) {
    if (!isValid(digit)) {
      throw CoreException(CoreErrorCode.boardIndexRange, 'digit=$digit 超出 1..9');
    }
  }

  /// 数值转字符：0 → `.`，1..9 → `'1'..'9'`。
  static String charOf(int value) => value == kEmptyValue ? kEmptyChar : '$value';

  /// 字符转数值：`.` / `0` / 空格 → 0，`'1'..'9'` → 1..9。
  ///
  /// 非法字符抛 `E_BOARD_002`。
  static int parseChar(String char) {
    if (char == kEmptyChar || char == '0' || char == ' ' || char == '_' || char == '*') {
      return kEmptyValue;
    }
    final int code = char.codeUnitAt(0);
    const int zero = 0x30; // '0'
    final int value = code - zero;
    if (value < kMinDigit || value > kMaxDigit) {
      throw CoreException(CoreErrorCode.boardStringChar, '非法字符「$char」');
    }
    return value;
  }
}
