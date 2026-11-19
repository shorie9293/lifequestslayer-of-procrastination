import 'package:flutter/material.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';

/// 討伐ボーナスメッセージリスト
class BonusMessageList extends StatelessWidget {
  final List<String> messages;

  const BonusMessageList({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎉 ボーナス',
            style: TextStyle(
              color: palette.accent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          ...messages.map(
            (msg) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                msg,
                style: TextStyle(
                  color: palette.accentStrong,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
