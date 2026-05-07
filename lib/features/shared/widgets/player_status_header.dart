import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/player_avatar_section.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/rank_slot_display.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/fatigue_gauge.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/exp_progress_bar.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/badge_row.dart';

class PlayerStatusHeader extends StatelessWidget {
  const PlayerStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final player = viewModel.player;
    final activeTasks = viewModel.activeTasks;

    return SemanticHelper.container(
        testId: '${SemanticTypes.section}_player_status',
        label: 'プレイヤーステータス',
        child: Container(
          key: AppKeys.playerStatusHeader,
          padding: const EdgeInsets.all(16),
          color: Colors.black12,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: PlayerAvatarSection(player: player),
                  ),
                  RankSlotDisplay(
                    player: player,
                    activeTasks: activeTasks,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FatigueGauge(
                fatigueStatus: viewModel.fatigueStatus,
                fatigueProgress: viewModel.fatigueProgress,
                fatigueLevel: viewModel.fatigueLevel,
                dailyTasksCompleted: player.dailyTasksCompleted,
                fatigueSevereThreshold: viewModel.fatigueSevereThreshold,
              ),
              const SizedBox(height: 12),
              ExpProgressBar(player: player),
              const SizedBox(height: 10),
              BadgeRow(
                streakDays: viewModel.streakDays,
                dailyMissionProgress: viewModel.dailyMissionProgress,
                isDailyMissionComplete: viewModel.isDailyMissionComplete,
                weeklyMissionProgress: viewModel.weeklyMissionProgress,
                isWeeklyMissionComplete: viewModel.isWeeklyMissionComplete,
                dailyMissionGoal: GameViewModel.dailyMissionGoal,
                weeklyMissionGoal: GameViewModel.weeklyMissionGoal,
              ),
            ],
          ),
        ));
  }
}
