import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _Bubble {
  final double startX;
  final double size;
  final double speed;
  final double driftAmplitude;
  final double driftSpeed;
  final double phase;
  final Color color;
  _Bubble({
    required this.startX,
    required this.size,
    required this.speed,
    required this.driftAmplitude,
    required this.driftSpeed,
    required this.phase,
    required this.color,
  });
}

/// A lightweight, looping field of soft glowing bubbles drifting upward.
/// Pure CustomPainter with plain radial-gradient circles — no blur filters,
/// no extra widget rebuilds outside the repaint — so it stays smooth even
/// on modest devices and rides whatever refresh rate the display/engine
/// support (60/90/120Hz), since it's driven by a single vsync-synced
/// AnimationController.
class FloatingBubblesBackground extends StatefulWidget {
  final int bubbleCount;
  final double opacity;

  const FloatingBubblesBackground({
    super.key,
    this.bubbleCount = 10,
    this.opacity = 0.5,
  });

  @override
  State<FloatingBubblesBackground> createState() =>
      _FloatingBubblesBackgroundState();
}

class _FloatingBubblesBackgroundState extends State<FloatingBubblesBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Bubble> _bubbles;

  static const _palette = [
    AppColors.primary,
    AppColors.purple,
    AppColors.cyan,
    AppColors.green,
  ];

  @override
  void initState() {
    super.initState();
    final rnd = math.Random(7);
    _bubbles = List.generate(widget.bubbleCount, (i) {
      return _Bubble(
        startX: rnd.nextDouble(),
        size: 26 + rnd.nextDouble() * 64,
        speed: 0.05 + rnd.nextDouble() * 0.06,
        driftAmplitude: 0.03 + rnd.nextDouble() * 0.05,
        driftSpeed: 0.5 + rnd.nextDouble() * 1.4,
        phase: rnd.nextDouble() * 2 * math.pi,
        color: _palette[i % _palette.length],
      );
    });
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 22))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _BubblesPainter(
                bubbles: _bubbles,
                t: _controller.value,
                opacity: widget.opacity,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final double t;
  final double opacity;
  _BubblesPainter({required this.bubbles, required this.t, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in bubbles) {
      final travel = (t / b.speed) % 1.0;
      final y = size.height * (1.15 - travel * 1.35);
      final drift =
          math.sin(t * 2 * math.pi * b.driftSpeed + b.phase) * b.driftAmplitude;
      final x = (b.startX + drift) * size.width;

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            b.color.withOpacity(opacity * 0.35),
            b.color.withOpacity(0),
          ],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: b.size));

      canvas.drawCircle(Offset(x, y), b.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) => oldDelegate.t != t;
}