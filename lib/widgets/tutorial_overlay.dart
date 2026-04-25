import 'package:flutter/material.dart';

class TutorialOverlay extends StatefulWidget {
  final Rect targetRect;
  final String characterName;
  final String avatarIcon;
  final String message;
  final Alignment dialogAlignment;
  final Color dialogColor;

  const TutorialOverlay({
    Key? key,
    required this.targetRect,
    required this.characterName,
    required this.avatarIcon,
    required this.message,
    this.dialogAlignment = Alignment.center,
    this.dialogColor = Colors.white,
  }) : super(key: key);

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arrowTop = widget.targetRect.top - 56;
    final showArrowAbove = arrowTop > 80;

    return IgnorePointer(
      ignoring: true, // タップはすべて下のUIに貫通させる
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. セミトランスパレントな背景とスポットライト（くり抜き＋脈動）
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => CustomPaint(
              painter: SpotlightPainter(
                widget.targetRect,
                pulseProgress: _pulseAnim.value,
              ),
            ),
          ),

          // 2. 指差し矢印（ターゲット直上 or 直下に表示）
          if (!widget.targetRect.isEmpty)
            Positioned(
              left: widget.targetRect.center.dx - 24,
              top: showArrowAbove
                  ? widget.targetRect.top - 52
                  : widget.targetRect.bottom + 8,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, (showArrowAbove ? 1 : -1) * _pulseAnim.value * 6),
                  child: Text(
                    showArrowAbove ? '👇' : '👆',
                    style: const TextStyle(
                      fontSize: 40,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 8),
                        Shadow(color: Colors.amber, blurRadius: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 3. キャラクターとダイアログ
          Align(
            alignment: widget.dialogAlignment,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Text(widget.avatarIcon, style: const TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: widget.dialogColor, width: 2),
                          ),
                          child: Text(
                            widget.characterName,
                            style: TextStyle(
                              color: widget.dialogColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
                        ],
                        border: Border.all(color: widget.dialogColor, width: 3),
                      ),
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double holeRadius;
  final double padding;
  final double pulseProgress; // 0.0 ～ 1.0 の脈動進捗

  SpotlightPainter(
    this.targetRect, {
    this.holeRadius = 12.0,
    this.padding = 4.0,
    this.pulseProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targetRect.isEmpty) return;

    // 1. 背景を暗くする（くり抜き付き）
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.72)
      ..style = PaintingStyle.fill;

    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final holeRect = Rect.fromLTRB(
      targetRect.left - padding,
      targetRect.top - padding,
      targetRect.right + padding,
      targetRect.bottom + padding,
    );
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(holeRadius)));

    final finalPath = Path.combine(PathOperation.difference, bgPath, holePath);
    canvas.drawPath(finalPath, paint);

    // 2. 脈動する黄色の枠線を描画（対象をより明確にハイライト）
    final pulsePadding = padding + 2.0 + pulseProgress * 6.0;
    final pulseOpacity = 0.85 - pulseProgress * 0.35;
    final pulseRect = Rect.fromLTRB(
      targetRect.left - pulsePadding,
      targetRect.top - pulsePadding,
      targetRect.right + pulsePadding,
      targetRect.bottom + pulsePadding,
    );
    final pulsePaint = Paint()
      ..color = Colors.amberAccent.withOpacity(pulseOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + pulseProgress * 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(pulseRect, Radius.circular(holeRadius + pulseProgress * 4)),
      pulsePaint,
    );
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
