/// 离线异步对决大厅：创建挑战、导入挑战码、比较成绩码。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sudoku_tutor/app/route_paths.dart';
import 'package:sudoku_tutor/core/core.dart';
import 'package:sudoku_tutor/domain/duel/async_duel_codec.dart';
import 'package:sudoku_tutor/domain/session/session_providers.dart';
import 'package:sudoku_tutor/ui/features/free_play/free_play_page.dart';
import 'package:sudoku_tutor/ui/theme/spacing.dart';

/// 离线对决大厅。
class AsyncDuelPage extends ConsumerStatefulWidget {
  /// 构造页面；[initialResult] 用于对局结束返回时自动带回我的成绩。
  const AsyncDuelPage({this.initialResult, super.key});

  /// 刚完成的本机成绩。
  final AsyncDuelResult? initialResult;

  @override
  ConsumerState<AsyncDuelPage> createState() => _AsyncDuelPageState();
}

class _AsyncDuelPageState extends ConsumerState<AsyncDuelPage> {
  final TextEditingController _nameController =
      TextEditingController(text: '玩家');
  final TextEditingController _challengeController = TextEditingController();
  final TextEditingController _firstResultController = TextEditingController();
  final TextEditingController _secondResultController = TextEditingController();

  Difficulty _difficulty = Difficulty.medium;
  AsyncDuelChallenge? _createdChallenge;
  String? _createdCode;
  AsyncDuelComparison? _comparison;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    final AsyncDuelResult? result = widget.initialResult;
    if (result != null) {
      _firstResultController.text = AsyncDuelCodec.encodeResult(result);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _challengeController.dispose();
    _firstResultController.dispose();
    _secondResultController.dispose();
    super.dispose();
  }

  Future<void> _createChallenge() async {
    if (_creating) {
      return;
    }
    setState(() => _creating = true);
    try {
      final Puzzle puzzle =
          await ref.read(puzzlePickerProvider).pick(_difficulty);
      final AsyncDuelChallenge challenge = AsyncDuelChallenge.create(
        challengerName: _nameController.text,
        puzzle: puzzle,
        difficulty: _difficulty,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _createdChallenge = challenge;
        _createdCode = AsyncDuelCodec.encodeChallenge(challenge);
      });
    } on AsyncDuelCodeException catch (error) {
      _showMessage(error.message);
    } on Object {
      _showMessage('创建挑战失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _creating = false);
      }
    }
  }

  void _startCreatedChallenge() {
    final AsyncDuelChallenge? challenge = _createdChallenge;
    if (challenge == null) {
      return;
    }
    _startChallenge(challenge, challenge.challengerName);
  }

  void _joinChallenge() {
    try {
      final AsyncDuelChallenge challenge =
          AsyncDuelCodec.decodeChallenge(_challengeController.text);
      _startChallenge(challenge, _nameController.text);
    } on AsyncDuelCodeException catch (error) {
      _showMessage(error.message);
    }
  }

  void _startChallenge(AsyncDuelChallenge challenge, String playerName) {
    try {
      // 复用成绩模型的昵称校验，避免进入对局后才发现无法生成成绩码。
      AsyncDuelResult.completed(
        challenge: challenge,
        playerName: playerName,
        elapsedMs: 0,
        wrongCount: 0,
      );
    } on AsyncDuelCodeException catch (error) {
      _showMessage(error.message);
      return;
    }
    context.goNamed(
      RouteNames.freePlay,
      extra: FreePlayLaunchChallenge(
        challenge: challenge,
        playerName: playerName.trim(),
      ),
    );
  }

  void _compareResults() {
    try {
      final AsyncDuelResult first =
          AsyncDuelCodec.decodeResult(_firstResultController.text);
      final AsyncDuelResult second =
          AsyncDuelCodec.decodeResult(_secondResultController.text);
      setState(() => _comparison = AsyncDuelCodec.compare(first, second));
    } on AsyncDuelCodeException catch (error) {
      setState(() => _comparison = null);
      _showMessage(error.message);
    }
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      _showMessage('$label已复制');
    }
  }

  Future<void> _paste(TextEditingController controller) async {
    final ClipboardData? data = await Clipboard.getData('text/plain');
    final String? text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      controller.text = text.trim();
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goNamed(RouteNames.home),
        ),
        title: const Text('离线对决'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.offline_bolt_outlined),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '无需联网：分享挑战码进入同一道题，完成后交换成绩码。'
                            '每个核验错误格罚时 5 秒。',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const ValueKey<String>('duel-player-name'),
                  controller: _nameController,
                  maxLength: 16,
                  decoration: const InputDecoration(
                    labelText: '我的昵称',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SectionCard(
                  icon: Icons.add_circle_outline,
                  title: '发起挑战',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DropdownButtonFormField<Difficulty>(
                        key: const ValueKey<String>('duel-difficulty'),
                        initialValue: _difficulty,
                        decoration: const InputDecoration(
                          labelText: '题目难度',
                          border: OutlineInputBorder(),
                        ),
                        items: <DropdownMenuItem<Difficulty>>[
                          for (final Difficulty value in Difficulty.values)
                            DropdownMenuItem<Difficulty>(
                              value: value,
                              child: Text(value.zhName),
                            ),
                        ],
                        onChanged: _creating
                            ? null
                            : (Difficulty? value) {
                                if (value != null) {
                                  setState(() => _difficulty = value);
                                }
                              },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        key: const ValueKey<String>('create-duel-code'),
                        onPressed: _creating ? null : _createChallenge,
                        icon: _creating
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.casino_outlined),
                        label: Text(_creating ? '正在选题…' : '生成挑战码'),
                      ),
                      if (_createdCode case final String code) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _CodeBox(
                          key: const ValueKey<String>('created-duel-code'),
                          label: '挑战码 · ${_createdChallenge!.id}',
                          code: code,
                          onCopy: () => _copy(code, '挑战码'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: _startCreatedChallenge,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('开始我的挑战'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  icon: Icons.login,
                  title: '接受挑战',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _CodeInput(
                        key: const ValueKey<String>('challenge-code-input'),
                        controller: _challengeController,
                        label: '粘贴对方的挑战码',
                        onPaste: () => _paste(_challengeController),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        key: const ValueKey<String>('join-duel'),
                        onPressed: _joinChallenge,
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('验证并开始'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  icon: Icons.emoji_events_outlined,
                  title: '比较成绩',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _CodeInput(
                        key: const ValueKey<String>('first-result-input'),
                        controller: _firstResultController,
                        label: '第一份成绩码',
                        onPaste: () => _paste(_firstResultController),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _CodeInput(
                        key: const ValueKey<String>('second-result-input'),
                        controller: _secondResultController,
                        label: '第二份成绩码',
                        onPaste: () => _paste(_secondResultController),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.tonalIcon(
                        key: const ValueKey<String>('compare-duel-results'),
                        onPressed: _compareResults,
                        icon: const Icon(Icons.compare_arrows),
                        label: const Text('比较胜负'),
                      ),
                      if (_comparison case final AsyncDuelComparison value) ...[
                        const SizedBox(height: AppSpacing.md),
                        _ComparisonCard(comparison: value),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '说明：离线成绩码带复制校验，但不具备服务器级防作弊能力，适合熟人之间公平约战。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon),
                  const SizedBox(width: AppSpacing.sm),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      );
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.label,
    required this.code,
    required this.onCopy,
    super.key,
  });

  final String label;
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              IconButton(
                tooltip: '复制',
                onPressed: onCopy,
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          SelectableText(
            code,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.label,
    required this.onPaste,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            tooltip: '从剪贴板粘贴',
            onPressed: onPaste,
            icon: const Icon(Icons.content_paste),
          ),
        ),
      );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final AsyncDuelComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AsyncDuelResult first = comparison.first;
    final AsyncDuelResult second = comparison.second;
    final String headline =
        comparison.isDraw ? '平局' : '${comparison.winner!.playerName} 获胜';
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: <Widget>[
            const Icon(Icons.emoji_events, size: 36),
            const SizedBox(height: AppSpacing.xs),
            Text(headline, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${first.playerName}：${_formatDuration(first.scoreMs)}　·　'
              '${second.playerName}：${_formatDuration(second.scoreMs)}',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int milliseconds) {
  final int totalSeconds = milliseconds ~/ 1000;
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
