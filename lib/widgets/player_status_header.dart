import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/player.dart';
import '../models/task.dart';
import '../viewmodels/game_view_model.dart';

class PlayerStatusHeader extends StatelessWidget {
  const PlayerStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final player = viewModel.player;
    final activeTasks = viewModel.activeTasks;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black12,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getSkinIcon(player.equippedSkin),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (player.equippedTitle != null && player.equippedTitle!.isNotEmpty)
                        Text(
                          "【${player.equippedTitle}】",
                          style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      Text(
                        "Lv.${player.level} ${_getJobName(player.currentJob)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            "${player.coins}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ],
                      ),
                      if (player.currentJob == Job.warrior)
                        Text(
                          "Combo: ${player.comboCount}",
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                    ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("体調: ${viewModel.fatigueStatus}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("本日の完遂: ${player.dailyTasksCompleted} / ${viewModel.fatigueSevereThreshold}", style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: 1.0 - viewModel.fatigueProgress,
            minHeight: 8,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              viewModel.fatigueProgress >= 1.0 ? Colors.red :
              viewModel.fatigueProgress >= 0.5 ? Colors.orange : Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: player.currentExp / player.expToNextLevel,
            minHeight: 10,
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          Text("${player.currentExp} / ${player.expToNextLevel} EXP"),
          const SizedBox(height: 10),
          // ミッション・ストリークバッジ（Wrapで3列表示）
          _buildBadgeRow(viewModel),
        ],
      ),
    );
  }

  Widget _buildBadgeRow(GameViewModel viewModel) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildStreakBadge(viewModel.streakDays),
        _buildMissionBadge(
          icon: "📅",
          label: viewModel.isDailyMissionComplete
              ? "デイリー達成！"
              : "デイリー: あと${GameViewModel.dailyMissionGoal - viewModel.dailyMissionProgress}クエスト",
          progress: viewModel.dailyMissionProgress / GameViewModel.dailyMissionGoal,
          isDone: viewModel.isDailyMissionComplete,
        ),
        _buildMissionBadge(
          icon: "🏆",
          label: viewModel.isWeeklyMissionComplete
              ? "週次ミッション達成！"
              : "週次Sランク: ${viewModel.weeklyMissionProgress}/${GameViewModel.weeklyMissionGoal}",
          progress: viewModel.weeklyMissionProgress / GameViewModel.weeklyMissionGoal,
          isDone: viewModel.isWeeklyMissionComplete,
        ),
      ],
    );
  }

  Widget _buildStreakBadge(int streakDays) {
    // 次のマイルストーンを求める
    final nextMilestone = streakDays < 3 ? 3 : streakDays < 7 ? 7 : 30;
    final progress = (streakDays / nextMilestone).clamp(0.0, 1.0);
    final isHot = streakDays >= 7;
    final dotCount = min(nextMilestone, 7); // 最大7ドット（1週間サイクル）

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isHot ? Colors.orange.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHot ? Colors.orange : Colors.white24,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🔥 $streakDays 日連続",
            style: TextStyle(
              fontSize: 10,
              color: isHot ? Colors.orangeAccent : Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(dotCount, (i) {
              return Container(
                margin: const EdgeInsets.only(right: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < streakDays ? Colors.orange : Colors.white24,
                ),
              );
            }),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isHot ? Colors.orange : Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionBadge({
    required String icon,
    required String label,
    required double progress,
    required bool isDone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDone ? Colors.green.withOpacity(0.2) : Colors.white10,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDone ? Colors.green : Colors.white24,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$icon $label",
            style: TextStyle(
              fontSize: 10,
              color: isDone ? Colors.greenAccent : Colors.white70,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 80,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDone ? Colors.green : Colors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getJobName(Job job) {
    switch (job) {
      case Job.warrior: return "戦士";
      case Job.cleric: return "僧侶";
      case Job.wizard: return "魔法使い";
      case Job.adventurer: return "冒険者";
    }
  }

  String _getSkinIcon(String? skinId) {
    if (skinId == "skin_1") return "🧥";
    if (skinId == "skin_2") return "🎖️";
    if (skinId == "skin_3") return "🪄";
    if (skinId == "skin_4") return "👑";
    return "👤";
  }

  Widget _buildRankRow(QuestRank rank, int current, int max) {
    Color color;
    switch (rank) {
      case QuestRank.S: color = const Color(0xFFFFD700); break;
      case QuestRank.A: color = const Color(0xFFC0C0C0); break;
      case QuestRank.B: color = const Color(0xFFCD7F32); break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rank.name,
          style: GoogleFonts.pressStart2p(fontSize: 12, color: color, fontWeight: FontWeight.bold),
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
