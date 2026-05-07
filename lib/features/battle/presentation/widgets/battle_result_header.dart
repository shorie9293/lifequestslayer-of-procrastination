import 'package:flutter/material.dart';

/// 戦果報告書のヘッダー（タイトル＋獲得金貨）
class BattleResultHeader extends StatelessWidget {
  final int coinsGained;

  const BattleResultHeader({super.key, required this.coinsGained});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          '⚔️ 戦果報告書',
          style: TextStyle(
            fontSize: 24,
            color: Color(0xFF4A90D9),
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 2,
          width: 120,
          color: const Color(0xFF4A90D9).withValues(alpha: 0.5),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              '$coinsGained 文 を獲得！',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
