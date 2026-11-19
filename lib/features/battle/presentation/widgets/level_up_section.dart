import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// レベルアップ表示セクション
class LevelUpSection extends StatelessWidget {
  final int previousLevel;
  final int newLevel;
  final int expToNextLevel;

  const LevelUpSection({
    super.key,
    required this.previousLevel,
    required this.newLevel,
    required this.expToNextLevel,
  });

  @override
  Widget build(BuildContext context) {
    // 金の帯（#7B5C00 → #FFD700）の上は、明度テーマに依らず濃色の前景が正しい。
    // ライトの onPrimary は墨色、ダークは黒で、いずれも金地に対して 4.5:1 以上。
    final onGold = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B5C00), Color(0xFFFFD700), Color(0xFF7B5C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.amber, blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          const Text('⬆', style: TextStyle(fontSize: 36)),
          Text(
            'LEVEL UP!',
            style: GoogleFonts.pressStart2p(
              fontSize: 20,
              color: onGold,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lv.$previousLevel → Lv.$newLevel',
            style: TextStyle(
              fontSize: 18,
              color: onGold,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '次のレベルまで $expToNextLevel EXP',
            style: TextStyle(
                fontSize: 12, color: onGold.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}
