/// 完全离线的挑战码 / 成绩码协议。
///
/// 挑战码携带题面与统一规则，接收方在本机校验唯一解；成绩码携带完成用时
/// 与错误数。协议只使用文本和校验和，不依赖账号、网络或服务器。
library;

import 'dart:convert';

import 'package:sudoku_tutor/core/core.dart';

/// 当前离线对决协议版本。
const int kAsyncDuelSchemaVersion = 1;

/// 每个核验错误格的默认罚时。
const int kAsyncDuelDefaultErrorPenaltyMs = 5000;

/// 挑战码解析失败。
class AsyncDuelCodeException implements Exception {
  /// 构造可直接展示给用户的错误。
  const AsyncDuelCodeException(this.message);

  /// 中文错误说明。
  final String message;

  @override
  String toString() => message;
}

/// 一场离线异步挑战。
class AsyncDuelChallenge {
  /// 构造挑战。
  const AsyncDuelChallenge({
    required this.id,
    required this.challengerName,
    required this.puzzle,
    required this.difficulty,
    required this.createdAtMs,
    this.errorPenaltyMs = kAsyncDuelDefaultErrorPenaltyMs,
  });

  /// 从本地题库题目创建挑战。
  factory AsyncDuelChallenge.create({
    required String challengerName,
    required Puzzle puzzle,
    required Difficulty difficulty,
    int? createdAtMs,
    int errorPenaltyMs = kAsyncDuelDefaultErrorPenaltyMs,
  }) {
    final String name = _validName(challengerName, field: '发起人昵称');
    final int timestamp =
        createdAtMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final String id = _checksum(
      utf8.encode('${puzzle.fingerprint}|$timestamp|$name'),
    ).toUpperCase();
    return AsyncDuelChallenge(
      id: id,
      challengerName: name,
      puzzle: puzzle.copyWith(difficulty: difficulty),
      difficulty: difficulty,
      createdAtMs: timestamp,
      errorPenaltyMs: errorPenaltyMs,
    );
  }

  /// 短挑战编号。
  final String id;

  /// 发起人昵称。
  final String challengerName;

  /// 相同题面及本机求得的唯一解。
  final Puzzle puzzle;

  /// 统一难度标识。
  final Difficulty difficulty;

  /// 挑战创建时间（UTC 毫秒）。
  final int createdAtMs;

  /// 每个核验错误格罚时。
  final int errorPenaltyMs;
}

/// 一名玩家完成挑战后生成的成绩。
class AsyncDuelResult {
  /// 构造成绩。
  const AsyncDuelResult({
    required this.challengeId,
    required this.puzzleFingerprint,
    required this.playerName,
    required this.elapsedMs,
    required this.wrongCount,
    required this.errorPenaltyMs,
    required this.completedAtMs,
  });

  /// 从完成的挑战生成成绩。
  factory AsyncDuelResult.completed({
    required AsyncDuelChallenge challenge,
    required String playerName,
    required int elapsedMs,
    required int wrongCount,
    int? completedAtMs,
  }) =>
      AsyncDuelResult(
        challengeId: challenge.id,
        puzzleFingerprint: challenge.puzzle.fingerprint,
        playerName: _validName(playerName, field: '玩家昵称'),
        elapsedMs: elapsedMs,
        wrongCount: wrongCount,
        errorPenaltyMs: challenge.errorPenaltyMs,
        completedAtMs:
            completedAtMs ?? DateTime.now().toUtc().millisecondsSinceEpoch,
      );

  /// 所属挑战编号。
  final String challengeId;

  /// 题面指纹，防止误比较不同题目。
  final String puzzleFingerprint;

  /// 玩家昵称。
  final String playerName;

  /// 实际完成用时。
  final int elapsedMs;

  /// 自动核验累计发现的错误格数。
  final int wrongCount;

  /// 每个错误格罚时。
  final int errorPenaltyMs;

  /// 完成时间（UTC 毫秒）。
  final int completedAtMs;

  /// 排名用成绩：实际用时 + 错误罚时。
  int get scoreMs => elapsedMs + wrongCount * errorPenaltyMs;
}

/// 两份成绩的比较结果。
class AsyncDuelComparison {
  /// 构造比较结果；[winner] 为 `null` 表示平局。
  const AsyncDuelComparison({
    required this.first,
    required this.second,
    required this.winner,
  });

  /// 第一份成绩。
  final AsyncDuelResult first;

  /// 第二份成绩。
  final AsyncDuelResult second;

  /// 胜者；完全同分时为 `null`。
  final AsyncDuelResult? winner;

  /// 是否平局。
  bool get isDraw => winner == null;
}

/// 离线对决文本协议。
abstract final class AsyncDuelCodec {
  static const String _challengePrefix = 'SDKD1';
  static const String _resultPrefix = 'SDKR1';

  /// 把挑战编码为可复制文本。
  static String encodeChallenge(AsyncDuelChallenge challenge) => _encode(
        _challengePrefix,
        <String, Object?>{
          'v': kAsyncDuelSchemaVersion,
          'id': challenge.id,
          'name': challenge.challengerName,
          'difficulty': challenge.difficulty.id,
          'puzzle': challenge.puzzle.givenString,
          'createdAt': challenge.createdAtMs,
          'penalty': challenge.errorPenaltyMs,
        },
      );

  /// 解析挑战码并在本机完成格式、唯一解及校验和验证。
  static AsyncDuelChallenge decodeChallenge(String code) {
    final Map<String, Object?> json = _decode(code, _challengePrefix);
    _requireVersion(json);
    final String id = _requiredString(json, 'id');
    if (!RegExp(r'^[0-9A-F]{8}$').hasMatch(id)) {
      throw const AsyncDuelCodeException('挑战编号无效');
    }
    final String challengerName =
        _validName(_requiredString(json, 'name'), field: '发起人昵称');
    final Difficulty? difficulty =
        Difficulty.tryParse(_requiredString(json, 'difficulty'));
    if (difficulty == null) {
      throw const AsyncDuelCodeException('挑战难度不受支持');
    }
    final String puzzle81 = _requiredString(json, 'puzzle');
    if (!RegExp(r'^[.1-9]{81}$').hasMatch(puzzle81)) {
      throw const AsyncDuelCodeException('挑战题面格式无效');
    }
    final int createdAtMs = _requiredInt(json, 'createdAt');
    final int errorPenaltyMs = _requiredInt(json, 'penalty');
    if (createdAtMs <= 0 || errorPenaltyMs < 0 || errorPenaltyMs > 60000) {
      throw const AsyncDuelCodeException('挑战规则参数无效');
    }

    try {
      final Board board = Board.fromPuzzleString(puzzle81);
      const BacktrackingSolver solver = BacktrackingSolver();
      if (solver.countSolutions(board, stopAt: 2) != 1) {
        throw const AsyncDuelCodeException('挑战题目不是唯一解');
      }
      final List<int>? solution = solver.solveFirst(board);
      if (solution == null) {
        throw const AsyncDuelCodeException('挑战题目无解');
      }
      return AsyncDuelChallenge(
        id: id,
        challengerName: challengerName,
        puzzle: Puzzle(
          given: board.toValueList(),
          solution: solution,
          difficulty: difficulty,
        ),
        difficulty: difficulty,
        createdAtMs: createdAtMs,
        errorPenaltyMs: errorPenaltyMs,
      );
    } on AsyncDuelCodeException {
      rethrow;
    } on Object {
      throw const AsyncDuelCodeException('挑战题面无法读取');
    }
  }

  /// 把完成成绩编码为可复制文本。
  static String encodeResult(AsyncDuelResult result) => _encode(
        _resultPrefix,
        <String, Object?>{
          'v': kAsyncDuelSchemaVersion,
          'id': result.challengeId,
          'fingerprint': result.puzzleFingerprint,
          'name': result.playerName,
          'elapsed': result.elapsedMs,
          'wrong': result.wrongCount,
          'penalty': result.errorPenaltyMs,
          'completedAt': result.completedAtMs,
        },
      );

  /// 解析并验证成绩码。
  static AsyncDuelResult decodeResult(String code) {
    final Map<String, Object?> json = _decode(code, _resultPrefix);
    _requireVersion(json);
    final String id = _requiredString(json, 'id');
    final String fingerprint = _requiredString(json, 'fingerprint');
    final String playerName =
        _validName(_requiredString(json, 'name'), field: '玩家昵称');
    final int elapsedMs = _requiredInt(json, 'elapsed');
    final int wrongCount = _requiredInt(json, 'wrong');
    final int errorPenaltyMs = _requiredInt(json, 'penalty');
    final int completedAtMs = _requiredInt(json, 'completedAt');
    if (!RegExp(r'^[0-9A-F]{8}$').hasMatch(id) ||
        fingerprint.isEmpty ||
        elapsedMs < 0 ||
        elapsedMs > const Duration(days: 1).inMilliseconds ||
        wrongCount < 0 ||
        wrongCount > 999 ||
        errorPenaltyMs < 0 ||
        errorPenaltyMs > 60000 ||
        completedAtMs <= 0) {
      throw const AsyncDuelCodeException('成绩数据超出有效范围');
    }
    return AsyncDuelResult(
      challengeId: id,
      puzzleFingerprint: fingerprint,
      playerName: playerName,
      elapsedMs: elapsedMs,
      wrongCount: wrongCount,
      errorPenaltyMs: errorPenaltyMs,
      completedAtMs: completedAtMs,
    );
  }

  /// 比较同一挑战的两份成绩。
  static AsyncDuelComparison compare(
    AsyncDuelResult first,
    AsyncDuelResult second,
  ) {
    if (first.challengeId != second.challengeId ||
        first.puzzleFingerprint != second.puzzleFingerprint ||
        first.errorPenaltyMs != second.errorPenaltyMs) {
      throw const AsyncDuelCodeException('两份成绩不属于同一场挑战');
    }
    final AsyncDuelResult? winner =
        switch (first.scoreMs.compareTo(second.scoreMs)) {
      < 0 => first,
      > 0 => second,
      _ => null,
    };
    return AsyncDuelComparison(
      first: first,
      second: second,
      winner: winner,
    );
  }

  static String _encode(String prefix, Map<String, Object?> json) {
    final List<int> bytes = utf8.encode(jsonEncode(json));
    final String payload = base64Url.encode(bytes).replaceAll('=', '');
    return '$prefix.$payload.${_checksum(bytes)}';
  }

  static Map<String, Object?> _decode(String raw, String expectedPrefix) {
    final String code = raw.replaceAll(RegExp(r'\s+'), '');
    if (code.length > 4096) {
      throw const AsyncDuelCodeException('代码过长');
    }
    final List<String> parts = code.split('.');
    if (parts.length != 3 || parts.first != expectedPrefix) {
      throw AsyncDuelCodeException(
        expectedPrefix == _challengePrefix ? '不是有效的挑战码' : '不是有效的成绩码',
      );
    }
    try {
      final String padded = parts[1].padRight(
        parts[1].length + (4 - parts[1].length % 4) % 4,
        '=',
      );
      final List<int> bytes = base64Url.decode(padded);
      if (_checksum(bytes).toLowerCase() != parts[2].toLowerCase()) {
        throw const AsyncDuelCodeException('代码校验失败，请重新复制完整代码');
      }
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?>) {
        throw const AsyncDuelCodeException('代码内容格式无效');
      }
      return decoded;
    } on AsyncDuelCodeException {
      rethrow;
    } on Object {
      throw const AsyncDuelCodeException('代码无法解析，请检查是否复制完整');
    }
  }

  static void _requireVersion(Map<String, Object?> json) {
    if (json['v'] != kAsyncDuelSchemaVersion) {
      throw const AsyncDuelCodeException('代码版本不受支持，请升级应用');
    }
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.isEmpty) {
      throw const AsyncDuelCodeException('代码缺少必要数据');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! int) {
      throw const AsyncDuelCodeException('代码缺少必要数据');
    }
    return value;
  }
}

String _validName(String raw, {required String field}) {
  final String value = raw.trim();
  if (value.isEmpty || value.runes.length > 16) {
    throw AsyncDuelCodeException('$field需为 1–16 个字符');
  }
  return value;
}

String _checksum(List<int> bytes) {
  int hash = 0x811c9dc5;
  for (final int byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
