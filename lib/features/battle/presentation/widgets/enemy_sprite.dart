import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';

/// Enemy sprite appearance configuration per rank.
///
/// Rank-based sprites give each quest tier a distinct visual identity:
/// - S: Boss-tier — large, ornate, golden
/// - A: Elite — medium, silver, armored
/// - B: Common — small, brown, basic
class EnemySpriteConfig {
  final double scale;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;
  final double glowRadius;
  final String label;

  const EnemySpriteConfig({
    required this.scale,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
    required this.glowRadius,
    required this.label,
  });

  static EnemySpriteConfig forRank(QuestRank rank) {
    switch (rank) {
      case QuestRank.S:
        return const EnemySpriteConfig(
          scale: 1.3,
          primaryColor: RankColors.s,
          secondaryColor: Color(0xFFFFD700),
          glowColor: Color(0xFFFFA000),
          glowRadius: 24.0,
          label: 'BOSS',
        );
      case QuestRank.A:
        return const EnemySpriteConfig(
          scale: 1.0,
          primaryColor: RankColors.a,
          secondaryColor: Color(0xFFBDBDBD),
          glowColor: Color(0xFF757575),
          glowRadius: 16.0,
          label: 'ELITE',
        );
      case QuestRank.B:
        return const EnemySpriteConfig(
          scale: 0.85,
          primaryColor: RankColors.b,
          secondaryColor: Color(0xFFA1887F),
          glowColor: Color(0xFF5D4037),
          glowRadius: 10.0,
          label: 'GRUNT',
        );
    }
  }
}

/// Animated enemy sprite widget that swaps appearance based on [rank].
///
/// Renders a procedurally-drawn enemy silhouette using [CustomPainter].
/// Supports [imagePath] override for pixel-art sprite assets.
///
/// Usage:
/// ```dart
/// EnemySprite(rank: task.rank, isAttacking: true)
/// ```
class EnemySprite extends StatefulWidget {
  final QuestRank rank;

  /// Optional image asset path for a hand-drawn sprite.
  /// When non-null, renders the image instead of the procedural shape.
  final String? imagePath;

  /// Whether the enemy is in its attack/hit reaction animation.
  final bool isAttacking;

  /// Whether the enemy has been defeated (fade-out animation).
  final bool isDefeated;

  const EnemySprite({
    super.key,
    required this.rank,
    this.imagePath,
    this.isAttacking = false,
    this.isDefeated = false,
  });

  @override
  State<EnemySprite> createState() => _EnemySpriteState();
}

class _EnemySpriteState extends State<EnemySprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController;
  late final Animation<double> _bobAnimation;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _bobAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _bobController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = EnemySpriteConfig.forRank(widget.rank);

    return AnimatedBuilder(
      animation: _bobAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, widget.isDefeated ? 40 : _bobAnimation.value),
          child: AnimatedOpacity(
            opacity: widget.isDefeated ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: AnimatedScale(
              scale: widget.isAttacking ? config.scale * 1.1 : config.scale,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: child,
            ),
          ),
        );
      },
      child: widget.imagePath != null
          ? _ImageSprite(imagePath: widget.imagePath!, config: config)
          : _ProceduralEnemyPainterWidget(config: config),
    );
  }
}

/// Renders a pixel-art sprite from an asset image.
class _ImageSprite extends StatelessWidget {
  final String imagePath;
  final EnemySpriteConfig config;

  const _ImageSprite({required this.imagePath, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: config.glowColor.withAlpha(100),
            blurRadius: config.glowRadius,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image.asset(
        imagePath,
        width: 80 * config.scale,
        height: 96 * config.scale,
        fit: BoxFit.contain,
        semanticLabel: '敵の画像',
        errorBuilder: (_, __, ___) =>
            _ProceduralEnemyPainterWidget(config: config),
      ),
    );
  }
}

/// Renders [EnemyPainter] in a properly sized widget.
class _ProceduralEnemyPainterWidget extends StatelessWidget {
  final EnemySpriteConfig config;

  const _ProceduralEnemyPainterWidget({required this.config});

  @override
  Widget build(BuildContext context) {
    final size = 80.0 * config.scale;
    return CustomPaint(
      size: Size(size, size * 1.2),
      painter: EnemyPainter(config: config),
    );
  }
}

/// Procedurally draws enemy silhouettes based on rank configuration.
///
/// Each rank draws a distinct monster shape:
/// - S: Dragon-like (wings + horns + fangs)
/// - A: Knight-like (shield + helmet)
/// - B: Slime-like (round blob)
class EnemyPainter extends CustomPainter {
  final EnemySpriteConfig config;

  EnemyPainter({required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    switch (config.label) {
      case 'BOSS':
        _drawDragon(canvas, size, center, paint, stroke);
      case 'ELITE':
        _drawKnight(canvas, size, center, paint, stroke);
      default:
        _drawSlime(canvas, size, center, paint, stroke);
    }
  }

  void _drawDragon(
      Canvas canvas, Size size, Offset center, Paint p, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Glow aura
    p.color = config.glowColor.withAlpha(40);
    canvas.drawCircle(Offset(center.dx, center.dy - h * 0.05), w * 0.45, p);

    // Body
    p.color = config.primaryColor;
    final body = RRect.fromLTRBR(
      center.dx - w * 0.25,
      center.dy - h * 0.15,
      center.dx + w * 0.25,
      center.dy + h * 0.25,
      const Radius.circular(16),
    );
    canvas.drawRRect(body, p);

    // Head
    p.color = config.secondaryColor;
    canvas.drawCircle(
        Offset(center.dx, center.dy - h * 0.2), w * 0.18, p);

    // Horns
    p.color = config.primaryColor;
    final leftHorn = Path()
      ..moveTo(center.dx - w * 0.12, center.dy - h * 0.32)
      ..lineTo(center.dx - w * 0.22, center.dy - h * 0.5)
      ..lineTo(center.dx - w * 0.05, center.dy - h * 0.35)
      ..close();
    final rightHorn = Path()
      ..moveTo(center.dx + w * 0.12, center.dy - h * 0.32)
      ..lineTo(center.dx + w * 0.22, center.dy - h * 0.5)
      ..lineTo(center.dx + w * 0.05, center.dy - h * 0.35)
      ..close();
    canvas.drawPath(leftHorn, p);
    canvas.drawPath(rightHorn, p);

    // Eyes
    p.color = Colors.red;
    canvas.drawCircle(
        Offset(center.dx - w * 0.06, center.dy - h * 0.22), 4, p);
    canvas.drawCircle(
        Offset(center.dx + w * 0.06, center.dy - h * 0.22), 4, p);

    // Wings
    p.color = config.primaryColor.withAlpha(180);
    final leftWing = Path()
      ..moveTo(center.dx - w * 0.2, center.dy - h * 0.05)
      ..quadraticBezierTo(center.dx - w * 0.45, center.dy - h * 0.25,
          center.dx - w * 0.35, center.dy + h * 0.1)
      ..quadraticBezierTo(center.dx - w * 0.2, center.dy + h * 0.05,
          center.dx - w * 0.2, center.dy - h * 0.05)
      ..close();
    final rightWing = Path()
      ..moveTo(center.dx + w * 0.2, center.dy - h * 0.05)
      ..quadraticBezierTo(center.dx + w * 0.45, center.dy - h * 0.25,
          center.dx + w * 0.35, center.dy + h * 0.1)
      ..quadraticBezierTo(center.dx + w * 0.2, center.dy + h * 0.05,
          center.dx + w * 0.2, center.dy - h * 0.05)
      ..close();
    canvas.drawPath(leftWing, p);
    canvas.drawPath(rightWing, p);

    // Fangs
    p.color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(
            center.dx - w * 0.06, center.dy - h * 0.1, 4, 8),
        p);
    canvas.drawRect(
        Rect.fromLTWH(
            center.dx + w * 0.02, center.dy - h * 0.1, 4, 8),
        p);
  }

  void _drawKnight(
      Canvas canvas, Size size, Offset center, Paint p, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Shield (back layer)
    p.color = config.primaryColor.withAlpha(120);
    final shield = Path()
      ..moveTo(center.dx, center.dy - h * 0.12)
      ..lineTo(center.dx + w * 0.22, center.dy - h * 0.05)
      ..lineTo(center.dx + w * 0.15, center.dy + h * 0.15)
      ..lineTo(center.dx - w * 0.15, center.dy + h * 0.15)
      ..lineTo(center.dx - w * 0.22, center.dy - h * 0.05)
      ..close();
    canvas.drawPath(shield, p);

    // Body
    p.color = config.primaryColor;
    final body = RRect.fromLTRBR(
      center.dx - w * 0.18,
      center.dy - h * 0.08,
      center.dx + w * 0.18,
      center.dy + h * 0.22,
      const Radius.circular(10),
    );
    canvas.drawRRect(body, p);

    // Helmet
    p.color = config.secondaryColor;
    final helmet = RRect.fromLTRBR(
      center.dx - w * 0.16,
      center.dy - h * 0.28,
      center.dx + w * 0.16,
      center.dy - h * 0.06,
      const Radius.circular(14),
    );
    canvas.drawRRect(helmet, p);

    // Visor slit
    p.color = Colors.black87;
    canvas.drawRRect(
      RRect.fromLTRBR(
        center.dx - w * 0.12,
        center.dy - h * 0.2,
        center.dx + w * 0.12,
        center.dy - h * 0.16,
        const Radius.circular(3),
      ),
      p,
    );

    // Eyes behind visor
    p.color = Colors.amber;
    canvas.drawCircle(
        Offset(center.dx - w * 0.06, center.dy - h * 0.18), 3.5, p);
    canvas.drawCircle(
        Offset(center.dx + w * 0.06, center.dy - h * 0.18), 3.5, p);
  }

  void _drawSlime(
      Canvas canvas, Size size, Offset center, Paint p, Paint stroke) {
    final w = size.width;
    final h = size.height;

    // Glow
    p.color = config.glowColor.withAlpha(30);
    canvas.drawCircle(center, w * 0.4, p);

    // Body blob
    p.color = config.primaryColor;
    final blob = Path()
      ..moveTo(center.dx - w * 0.3, center.dy + h * 0.1)
      ..quadraticBezierTo(center.dx - w * 0.3, center.dy - h * 0.25,
          center.dx, center.dy - h * 0.3)
      ..quadraticBezierTo(center.dx + w * 0.3, center.dy - h * 0.25,
          center.dx + w * 0.3, center.dy + h * 0.1)
      ..quadraticBezierTo(center.dx + w * 0.15, center.dy + h * 0.2,
          center.dx, center.dy + h * 0.15)
      ..quadraticBezierTo(center.dx - w * 0.15, center.dy + h * 0.2,
          center.dx - w * 0.3, center.dy + h * 0.1)
      ..close();
    canvas.drawPath(blob, p);

    // Highlight
    p.color = config.secondaryColor.withAlpha(80);
    canvas.drawCircle(
        Offset(center.dx - w * 0.1, center.dy - h * 0.1), w * 0.1, p);

    // Eyes
    p.color = Colors.white;
    canvas.drawCircle(
        Offset(center.dx - w * 0.1, center.dy - h * 0.08), 6, p);
    canvas.drawCircle(
        Offset(center.dx + w * 0.1, center.dy - h * 0.08), 6, p);
    p.color = Colors.black;
    canvas.drawCircle(
        Offset(center.dx - w * 0.09, center.dy - h * 0.1), 3, p);
    canvas.drawCircle(
        Offset(center.dx + w * 0.11, center.dy - h * 0.1), 3, p);
  }

  @override
  bool shouldRepaint(EnemyPainter oldDelegate) =>
      config.label != oldDelegate.config.label;
}
