import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/task.dart';
import '../providers/game_state.dart';

class PlayerStatusHeader extends StatelessWidget {
  const PlayerStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // We listen to GameState changes to update stats live
    final gameState = Provider.of<GameState>(context);
    final player = gameState.player;
    final activeTasks = gameState.activeTasks;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black12,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Lv.${player.level} ${_getJobName(player.currentJob)}",
                    style: GoogleFonts.pressStart2p(fontSize: 16),
                  ),
                  if (player.currentJob == Job.warrior)
                    Text(
                      "Combo: ${player.comboCount}",
                      style: const TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildRankRow(
                      QuestRank.S,
                      activeTasks.where((t) => t.rank == QuestRank.S).length,
                      player.questSlots[QuestRank.S] ?? 0),
                  const SizedBox(height: 4),
                  _buildRankRow(
                      QuestRank.A,
                      activeTasks.where((t) => t.rank == QuestRank.A).length,
                      player.questSlots[QuestRank.A] ?? 0),
                  const SizedBox(height: 4),
                  _buildRankRow(
                      QuestRank.B,
                      activeTasks.where((t) => t.rank == QuestRank.B).length,
                      player.questSlots[QuestRank.B] ?? 0),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: player.currentExp / player.expToNextLevel,
            minHeight: 10,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          Text("${player.currentExp} / ${player.expToNextLevel} EXP"),
        ],
      ),
    );
  }

  String _getJobName(Job job) {
    switch (job) {
      case Job.warrior:
        return "戦士";
      case Job.cleric:
        return "僧侶";
      case Job.wizard:
        return "魔法使い";
      case Job.adventurer:
        return "冒険者";
    }
  }

  Widget _buildRankRow(QuestRank rank, int current, int max) {
    Color color;
    switch (rank) {
      case QuestRank.S:
        color = const Color(0xFFFFD700); // Gold
        break;
      case QuestRank.A:
        color = const Color(0xFFC0C0C0); // Silver
        break;
      case QuestRank.B:
        color = const Color(0xFFCD7F32); // Bronze
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
