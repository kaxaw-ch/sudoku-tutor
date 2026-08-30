/// 自由练习断点快照 `SessionSnapshot`（P0-PRA-09 断点续玩）。
///
/// 对应架构文档 §4.3 类图：题面 + 当前盘面 + 笔记掩码 + 用时 + 撤销栈 +
/// 难度 + 保存时间。撤销栈复用 `sudoku_core` 的 `Move` 编解码，
/// 本文件只做容器与 JSON 序列化。
library;

import 'package:sudoku_tutor/core/core.dart';

/// 对局断点（不可变值对象）。
class SessionSnapshot {
  /// 构造断点。
  const SessionSnapshot({
    required this.puzzle81,
    required this.board81,
    required this.elapsedMs,
    this.noteMasks = const <int>[],
    this.undoStack = const <Move>[],
    this.redoStack = const <Move>[],
    this.difficultyId = 'beginner',
    this.savedAt = 0,
    this.solution81,
    this.givenMask81,
    this.noteMode = false,
    this.autoCandidates = true,
    this.autoNotesFilled = false,
  });

  /// 题面 81 字符串（空格用 `.`，`Board.toPuzzleString()` 口径）。
  final String puzzle81;

  /// 当前盘面 81 字符串。
  final String board81;

  /// 已用时长（毫秒）。
  final int elapsedMs;

  /// 笔记掩码（81 个 `CandidateSet.mask` 位集，0 = 无笔记）。
  final List<int> noteMasks;

  /// 撤销栈（`Move` 值对象，序列化走 `Move.toJson`）。
  final List<Move> undoStack;

  /// 重做栈（`Move` 值对象）。
  final List<Move> redoStack;

  /// 难度档（`Difficulty.id` 字符串）。
  final String difficultyId;

  /// 保存时间（epoch 毫秒，int UTC）。
  final int savedAt;

  /// 终局解 81 字符串（可选；续玩时用于核对答案/提示，T-DOM-04 扩展）。
  ///
  /// 旧版本存档（E-1 基线）不含本字段，读取时按 `null` 容错，
  /// 此时对局可续玩但「核对答案/提示」因缺少终局解而降级。
  final String? solution81;

  /// 题面给定掩码 81 字符串（可选；`1` = 给定，T-DOM-04 扩展）。
  final String? givenMask81;

  /// 是否处于手动笔记模式（T-DOM-04 扩展；旧档缺省视为 false）。
  final bool noteMode;

  /// 自动候选数开关（T-DOM-04 扩展；旧档缺省视为 true）。
  final bool autoCandidates;

  /// 是否通过做题页“自动笔记”按钮填入了全盘候选。
  final bool autoNotesFilled;

  /// 序列化为 JSON map。
  Map<String, Object?> toJson() => <String, Object?>{
        'puzzle81': puzzle81,
        'board81': board81,
        'elapsedMs': elapsedMs,
        'noteMasks': noteMasks,
        'undoStack': <Map<String, Object?>>[
          for (final Move m in undoStack) m.toJson(),
        ],
        'redoStack': <Map<String, Object?>>[
          for (final Move m in redoStack) m.toJson(),
        ],
        'difficultyId': difficultyId,
        'savedAt': savedAt,
        if (solution81 != null) 'solution81': solution81,
        if (givenMask81 != null) 'givenMask81': givenMask81,
        'noteMode': noteMode,
        'autoCandidates': autoCandidates,
        'autoNotesFilled': autoNotesFilled,
      };

  /// 由 JSON map 反序列化。
  factory SessionSnapshot.fromJson(Map<String, Object?> json) {
    List<Move> decodeMoves(Object? raw) => <Move>[
          if (raw is List)
            for (final Object? item in raw)
              Move.fromJson(item! as Map<String, Object?>),
        ];

    return SessionSnapshot(
      puzzle81: json['puzzle81']! as String,
      board81: json['board81']! as String,
      elapsedMs: (json['elapsedMs'] as int?) ?? 0,
      noteMasks: <int>[
        if (json['noteMasks'] is List)
          for (final Object? item in json['noteMasks']! as List) item! as int,
      ],
      undoStack: decodeMoves(json['undoStack']),
      redoStack: decodeMoves(json['redoStack']),
      difficultyId: (json['difficultyId'] as String?) ?? 'beginner',
      savedAt: (json['savedAt'] as int?) ?? 0,
      solution81: json['solution81'] as String?,
      givenMask81: json['givenMask81'] as String?,
      noteMode: (json['noteMode'] as bool?) ?? false,
      autoCandidates: (json['autoCandidates'] as bool?) ?? true,
      autoNotesFilled: (json['autoNotesFilled'] as bool?) ?? false,
    );
  }
}
