/// T-EDU-01 · 课程 Provider 链路测试。
///
/// 覆盖：
/// - `curriculumRepositoryProvider` / `curriculumIndexProvider` 装配；
/// - `curriculumStateProvider` 把索引 + 存档进度装配成课程视图状态
///   （各章进度、解锁状态、关卡三态、星数）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_providers.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/domain/storage/models/level_progress.dart';
import 'package:sudoku_tutor/domain/storage/progress_repository.dart';

import '../../helpers/fake_progress_repository.dart';

/// 最小单关 JSON（id 可参数化）。
String _levelJson(String id, String title) => '{"schemaVersion":1,"id":"$id",'
    '"chapter":${id.substring(2, 3)},"order":1,"kind":"demo","title":"$title",'
    '"intro":"测试关。","techniqueTags":["nakedSingle"],'
    '"puzzle81":"...157....2.983.....5264..82...15...183..6...5968..71...1....6..6....3....8....52",'
    '"solution81":"839157246624983175715264938247315689183796524596842713351429867462578391978631452",'
    '"poolRef":null,"script":{"steps":[]}}';

/// 两章索引文本。
String _indexJson() => '{"schemaVersion":1,"chapters":['
    '{"chapter":0,"title":"第 0 章","techniqueTags":["nakedSingle"],'
    '"levels":[{"id":"ch0_l01","chapter":0,"order":1,"kind":"demo",'
    '"title":"唯一余数","techniqueTags":["nakedSingle"],"file":"ch0_l01.json"}]},'
    '{"chapter":1,"title":"第 1 章","techniqueTags":["xWing"],'
    '"levels":[{"id":"ch1_l01","chapter":1,"order":1,"kind":"demo",'
    '"title":"X 翼","techniqueTags":["xWing"],"file":"ch1_l01.json"}]}]}';

void main() {
  late ProviderContainer container;
  late FakeProgressRepository fakeRepo;

  setUp(() {
    final CurriculumRepository repo = CurriculumRepository(
      loader: (String path) async => switch (path) {
        'assets/curriculum/index.json' => _indexJson(),
        _ => _levelJson('ch0_l01', '唯一余数'),
      },
    );
    fakeRepo = FakeProgressRepository();
    container = ProviderContainer(
      overrides: <Override>[
        curriculumRepositoryProvider.overrideWithValue(repo),
        progressRepositoryProvider
            .overrideWith((Ref ref) async => fakeRepo as ProgressRepository),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('curriculumIndexProvider 解析课程索引', () async {
    final LevelIndex index =
        await container.read(curriculumIndexProvider.future);
    expect(index.chapters, hasLength(2));
    expect(index.byId('ch0_l01'), isNotNull);
  });

  test('curriculumStateProvider 装配：干净存档 → 全部关卡 unlocked', () async {
    final CurriculumState state =
        await container.read(curriculumStateProvider.future);
    expect(state.chapters, hasLength(2));
    expect(state.totalLevels, 2);
    expect(state.completedLevels, 0);
    expect(state.statusOf('ch0_l01'), LevelStatus.unlocked);
    expect(
      state.statusOf('ch1_l01'),
      LevelStatus.unlocked,
      reason: '后续章节无需前置通关即可选择',
    );
    expect(state.starsOf('ch0_l01'), 0);
  });

  test('完成 ch0 后：进度与星数更新，ch1 仍可进入', () async {
    await fakeRepo.updateLevel(
      const LevelProgress(
        levelId: 'ch0_l01',
        status: LevelStatus.completed,
        stars: 3,
      ),
    );
    final CurriculumState state =
        await container.read(curriculumStateProvider.future);
    expect(state.completedLevels, 1);
    expect(state.statusOf('ch0_l01'), LevelStatus.completed);
    expect(state.starsOf('ch0_l01'), 3);
    expect(state.statusOf('ch1_l01'), LevelStatus.unlocked);
    expect(state.chapterOf(0)!.progressLabel, '1/1');
  });
}
