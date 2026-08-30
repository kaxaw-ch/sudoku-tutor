/// 应用根棋盘主题下发测试。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/app.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/settings/settings_controller.dart';
import 'package:sudoku_tutor/domain/storage/models/progress_state.dart';
import 'package:sudoku_tutor/domain/storage/models/settings_models.dart';
import 'package:sudoku_tutor/ui/theme/game_palette.dart';

import '../../helpers/fake_progress_repository.dart';

void main() {
  testWidgets('存档主题由应用根下发，切换后已挂载页面即时更新', (WidgetTester tester) async {
    final FakeProgressRepository repo = FakeProgressRepository(
      initial: const ProgressState(
        schemaVersion: 1,
        deviceId: 'fake-device',
        settings: SettingsState(boardTheme: BoardThemeStyle.blue),
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        progressRepositoryProvider.overrideWith((Ref ref) async => repo),
      ],
    );
    addTearDown(container.dispose);

    BoardPalette? renderedPalette;
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) => Builder(
            builder: (BuildContext context) {
              renderedPalette = Theme.of(context).extension<BoardPalette>();
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: SudokuTutorApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderedPalette, GamePalette.blueBoard);

    await container
        .read(settingsControllerProvider.notifier)
        .setBoardTheme(BoardThemeStyle.green);
    await tester.pumpAndSettle();

    expect(renderedPalette, GamePalette.greenBoard);
    expect(repo.current.settings.boardTheme, BoardThemeStyle.green);
  });
}
