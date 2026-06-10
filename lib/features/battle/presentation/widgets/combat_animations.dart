import 'dart:math';
import 'package:flutter/material.dart';

// ─── Slash Effect ───────────────────────────────────────────────────

/// Draws a sword-slash arc across the canvas using [CustomPainter].
///
/// Used for the attack animation when the player strikes an enemy.
/// Controlled by a parent [AnimationController] (0→1 sweeps the arc).
class SlashEffect extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final double thickness;

  const SlashEffect({
    super.key,
    required this.animation,
    this.color = Colors.amberAccent,
    this.thickness = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _SlashPainter(
            progress: animation.value,
            color: color,
            thickness: thickness,
          ),
        );
      },
    );
  }
}

class _SlashPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double thickness;

  _SlashPainter({
    required this.progress,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1.0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Three diagonal slash arcs that sweep across
    for (int i = 0; i < 3; i++) {
      final offset = (i - 1) * 20.0;
      final p = (progress * 1.3 - i * 0.15).clamp(0.0, 1.0);

      final startX = size.width * 0.2 + offset;
      final startY = size.height * 0.7;
      final endX = size.width * 0.8 + offset;

      final path = Path()
        ..moveTo(startX, startY)
        ..quadraticBezierTo(
          size.width * 0.5 + offset,
          size.height * (0.3 - p * 0.5),
          endX,
          size.height * 0.3,
        );

      // Dash effect: draw only active portion
      canvas.drawPath(
        _trimPath(path, p.clamp(0.0, 1.0)),
        paint..color = color.withAlpha((200 * p).round()),
      );
    }
  }

  Path _trimPath(Path source, double fraction) {
    if (fraction >= 1.0) return source;
    final metrics = source.computeMetrics().first;
    return metrics.extractPath(0, metrics.length * fraction);
  }

  @override
  bool shouldRepaint(_SlashPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

// ─── Hit Spark Particles ─────────────────────────────────────────────

/// Burst of colored sparks that radiate from a hit point.
///
/// Renders [count] particles that shoot outward and fade.
/// Controlled by a parent [AnimationController].
class HitSparkEffect extends StatelessWidget {
  final Animation<double> animation;
  final int count;
  final Color primaryColor;
  final Color secondaryColor;
  final double radius;

  const HitSparkEffect({
    super.key,
    required this.animation,
    this.count = 12,
    this.primaryColor = Colors.orangeAccent,
    this.secondaryColor = Colors.yellow,
    this.radius = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final sparks = List.generate(count, (i) => _sparkForIndex(i));
        return CustomPaint(
          size: Size(radius * 2, radius * 2),
          painter: _HitSparkPainter(
            progress: animation.value,
            sparks: sparks,
          ),
        );
      },
    );
  }

  _Spark _sparkForIndex(int i) {
    final random = Random(i * 37); // seeded per particle
    final angle = (i / count) * 2 * pi + random.nextDouble() * 0.3;
    return _Spark(
      angle: angle,
      distance: radius * (0.5 + random.nextDouble() * 0.5),
      size: 2.0 + random.nextDouble() * 4.0,
      color: random.nextBool() ? primaryColor : secondaryColor,
      delay: random.nextDouble() * 0.1,
    );
  }
}

class _Spark {
  final double angle;
  final double distance;
  final double size;
  final Color color;
  final double delay;

  const _Spark({
    required this.angle,
    required this.distance,
    required this.size,
    required this.color,
    required this.delay,
  });
}

class _HitSparkPainter extends CustomPainter {
  final double progress;
  final List<_Spark> sparks;

  _HitSparkPainter({required this.progress, required this.sparks});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final spark in sparks) {
      final raw = ((progress - spark.delay) / (1.0 - spark.delay)).clamp(0.0, 1.0);
      if (raw <= 0) continue;

      final curve = Curves.easeOut.transform(raw);
      final dx = center.dx + cos(spark.angle) * spark.distance * curve;
      final dy = center.dy + sin(spark.angle) * spark.distance * curve;
      final alpha = ((1.0 - raw) * 255).round().clamp(0, 255);

      paint.color = spark.color.withAlpha(alpha);
      canvas.drawCircle(Offset(dx, dy), spark.size * (1.0 - raw * 0.5), paint);

      // Trail
      paint.color = spark.color.withAlpha((alpha * 0.4).round());
      canvas.drawCircle(
        Offset(
          dx - cos(spark.angle) * spark.size * 2,
          dy - sin(spark.angle) * spark.size * 2,
        ),
        spark.size * 0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HitSparkPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

// ─── Floating Damage Number ──────────────────────────────────────────

/// A damage/XP number that floats upward and fades out.
///
/// Usage:
/// ```dart
/// DamageNumber(
///   value: 42,
///   isCritical: true,
///   controller: _damageAnimController,
/// )
/// ```
class DamageNumber extends StatelessWidget {
  final int value;
  final bool isCritical;
  final bool isXp;
  final AnimationController controller;

  const DamageNumber({
    super.key,
    required this.value,
    required this.controller,
    this.isCritical = false,
    this.isXp = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final curved = Curves.easeOutCubic.transform(t);

        return Opacity(
          opacity: t < 0.2 ? (t / 0.2) : (1.0 - ((t - 0.2) / 0.8)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -curved * 60),
            child: Transform.scale(
              scale: isCritical ? 1.4 : 1.0 + curved * 0.3,
              child: Text(
                isXp ? '+$value XP' : '$value',
                style: TextStyle(
                  fontSize: isCritical ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  color: isXp
                      ? Colors.lightGreenAccent
                      : isCritical
                          ? Colors.redAccent
                          : Colors.orangeAccent,
                  shadows: [
                    Shadow(
                      color: Colors.black.withAlpha(180),
                      blurRadius: 4,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
