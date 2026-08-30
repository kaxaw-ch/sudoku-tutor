/// 设置模型序列化与旧存档兼容测试。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

void main() {
  test('棋盘主题参与 JSON 往返', () {
    const SettingsState source = SettingsState(
      boardTheme: BoardThemeStyle.blue,
    );

    final SettingsState restored = SettingsState.fromJson(source.toJson());

    expect(source.toJson()['boardTheme'], 'blue');
    expect(restored.boardTheme, BoardThemeStyle.blue);
  });

  test('旧存档没有棋盘主题或值未知时回退绿色', () {
    final Map<String, Object?> legacy = const SettingsState().toJson()
      ..remove('boardTheme');
    expect(
      SettingsState.fromJson(legacy).boardTheme,
      BoardThemeStyle.green,
    );

    final Map<String, Object?> unknown = const SettingsState().toJson()
      ..['boardTheme'] = 'unknown';
    expect(
      SettingsState.fromJson(unknown).boardTheme,
      BoardThemeStyle.green,
    );

    final Map<String, Object?> invalidType = const SettingsState().toJson()
      ..['boardTheme'] = 42;
    expect(
      SettingsState.fromJson(invalidType).boardTheme,
      BoardThemeStyle.green,
    );
  });
}
