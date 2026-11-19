import 'package:flutter/material.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';

/// 戦果報告書のヘッダー（タイトル＋獲得金貨）
class BattleResultHeader extends StatelessWidget {
  final int coinsGained;

  const BattleResultHeader({super.key, required this.coinsGained});

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final titleColor = palette.readable(const Color(0xFF4A90D9));
    return Column(
      children: [
        Text(
          '⚔️ 戦果報告書',
          style: TextStyle(
            fontSize: 24,
            color: titleColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 2,
          width: 120,
          color: titleColor.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              '$coinsGained 文 を獲得！',
              style: TextStyle(
                fontSize: 20,
                color: palette.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
