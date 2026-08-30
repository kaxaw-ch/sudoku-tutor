/// 终端进度输出与命中率报表（doc 06 §3.2 `lib/src/io/progress_reporter.dart`）。
///
/// 职责：
/// - 统一收敛 CLI 的终端文案（`avoid_print` 由本文件集中承担）；
/// - 统计管道各阶段的漏斗数据（尝试/唯一解/逻辑可解/命中筛选/去重收录），
///   渲染**命中率报表**（doc 07 T-CLI-02 验收项，风险 A-06 的决策数据来源）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:sudoku_core/sudoku_core.dart';

/// 一次出题管线的统计漏斗（纯数据，可序列化）。
class PipelineStats {
  /// 构造统计对象。
  PipelineStats({
    required this.targetCount,
    required this.attempts,
    required this.uniqueOk,
    required this.solvable,
    required this.matched,
    required this.accepted,
    required this.elapsedMs,
    Map<TechniqueId, int> usageCounts = const <TechniqueId, int>{},
    Map<Difficulty, int> difficultyCounts = const <Difficulty, int>{},
  })  : usageCounts = Map<TechniqueId, int>.unmodifiable(usageCounts),
        difficultyCounts = Map<Difficulty, int>.unmodifiable(difficultyCounts);

  /// 目标收录数量。
  final int targetCount;

  /// 生成器调用次数（尝试总数）。
  final int attempts;

  /// 唯一解校验通过的题数。
  final int uniqueOk;

  /// 在规则集内纯逻辑可解的题数。
  final int solvable;

  /// 通过筛选条件的题数（去重前）。
  final int matched;

  /// 去重后实际收录的题数。
  final int accepted;

  /// 耗时（毫秒）。
  final int elapsedMs;

  /// 收录题中各技巧的总使用次数（rank 升序）。
  final Map<TechniqueId, int> usageCounts;

  /// 收录题的难度分布。
  final Map<Difficulty, int> difficultyCounts;

  /// 序列化为 JSON map（`--report` 落盘用）。
  Map<String, Object?> toJson() => <String, Object?>{
        'targetCount': targetCount,
        'attempts': attempts,
        'uniqueOk': uniqueOk,
        'solvable': solvable,
        'matched': matched,
        'accepted': accepted,
        'elapsedMs': elapsedMs,
        'usageCounts': <String, int>{
          for (final MapEntry<TechniqueId, int> e in usageCounts.entries)
            e.key.id: e.value,
        },
        'difficultyCounts': <String, int>{
          for (final MapEntry<Difficulty, int> e in difficultyCounts.entries)
            e.key.id: e.value,
        },
      };

  /// 由 JSON map 反序列化。
  static PipelineStats fromJson(Map<String, Object?> json) => PipelineStats(
        targetCount: json['targetCount']! as int,
        attempts: json['attempts']! as int,
        uniqueOk: json['uniqueOk']! as int,
        solvable: json['solvable']! as int,
        matched: json['matched']! as int,
        accepted: json['accepted']! as int,
        elapsedMs: json['elapsedMs']! as int,
        usageCounts: <TechniqueId, int>{
          for (final MapEntry<String, Object?> e
              in ((json['usageCounts'] as Map<String, Object?>?) ??
                      const <String, Object?>{})
                  .entries)
            TechniqueId.parse(e.key): e.value! as int,
        },
        difficultyCounts: <Difficulty, int>{
          for (final MapEntry<String, Object?> e
              in ((json['difficultyCounts'] as Map<String, Object?>?) ??
                      const <String, Object?>{})
                  .entries)
            Difficulty.tryParse(e.key)!: e.value! as int,
        },
      );
}

/// 终端进度与报表输出器。
///
/// [sink] 可注入（测试用 StringBuffer）；[quiet] 时跳过 `progress` 噪音，
/// 但 `info/warn/error` 与最终报表始终输出。
class ProgressReporter {
  /// 构造输出器。
  ProgressReporter({StringSink? sink, this.quiet = false})
      : _sink = sink ?? stdout;

  final StringSink _sink;

  /// 安静模式：隐藏逐条进度。
  final bool quiet;

  /// 普通信息（quiet 模式下仍输出，用于关键节点）。
  void info(String message) => _sink.writeln(message);

  /// 进度信息（quiet 模式下跳过）。
  void progress(String message) {
    if (!quiet) {
      _sink.writeln(message);
    }
  }

  /// 警告（始终输出，前缀 `⚠`）。
  void warn(String message) => _sink.writeln('⚠ $message');

  /// 错误（始终输出，前缀 `✖`）。
  void error(String message) => _sink.writeln('✖ $message');

  /// 分节标题。
  void section(String title) {
    _sink
      ..writeln()
      ..writeln('========== $title ==========');
  }

  /// 输出命中率报表。
  void reportStats(PipelineStats stats, {String title = '生成命中率报表'}) {
    _sink.writeln(_renderStats(stats, title: title));
  }

  /// 渲染命中率报表文本（公开以便测试断言）。
  String renderStats(PipelineStats stats, {String title = '生成命中率报表'}) =>
      _renderStats(stats, title: title);

  String _renderStats(PipelineStats stats, {required String title}) {
    final StringBuffer buffer = StringBuffer();
    final double uniqueRate = _rate(stats.uniqueOk, stats.attempts);
    final double solvableRate = _rate(stats.solvable, stats.attempts);
    final double matchedRate = _rate(stats.matched, stats.attempts);
    final double acceptRate = _rate(stats.accepted, stats.attempts);

    buffer
      ..writeln(title)
      ..writeln('  目标收录     : ${stats.targetCount} 道')
      ..writeln('  尝试总数     : ${stats.attempts}')
      ..writeln('  唯一解成功   : ${stats.uniqueOk} (${_pct(uniqueRate)})')
      ..writeln('  纯逻辑可解   : ${stats.solvable} (${_pct(solvableRate)})')
      ..writeln('  命中筛选     : ${stats.matched} (${_pct(matchedRate)})')
      ..writeln('  去重后收录   : ${stats.accepted} (${_pct(acceptRate)})')
      ..writeln('  耗时         : ${_formatDuration(stats.elapsedMs)}');

    // 难度分布
    buffer.writeln('  难度分布     :');
    for (final Difficulty difficulty in Difficulty.values) {
      final int count = stats.difficultyCounts[difficulty] ?? 0;
      buffer.writeln('    ${_pad(difficulty.id)} : $count');
    }

    // 技巧命中（按 rank 升序；收录题中的出现次数）
    buffer.writeln('  技巧命中（收录题中使用次数，rank 升序）:');
    final List<TechniqueId> ids = TechniqueRank.byRankAscending()
        .where(stats.usageCounts.containsKey)
        .toList();
    if (ids.isEmpty) {
      buffer.writeln('    （无 —— 收录题未标注任何技巧）');
    } else {
      for (final TechniqueId id in ids) {
        final int count = stats.usageCounts[id]!;
        final String tag =
            Difficulty.values.contains(TechniqueRank.difficultyOf(id))
                ? '【${TechniqueRank.difficultyOf(id).id}】'
                : '';
        buffer.writeln('    ${_pad(id.id)} : $count  $tag');
      }
    }
    return buffer.toString();
  }

  static String _pad(String text) => text.padRight(18);

  static double _rate(int part, int total) =>
      total <= 0 ? 0 : part / total;

  static String _pct(double rate) => '${(rate * 100).toStringAsFixed(1)}%';

  static String _formatDuration(int elapsedMs) {
    if (elapsedMs < 1000) {
      return '$elapsedMs ms';
    }
    return '${(elapsedMs / 1000).toStringAsFixed(1)} s';
  }

  /// JSON 美化输出（供 `--report` 落盘）。
  static String prettyJson(Map<String, Object?> json) =>
      const JsonEncoder.withIndent('  ').convert(json);
}
