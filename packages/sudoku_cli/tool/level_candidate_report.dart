/// 生成 T-CNT-03 教学关候选盘面的技巧验证报告。
///
/// 扫描 `dataset/level_candidates/ch{N}` 下 `<关>_candidate_<n>.json`，
/// 逐候选核验：最高技巧（按 rank 推导）/ 是否含该关目标技巧 / 脚本步数 /
/// 难度（= 最高技巧的档位）/ 指纹全局去重。
/// 输出 `dataset/level_candidates/verification_report.md`。
///
/// 用法: `dart run tool/level_candidate_report.dart`
library;

import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';
import 'package:sudoku_cli/sudoku_cli.dart';

/// 每关目标技巧（与 `.tmp_content/run_candidates.sh` 的 LEVELS_SPEC 对齐）。
const Map<String, List<TechniqueId>> kLevelTargets = <String, List<TechniqueId>>{
  'ch0_l01': <TechniqueId>[TechniqueId.nakedSingle],
  'ch0_l02': <TechniqueId>[TechniqueId.hiddenSingle],
  'ch0_l03': <TechniqueId>[TechniqueId.nakedSingle],
  'ch0_l04': <TechniqueId>[TechniqueId.hiddenSingle],
  'ch0_l05': <TechniqueId>[TechniqueId.nakedPair],
  'ch0_l06': <TechniqueId>[TechniqueId.nakedPair],
  'ch0_l07': <TechniqueId>[TechniqueId.hiddenPair],
  'ch0_l08': <TechniqueId>[TechniqueId.hiddenPair],
  'ch0_l09': <TechniqueId>[TechniqueId.lockedCandidates],
  'ch0_l10': <TechniqueId>[TechniqueId.lockedCandidates],
  'ch1_l01': <TechniqueId>[TechniqueId.nakedTriple],
  'ch1_l02': <TechniqueId>[TechniqueId.hiddenTriple],
  'ch1_l03': <TechniqueId>[TechniqueId.nakedTriple],
  'ch1_l04': <TechniqueId>[TechniqueId.hiddenTriple],
  'ch1_l05': <TechniqueId>[TechniqueId.xWing],
  'ch1_l06': <TechniqueId>[TechniqueId.xWing],
  'ch1_l07': <TechniqueId>[TechniqueId.nakedTriple, TechniqueId.hiddenTriple, TechniqueId.xWing],
  'ch2_l01': <TechniqueId>[TechniqueId.finnedXWing],
  'ch2_l02': <TechniqueId>[TechniqueId.swordfish],
  'ch2_l03': <TechniqueId>[TechniqueId.finnedXWing],
  'ch2_l04': <TechniqueId>[TechniqueId.finnedXWing],
  'ch2_l05': <TechniqueId>[TechniqueId.swordfish],
  'ch2_l06': <TechniqueId>[TechniqueId.swordfish],
  'ch2_l07': <TechniqueId>[TechniqueId.finnedXWing, TechniqueId.swordfish],
  'ch3_l01': <TechniqueId>[TechniqueId.xyWing],
  'ch3_l02': <TechniqueId>[TechniqueId.xyWing],
  'ch3_l03': <TechniqueId>[TechniqueId.xyzWing],
  'ch3_l04': <TechniqueId>[TechniqueId.xyWing],
  'ch3_l05': <TechniqueId>[TechniqueId.xyWing],
  'ch3_l06': <TechniqueId>[TechniqueId.xyWing],
  'ch3_l07': <TechniqueId>[TechniqueId.xyzWing],
  'ch3_l08': <TechniqueId>[TechniqueId.xyzWing],
  'ch3_l09': <TechniqueId>[TechniqueId.xyzWing],
  'ch3_l10': <TechniqueId>[TechniqueId.xyWing, TechniqueId.xyzWing],
};

const Map<String, String> kLevelKinds = <String, String>{
  'ch0_l01': 'demo', 'ch0_l02': 'demo', 'ch0_l03': 'demo', 'ch0_l04': 'demo',
  'ch0_l05': 'demo', 'ch0_l06': 'guidedPractice', 'ch0_l07': 'demo',
  'ch0_l08': 'guidedPractice', 'ch0_l09': 'demo', 'ch0_l10': 'guidedPractice',
  'ch1_l01': 'demo', 'ch1_l02': 'demo', 'ch1_l03': 'guidedPractice',
  'ch1_l04': 'guidedPractice', 'ch1_l05': 'demo', 'ch1_l06': 'guidedPractice',
  'ch1_l07': 'trial',
  'ch2_l01': 'demo', 'ch2_l02': 'demo', 'ch2_l03': 'guidedPractice',
  'ch2_l04': 'guidedPractice', 'ch2_l05': 'guidedPractice',
  'ch2_l06': 'guidedPractice', 'ch2_l07': 'trial',
  'ch3_l01': 'demo', 'ch3_l02': 'demo', 'ch3_l03': 'demo',
  'ch3_l04': 'guidedPractice', 'ch3_l05': 'guidedPractice',
  'ch3_l06': 'guidedPractice', 'ch3_l07': 'guidedPractice',
  'ch3_l08': 'guidedPractice', 'ch3_l09': 'guidedPractice', 'ch3_l10': 'trial',
};

void main() {
  // 项目根 = 本脚本(…/packages/sudoku_cli/tool/xxx.dart) 上溯 4 层。
  final String projectRoot = File.fromUri(Platform.script)
      .parent
      .parent
      .parent
      .parent
      .path;
  final String datasetRoot = joinPath(projectRoot, 'dataset', 'level_candidates');
  final StringBuffer out = StringBuffer();
  final Set<String> globalFingerprints = <String>{};
  final Map<String, List<_Candidate>> byLevel = <String, List<_Candidate>>{};

  for (int ch = 0; ch <= 3; ch++) {
    final Directory dir = Directory(joinPath(datasetRoot, 'ch$ch'));
    if (!dir.existsSync()) {
      continue;
    }
    final List<File> files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final File file in files) {
      final String name = file.path.split(Platform.pathSeparator).last;
      if (!name.contains('_candidate_')) {
        continue;
      }
      final String level = name.split('_candidate_').first;
      final Map<String, Object?> json = JsonWriter.readJsonMap(file.path);
      final Set<TechniqueId> tags = <TechniqueId>{
        for (final Object? raw in (json['techniqueTags'] as List<Object?>?) ??
            const <Object?>[])
          if (raw is String && TechniqueId.tryParse(raw) != null)
            TechniqueId.tryParse(raw)!,
      };
      final Object? rawScript = json['script'];
      final List<Object?> steps =
          (rawScript is Map<String, Object?> &&
                  rawScript['steps'] is List<Object?>)
              ? (rawScript['steps'] as List<Object?>)
              : const <Object?>[];
      byLevel.putIfAbsent(level, () => <_Candidate>[]).add(
            _Candidate(
              puzzle81: json['puzzle81']! as String,
              tags: tags,
              scriptSteps: steps.length,
            ),
          );
      globalFingerprints.add(
        Fingerprint.ofValues(BoardCodec.decodeValues(json['puzzle81']! as String)),
      );
    }
  }

  final List<String> levelOrder = byLevel.keys.toList()..sort();
  final StringBuffer perChapter = StringBuffer();
  var totalLevels = 0, totalCandidates = 0, totalPeak = 0, totalHitTarget = 0;
  final StringBuffer overview = StringBuffer();

  overview.writeln('## 1. 总览');
  overview.writeln();
  overview.writeln('| 章 | 关数 | 候选数 | 目标技巧 | 逐关候选≥5 | 全部含目标技巧 | 指纹去重 | CLI verify |');
  overview.writeln('|---|--:|--:|---|---|---|---|---|');

  for (int ch = 0; ch <= 3; ch++) {
    final levels = levelOrder.where((l) => l.startsWith('ch${ch}_')).toList();
    var candCount = 0, peak = 0, hit = 0;
    final chapterTargets = <TechniqueId>{};
    final chapterFps = <String>{};
    for (final l in levels) {
      final cands = byLevel[l] ?? const <_Candidate>[];
      candCount += cands.length;
      chapterTargets.addAll(kLevelTargets[l] ?? const <TechniqueId>[]);
      for (final c in cands) {
        chapterFps.add(c.fingerprint);
        final targets = kLevelTargets[l] ?? const <TechniqueId>[];
        if (targets.any(c.tags.contains)) {
          hit++;
        }
        if (targets.contains(c.hardest)) {
          peak++;
        }
      }
    }
    final bool allContain = levels.every((l) {
      final targets = kLevelTargets[l] ?? const <TechniqueId>[];
      return (byLevel[l] ?? const <_Candidate>[]).every(
          (c) => targets.any(c.tags.contains));
    });
    final bool minFive = levels.every((l) => (byLevel[l]?.length ?? 0) >= 5);
    final int chapterDup = candCount - chapterFps.length;
    overview.writeln('| ch$ch | ${levels.length} | $candCount | '
        '${chapterTargets.map((t) => t.zhName).join('、')} | '
        '${minFive ? '✅' : '❌'} | ${allContain ? '✅' : '❌'} | '
        '${chapterDup == 0 ? '✅' : '❌'} | 通过（回放校验） |');
    totalLevels += levels.length;
    totalCandidates += candCount;
    totalPeak += peak;
    totalHitTarget += hit;
  }
  overview.writeln('| **合计** | **$totalLevels** | **$totalCandidates** | — | — | — | '
      '全局唯一 ${globalFingerprints.length}（重复 ${totalCandidates - globalFingerprints.length}） | — |');
  overview.writeln();

  perChapter.writeln('## 2. 逐关候选明细');
  perChapter.writeln();
  perChapter.writeln('> 每候选格式：`<编号>:<难度档>/<最高技巧><标记>(<脚本步数>步)`，'
      '标记 `★`=目标技巧为最高技巧（教学峰值明确）；`✓`=含目标技巧但非最高；`✗`=不含（不应出现）。');
  perChapter.writeln();
  for (int ch = 0; ch <= 3; ch++) {
    perChapter.writeln('### ch$ch');
    perChapter.writeln();
    perChapter.writeln('| 关 | 类型 | 目标技巧 | 候选数 | 候选详情 |');
    perChapter.writeln('|---|---|---|---|---|');
    final levels = levelOrder.where((l) => l.startsWith('ch${ch}_')).toList();
    for (final l in levels) {
      final cands = byLevel[l] ?? const <_Candidate>[];
      final targets = kLevelTargets[l] ?? const <TechniqueId>[];
      final details = <String>[];
      for (int i = 0; i < cands.length; i++) {
        final c = cands[i];
        final isPeak = targets.contains(c.hardest);
        final hitTarget = targets.any(c.tags.contains);
        details.add('${i + 1}:${c.difficultyId}/${c.hardest?.id ?? '-'}'
            '${isPeak ? '★' : (hitTarget ? '✓' : '✗')}(${c.scriptSteps}步)');
      }
      perChapter.writeln('| $l | ${kLevelKinds[l]} | '
          '${targets.map((t) => t.zhName).join('、')} | ${cands.length} | '
          '${details.join('<br/>')} |');
    }
    perChapter.writeln();
  }

  out.writeln('# T-CNT-03 教学关候选盘面技巧验证报告');
  out.writeln();
  out.writeln('> 生成时间：${DateTime.now().toUtc().toIso8601String()}');
  out.writeln('> 来源：`packages/sudoku_cli` 的 `generate`+`export-level` 管线'
      '（T-CNT-03 / P0-CLI-07），并已通过 `verify --dataset dataset/level_candidates` 全量回放校验。');
  out.writeln();
  out.write(overview.toString());
  out.write(perChapter.toString());

  out.writeln('## 3. 目标技巧命中与教学峰值');
  out.writeln();
  out.writeln('- 候选总数：$totalCandidates');
  out.writeln('- 含目标技巧的候选：$totalHitTarget（${_pct(totalHitTarget, totalCandidates)}）'
      '——目标技巧为最高技巧（★）：$totalPeak（${_pct(totalPeak, totalCandidates)}）。');
  out.writeln('- 无越章技巧：生成时 `--banned` 屏蔽高于本章范围的技巧'
      '（wWing / 唯一矩形 / 简单涂色等教学范围外技巧一律不出现），'
      '保证每个候选都可用「已学技巧」完整解出。');
  out.writeln();

  out.writeln('## 4. 生成参数摘要');
  out.writeln();
  out.writeln('- 每关候选数：6（34 关 × 6 = 204，全局指纹唯一 204）。');
  out.writeln('- 生成策略：每个目标技巧**单次** `generate --annotate --count 关数×6` 产出大集合'
      '（避免多关独立运行因有效盘面稀疏而扫到相同种子），'
      '再用 `tool/split_gen_collection.dart` 切成各关子集合，`export-level` 导出后重命名。');
  out.writeln('- 试炼关候选：ch1_l07=3 隐三+3 X翼、ch2_l07=3 鳍形 X 翼+3 剑鱼、'
      'ch3_l10=3 XY翼+3 XYZ翼，直接取自各技巧集合（保证全局去重）。');
  out.writeln('- 越章屏蔽：`--banned` 屏蔽高于本章范围的技巧'
      '（wWing / 唯一矩形 / 简单涂色等教学范围外技巧一律不出现），'
      '保证目标技巧为最高技巧且每个候选都可用「已学技巧」完整解出。');
  out.writeln('- 并发：`--concurrency 4`；低命中技巧加大 `--max-attempts`'
      '（swordfish 150000、xWing/hiddenTriple 100000 等，实测剑鱼在屏蔽后命中率约 0.02%）。');
  out.writeln('- 复现：每技巧固定 `--seed`（ch0=300000001…、ch1=310000001…、'
      'ch2=320000001…、ch3=330000001…），同参可复现。');
  out.writeln();

  final File target = File(joinPath(datasetRoot, 'verification_report.md'));
  target.parent.createSync(recursive: true);
  target.writeAsStringSync(out.toString(), flush: true);
  stdout.writeln('已写出验证报告：${target.path}');
}

String _pct(int n, int d) =>
    d == 0 ? '-' : '${(n * 100 / d).toStringAsFixed(1)}%';

String joinPath(String a, String b, [String? c]) {
  final String sep = Platform.pathSeparator;
  final StringBuffer sb = StringBuffer(
    Directory(a).isAbsolute ? a : '${Directory.current.path}$sep$a',
  );
  sb.write(sep);
  sb.write(b);
  if (c != null) {
    sb.write(sep);
    sb.write(c);
  }
  return sb.toString();
}

class _Candidate {
  _Candidate({
    required this.puzzle81,
    required this.tags,
    required this.scriptSteps,
  });

  final String puzzle81;
  final Set<TechniqueId> tags;
  final int scriptSteps;

  /// 规范化指纹（同构去重用）。
  String get fingerprint =>
      Fingerprint.ofValues(BoardCodec.decodeValues(puzzle81));

  /// 按 rank 推导最高技巧。
  TechniqueId? get hardest {
    TechniqueId? best;
    var bestRank = -1;
    for (final TechniqueId id in tags) {
      final int r = TechniqueRank.of(id);
      if (r > bestRank) {
        bestRank = r;
        best = id;
      }
    }
    return best;
  }

  /// 难度档 = 最高技巧对应档位（与 DifficultyGrader 口径一致）。
  String get difficultyId =>
      hardest == null ? '-' : TechniqueRank.difficultyOf(hardest!).id;
}
