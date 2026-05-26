import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/player_avatar_section.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/rank_slot_display.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/fatigue_gauge.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/exp_progress_bar.dart';
import 'package:rpg_todo/features/shared/widgets/widgets/badge_row.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class PlayerStatusHeader extends StatelessWidget {
  const PlayerStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final playerVM = context.watch<PlayerViewModel>();
    final taskVM = context.watch<TaskViewModel>();
    final player = playerVM.player;
    final activeTasks = taskVM.activeTasks;

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
                fatigueStatus: playerVM.fatigueStatus,
                fatigueProgress: playerVM.fatigueProgress,
                fatigueLevel: playerVM.fatigueLevel,
                dailyTasksCompleted: player.dailyTasksCompleted,
                fatigueSevereThreshold: playerVM.fatigueSevereThreshold,
              ),
              const SizedBox(height: 12),
              ExpProgressBar(player: player),
              const SizedBox(height: 10),
              BadgeRow(
                streakDays: playerVM.streakDays,
                dailyMissionProgress: playerVM.dailyMissionProgress,
                isDailyMissionComplete: playerVM.isDailyMissionComplete,
                weeklyMissionProgress: playerVM.weeklyMissionProgress,
                isWeeklyMissionComplete: playerVM.isWeeklyMissionComplete,
                dailyMissionGoal: PlayerViewModel.dailyMissionGoal,
                weeklyMissionGoal: PlayerViewModel.weeklyMissionGoal,
              ),
            ],
          ),
        ));
  }
}
