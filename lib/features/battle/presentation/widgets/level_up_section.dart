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
              color: Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lv.$previousLevel → Lv.$newLevel',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '次のレベルまで $expToNextLevel EXP',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
