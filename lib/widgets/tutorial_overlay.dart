import 'package:flutter/material.dart';

class TutorialOverlay extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true, // タップはすべて下のUIに貫通させる
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. セミトランスパレントな背景とスポットライト（くり抜き）
          CustomPaint(
            painter: SpotlightPainter(targetRect),
          ),
          
          // 2. キャラクターとダイアログ
          Align(
            alignment: dialogAlignment,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // キャラクターアイコンと名前
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Text(avatarIcon, style: const TextStyle(fontSize: 28)),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dialogColor, width: 2),
                          ),
                          child: Text(
                            characterName,
                            style: TextStyle(
                              color: dialogColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 吹き出し
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: dialogColor, width: 3),
                      ),
                      child: Text(
                        message,
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

  SpotlightPainter(this.targetRect, {this.holeRadius = 12.0, this.padding = 4.0});

  @override
  void paint(Canvas canvas, Size size) {
    if (targetRect.isEmpty) return; // 何も描画しない
    
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // 画面全体
    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // くり抜く部分 (パディングを追加して少し大きめにくり抜く)
    final holeRect = Rect.fromLTRB(
      targetRect.left - padding, 
      targetRect.top - padding, 
      targetRect.right + padding, 
      targetRect.bottom + padding
    );
    final holePath = Path()..addRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(holeRadius)));

    // 差分を作成
    final finalPath = Path.combine(PathOperation.difference, bgPath, holePath);

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
