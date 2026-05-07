import 'package:flutter/material.dart';
import 'package:rpg_todo/domain/models/player.dart';

/// EXPバー表示Widget
class ExpProgressBar extends StatelessWidget {
  final Player player;

  const ExpProgressBar({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: player.currentExp / player.expToNextLevel,
          minHeight: 10,
          backgroundColor: Colors.grey[800],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
        ),
        Text("${player.currentExp} / ${player.expToNextLevel} EXP"),
      ],
    );
  }
}
