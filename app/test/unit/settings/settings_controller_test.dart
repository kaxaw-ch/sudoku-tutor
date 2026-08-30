/// T-UI-05 · 设置控制器测试（P0-STO-08 冻结清单读写）。
///
/// 覆盖：
/// - 读：从存档加载设置，默认值 = 冻结清单的默认配置；
/// - 冻结清单字段逐一存在且默认值正确（theme/boardTheme/sound/haptic/
///   autoCandidates/markErrors/showTimer/highlightSameDigit/hintQuota/language/
///   developerMode）；
/// - 写：任一项更新都走「载入 → 替换 → 落盘 → 发布」，存档确实变更；
/// - 不可变语义：更新一项后其它字段保持不变；
/// - 加载失败 → 状态进入 AsyncError。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/settings/settings_controller.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  group('默认值（冻结清单）', () {
    test('从空存档加载 = 冻结清单默认配置', () async {
      final FakeProgressRepository repo = FakeProgressRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
      );
      addTearDown(container.dispose);

      final SettingsState settings =
          await container.read(settingsControllerProvider.future);
      // 冻结清单逐项断言。
      expect(settings.theme, ThemeSlot.white, reason: '本期仅白色实现');
      expect(settings.boardTheme, BoardThemeStyle.green, reason: '棋盘默认绿色');
      expect(settings.soundOn, isFalse, reason: '音效默认关');
      expect(settings.hapticOn, isTrue, reason: '震动移动端默认开');
      expect(settings.autoCandidates, isFalse, reason: '自动候选默认关闭');
      expect(settings.markErrors, isTrue);
      expect(settings.showTimer, isTrue);
      expect(settings.highlightSameDigit, isTrue);
      expect(settings.hintQuota, HintQuota.unlimited, reason: '提示默认不限');
      expect(settings.language, 'zh', reason: '本期仅简体中文');
      expect(settings.developerMode, isFalse);
    });

    test('从预置存档加载：读存档而非默认', () async {
      final FakeProgressRepository repo = FakeProgressRepository(
        initial: const ProgressState(
          schemaVersion: 1,
          deviceId: 'fake-device',
          settings: SettingsState(
            soundOn: true,
            boardTheme: BoardThemeStyle.blue,
            hintQuota: HintQuota.three,
            markErrors: false,
          ),
        ),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
      );
      addTearDown(container.dispose);

      final SettingsState settings =
          await container.read(settingsControllerProvider.future);
      expect(settings.soundOn, isTrue);
      expect(settings.boardTheme, BoardThemeStyle.blue);
      expect(settings.hintQuota, HintQuota.three);
      expect(settings.markErrors, isFalse);
      expect(settings.hapticOn, isTrue, reason: '未覆盖字段保持默认');
    });
  });

  group('写入', () {
    late FakeProgressRepository repo;
    late ProviderContainer container;
    late SettingsController controller;

    setUp(() {
      repo = FakeProgressRepository();
      container = ProviderContainer(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
      );
      controller = container.read(settingsControllerProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('setSoundOn 落盘并发布新状态', () async {
      await controller.setSoundOn(true);
      expect(repo.current.settings.soundOn, isTrue, reason: '存档已变更');
      expect(
        container.read(settingsControllerProvider).valueOrNull?.soundOn,
        isTrue,
        reason: 'Riverpod 状态同步发布',
      );
    });

    test('setHintQuota 枚举写档', () async {
      await controller.setHintQuota(HintQuota.three);
      expect(repo.current.settings.hintQuota, HintQuota.three);
      await controller.setHintQuota(HintQuota.five);
      expect(repo.current.settings.hintQuota, HintQuota.five);
    });

    test('updateLevel 等设置项逐项可写且互不影响（不可变语义）', () async {
      await controller.setSoundOn(true);
      await controller.setMarkErrors(false);
      await controller.setHighlightSameDigit(false);
      await controller.setAutoCandidates(true);
      await controller.setTheme(ThemeSlot.pink);
      await controller.setBoardTheme(BoardThemeStyle.blue);
      await controller.setHapticOn(false);
      await controller.setShowTimer(false);
      await controller.enableDeveloperMode();

      final SettingsState s = repo.current.settings;
      expect(s.soundOn, isTrue);
      expect(s.markErrors, isFalse);
      expect(s.highlightSameDigit, isFalse);
      expect(s.autoCandidates, isTrue);
      expect(s.theme, ThemeSlot.pink);
      expect(s.boardTheme, BoardThemeStyle.blue);
      expect(s.hapticOn, isFalse);
      expect(s.showTimer, isFalse);
      expect(s.developerMode, isTrue, reason: '开发者模式一经开启不提供关闭');
      expect(s.hintQuota, HintQuota.unlimited, reason: '未更新的字段保持默认');
      expect(s.language, 'zh');
    });

    test('连续两次写同一字段：最后一次生效', () async {
      await controller.setSoundOn(true);
      await controller.setSoundOn(false);
      expect(repo.current.settings.soundOn, isFalse);
    });
  });

  group('加载失败', () {
    test('存档读取失败 → AsyncError，不抛到外部', () async {
      final FakeProgressRepository repo = FakeProgressRepository()
        ..failOnLoad = true;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          progressRepositoryProvider.overrideWith((Ref ref) async => repo),
        ],
      );
      addTearDown(container.dispose);

      // 首次读取即触发 build；build 内 load 抛 StateError → future 以 error 完成。
      final Future<SettingsState> future =
          container.read(settingsControllerProvider.future);
      await expectLater(future, throwsA(isA<StateError>()));
    });
  });
}
