import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';

/// S/A/Bランク枠表示Widget
class RankSlotDisplay extends StatelessWidget {
  final Player player;
  final List<Task> activeTasks;

  const RankSlotDisplay({
    super.key,
    required this.player,
    required this.activeTasks,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildRankRow(
          QuestRank.S,
          activeTasks.where((t) => t.rank == QuestRank.S).length,
          player.questSlots[QuestRank.S] ?? 0,
        ),
        const SizedBox(height: 4),
        _buildRankRow(
          QuestRank.A,
          activeTasks.where((t) => t.rank == QuestRank.A).length,
          player.questSlots[QuestRank.A] ?? 0,
        ),
        const SizedBox(height: 4),
        _buildRankRow(
          QuestRank.B,
          activeTasks.where((t) => t.rank == QuestRank.B).length,
          player.questSlots[QuestRank.B] ?? 0,
        ),
      ],
    );
  }

  Widget _buildRankRow(QuestRank rank, int current, int max) {
    Color color;
    switch (rank) {
      case QuestRank.S:
        color = const Color(0xFFFFD700);
        break;
      case QuestRank.A:
        color = const Color(0xFFC0C0C0);
        break;
      case QuestRank.B:
        color = const Color(0xFFCD7F32);
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rank.name,
          style: GoogleFonts.pressStart2p(
              fontSize: 12, color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        if (max == 0) Text("-", style: TextStyle(color: Colors.grey[600])),
        for (int i = 0; i < max; i++)
          Container(
            margin: const EdgeInsets.only(left: 4),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: i < current ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
          ),
      ],
    );
  }
}
