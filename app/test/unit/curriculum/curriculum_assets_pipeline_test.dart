/// T-EDU-01 · 真实资产管线测试（app/assets/curriculum）。
///
/// 用 `TestWidgetsFlutterBinding` 的 rootBundle 读**真实打包资产**：
/// - `assets/curriculum/index.json` 经 [CurriculumRepository] 加载；
/// - 索引登记的最小测试关 `ch0_l01_test.json` 可解码为 [LessonLevel]。
///
/// 这验证「新增一关 = 加文件 + 登记一行」在真实资产链路上成立：
/// 只要文件在 assets 且 index 登记，App 即可加载该关（零逻辑改动）。
///
/// ⚠️ 依赖 pubspec 的 `assets/curriculum/` 声明（批次 F-2 已加）；
/// 由主理人在 `flutter test` 环境统一运行。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/curriculum/curriculum_repository.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('真实 assets：index.json 可加载且登记测试关', () async {
    final CurriculumRepository repo = CurriculumRepository();
    final LevelIndex index = await repo.loadIndex();

    expect(index.schemaVersion, kLevelIndexSchemaVersion);
    expect(index.allLevels, isNotEmpty, reason: 'index.json 应登记至少一个关卡');

    final LevelEntry? entry = index.byId('ch0_l01');
    expect(entry, isNotNull, reason: '测试关 ch0_l01 应在 index 登记');
  });

  test('真实 assets：登记的最小测试关可解码', () async {
    final CurriculumRepository repo = CurriculumRepository();
    final LessonLevel level = await repo.loadLevel('ch0_l01');

    expect(level.id, 'ch0_l01');
    expect(level.kind, LevelKind.demo);
    expect(level.givenCount, greaterThan(0));
    expect(level.hasScript, isTrue, reason: '演示关应携带解题脚本');
  });

  test('真实 assets：章入口可按章节号查询', () async {
    final CurriculumRepository repo = CurriculumRepository();
    final ChapterEntry? chapter = await repo.chapterEntry(0);
    expect(chapter, isNotNull);
    expect(chapter!.levels, isNotEmpty);
  });

  test('English：全部真实教程标题、简介与脚本步骤均可呈现英文', () async {
    final CurriculumRepository repo = CurriculumRepository();
    final LevelIndex index = await repo.loadIndex();
    const AppLocalizations english = AppLocalizations(Locale('en'));
    final RegExp han = RegExp(r'[\u3400-\u9fff]');
    int stepCount = 0;

    expect(index.allLevels.length, 34, reason: '正式课程应完整覆盖 34 关');
    for (final LevelEntry entry in index.allLevels) {
      final LessonLevel level = await repo.loadLevel(entry.id);
      final String title = english.lessonTitle(entry.id, entry.title);
      final String intro = english.lessonIntro(entry.id, level.intro);
      expect(title.trim(), isNotEmpty, reason: '${entry.id} 英文标题');
      expect(han.hasMatch(title), isFalse, reason: '${entry.id} 标题仍含中文');
      expect(intro.trim(), isNotEmpty, reason: '${entry.id} 英文简介');
      expect(han.hasMatch(intro), isFalse, reason: '${entry.id} 简介仍含中文');

      for (final ScriptStep step
          in level.script?.steps ?? const <ScriptStep>[]) {
        stepCount++;
        final String narration = english.scriptNarration(step, step.narration);
        expect(narration.trim(), isNotEmpty,
            reason: '${entry.id} #${step.order}');
        expect(
          han.hasMatch(narration),
          isFalse,
          reason: '${entry.id} #${step.order} 英文旁白仍含中文：$narration',
        );
      }
    }
    expect(stepCount, greaterThan(1000), reason: '应审计全部真实教程脚本，而非样例');
  });
}
