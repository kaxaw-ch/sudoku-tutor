/// 数独核验通过后的恭喜动画。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sudoku_tutor/l10n/app_localizations.dart';

/// 恭喜动画弹层。
abstract final class CongratulationsAnimation {
  /// 展示彩屑与奖杯动画；用户点击按钮或遮罩后关闭。
  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
  }) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.text('关闭恭喜动画'),
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration:
          disableAnimations ? Duration.zero : const Duration(milliseconds: 420),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) =>
          _CongratulationsCard(
            title: title ?? context.l10n.text('恭喜完成！'),
            message:
                message ?? context.l10n.text('自动核验通过，整盘全部正确。'),
          ),
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        final Animation<double> curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    );
  }
}

class _CongratulationsCard extends StatefulWidget {
  const _CongratulationsCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_CongratulationsCard> createState() => _CongratulationsCardState();
}

class _CongratulationsCardState extends State<_CongratulationsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Material(
          key: const ValueKey<String>('congratulations-animation'),
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(24),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 330,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (BuildContext context, Widget? child) =>
                              CustomPaint(
                            painter: _ConfettiPainter(
                              progress: _controller.value,
                              colors: <Color>[
                                theme.colorScheme.primary,
                                const Color(0xFFF59E0B),
                                const Color(0xFF16A34A),
                                const Color(0xFFDB2777),
                                const Color(0xFF0891B2),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (BuildContext context, Widget? child) {
                                final double t = Curves.elasticOut.transform(
                                  math.min(1, _controller.value / 0.55),
                                );
                                return Transform.scale(
                                  scale: t,
                                  child: Transform.rotate(
                                    angle: math.sin(
                                            _controller.value * math.pi * 4) *
                                        (1 - _controller.value) *
                                        0.12,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                width: 92,
                                height: 92,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.emoji_events_rounded,
                                  size: 54,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 22),
                            FilledButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.celebration_rounded),
                              label: Text(context.l10n.text('太棒了')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 结算卡可复用的弹性奖杯图标。
class CelebrationTrophy extends StatefulWidget {
  /// 构造奖杯动画。
  const CelebrationTrophy({this.size = 28, super.key});

  /// 图标尺寸。
  final double size;

  @override
  State<CelebrationTrophy> createState() => _CelebrationTrophyState();
}

class _CelebrationTrophyState extends State<CelebrationTrophy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        scale: Curves.elasticOut.transform(_controller.value),
        child: child,
      ),
      child: Icon(
        Icons.emoji_events_outlined,
        size: widget.size,
        color: const Color(0xFFD97706),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  static const int _particleCount = 38;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || progress <= 0) {
      return;
    }
    for (int i = 0; i < _particleCount; i++) {
      final double phase = (progress * 1.16 + i * 0.071) % 1;
      final double baseX = ((i * 47) % _particleCount) / _particleCount;
      final double sway = math.sin(phase * math.pi * 4 + i) * 16;
      final Offset center = Offset(
        baseX * size.width + sway,
        -14 + phase * (size.height + 28),
      );
      final Paint paint = Paint()..color = colors[i % colors.length];
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(phase * math.pi * 3 + i);
      if (i.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-4, -2.5, 8, 5),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, 3, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}
