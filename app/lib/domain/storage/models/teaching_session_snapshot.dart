/// 引导实操关的轻量断点，仅保存当前状态，不保存操作历史。
library;

import 'package:sudoku_tutor/core/core.dart';

import 'session_snapshot.dart';

/// 单个教学关卡的当前盘面快照。
class TeachingSessionSnapshot {
  /// 构造教学断点。
  const TeachingSessionSnapshot({
    required this.levelId,
    required this.puzzle81,
    required this.board81,
    required this.elapsedMs,
    this.noteMasks = const <int>[],
    this.noteMode = false,
    this.autoCandidates = false,
    this.autoNotesFilled = false,
    this.hintUsed = 0,
    this.errorCount = 0,
    this.savedAt = 0,
  });

  /// 课程关卡 id。
  final String levelId;

  /// 用于识别课程更新的原始题面。
  final String puzzle81;

  /// 当前盘面。
  final String board81;

  /// 当前候选/笔记掩码。
  final List<int> noteMasks;

  /// 已用时长。
  final int elapsedMs;

  /// 是否处于笔记模式。
  final bool noteMode;

  /// 是否持续自动维护候选数。
  final bool autoCandidates;

  /// 是否使用过一次性自动笔记。
  final bool autoNotesFilled;

  /// 已使用的提示次数。
  final int hintUsed;

  /// 已记录的误操作次数。
  final int errorCount;

  /// 保存时间（UTC epoch 毫秒）。
  final int savedAt;

  /// 关卡题面未变化时才允许恢复，避免课程升级后套用旧盘面。
  bool matches(Puzzle puzzle) => puzzle.givenString == puzzle81;

  /// 转成通用对局快照；撤销和重做栈明确留空。
  SessionSnapshot toSessionSnapshot(Puzzle puzzle) => SessionSnapshot(
        puzzle81: puzzle.givenString,
        board81: board81,
        elapsedMs: elapsedMs,
        noteMasks: List<int>.of(noteMasks),
        undoStack: const <Move>[],
        redoStack: const <Move>[],
        difficultyId: (puzzle.difficulty ?? Difficulty.medium).id,
        savedAt: savedAt,
        solution81: puzzle.solution.join(),
        givenMask81: puzzle.toGivenBoard().toGivenMaskString(),
        noteMode: noteMode,
        autoCandidates: autoCandidates,
        autoNotesFilled: autoNotesFilled,
      );

  /// 序列化。
  Map<String, Object?> toJson() => <String, Object?>{
        'levelId': levelId,
        'puzzle81': puzzle81,
        'board81': board81,
        'elapsedMs': elapsedMs,
        'noteMasks': noteMasks,
        'noteMode': noteMode,
        'autoCandidates': autoCandidates,
        'autoNotesFilled': autoNotesFilled,
        'hintUsed': hintUsed,
        'errorCount': errorCount,
        'savedAt': savedAt,
      };

  /// 反序列化。
  factory TeachingSessionSnapshot.fromJson(Map<String, Object?> json) =>
      TeachingSessionSnapshot(
        levelId: json['levelId']! as String,
        puzzle81: json['puzzle81']! as String,
        board81: json['board81']! as String,
        elapsedMs: (json['elapsedMs'] as int?) ?? 0,
        noteMasks: <int>[
          if (json['noteMasks'] is List)
            for (final Object? item in json['noteMasks']! as List) item! as int,
        ],
        noteMode: (json['noteMode'] as bool?) ?? false,
        autoCandidates: (json['autoCandidates'] as bool?) ?? false,
        autoNotesFilled: (json['autoNotesFilled'] as bool?) ?? false,
        hintUsed: (json['hintUsed'] as int?) ?? 0,
        errorCount: (json['errorCount'] as int?) ?? 0,
        savedAt: (json['savedAt'] as int?) ?? 0,
      );
}
