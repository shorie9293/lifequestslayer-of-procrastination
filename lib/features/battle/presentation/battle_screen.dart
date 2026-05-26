import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/shared/widgets/player_status_header.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'widgets/battle_report_dialog.dart';
import 'widgets/particle_effect.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'package:rpg_todo/core/testing/tutorial_keys.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  Color _getRankColor(QuestRank rank) => RankColors.forRank(rank);

  void _completeTask(BuildContext context, String taskId) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);

    // 重要: この関数は非同期ダイアログ/SnackBar を多数スケジュールする。
    // タスク討伐後に ListView から当該アイテムが dispose されると `context` が unmounted になるため、
    // Navigator / ScaffoldMessenger は関数冒頭で捕捉しておく（Flutter 公式の async callback パターン）。
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final wasActive = viewModel.activeTasks.any((t) => t.id == taskId);
    if (!wasActive) return;

    // レベルアップ前のレベルを記録（completeTask 後に比較するため）
    final previousLevel = viewModel.player.level;

    final result = viewModel.completeTask(taskId);

    if (result == null) {
      final stillActive = viewModel.activeTasks.any((t) => t.id == taskId);
      if (stillActive) {
        final task = viewModel.activeTasks.firstWhere((t) => t.id == taskId);
        if (task.subTasks.any((s) => !s.isCompleted)) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text("サブ依頼が残っています！")),
          );
        }
      }
      return;
    }

    final leveledUp = result['leveledUp'] as bool;
    final coinsGained = result['coinsGained'] as int;
    final bonusMessages = result['bonusMessages'] as List<String>;
    final quizQuestion = result['quizQuestion'] as QuizQuestion?;
    final baseExp = result['baseExp'] as int;
    final isOverdueBoss = result['isOverdueBoss'] as bool? ?? false;
    final wrongAnswerPenaltyExp = result['wrongAnswerPenaltyExp'] as int? ?? 0;
    final wrongAnswerPenaltyCoins = result['wrongAnswerPenaltyCoins'] as int? ?? 0;

    // 討伐成功メッセージ (SnackBar)
    if (bonusMessages.isNotEmpty) {
          scaffoldMessenger.showSnackBar(SnackBar(
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text("見事仕留めた！ $coinsGained 文を獲得しました！"),
              const SizedBox(height: 4),
              ...bonusMessages.map((msg) => Text(msg,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.amberAccent))),
            ]),
            duration: const Duration(seconds: 4),
          ));
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("見事仕留めた！ $coinsGained 文を獲得しました！")),
      );
    }

    // 討伐完了パーティクルエフェクト → 戦果報告書（統合ダイアログ）
    // navigator を事前捕捉してあるので、リスト項目が dispose されても確実に pop できる。
    final dialogContext = navigator.context;
    bool effectClosed = false;

    void showBattleReport() {
      if (!dialogContext.mounted) return;
      final player = viewModel.player;
      // 疲労警告用の判定
      final warnThresh = viewModel.fatigueWarnThreshold;
      final severeThresh = viewModel.fatigueSevereThreshold;
      final dailyDone = player.dailyTasksCompleted;
      String? fatigueWarning;
      if (dailyDone >= severeThresh) {
        fatigueWarning = '疲労が限界に達しています。宿屋で休むことをお勧めします。';
      } else if (dailyDone >= warnThresh) {
        fatigueWarning = '疲れが溜まってきました。宿屋で一息つきませんか？';
      }

      BattleReportDialog.show(
        dialogContext,
        coinsGained: coinsGained,
        bonusMessages: bonusMessages,
        leveledUp: leveledUp,
        previousLevel: previousLevel,
        newLevel: player.level,
        currentExp: player.currentExp,
        expToNextLevel: player.expToNextLevel,
        quizQuestion: quizQuestion,
        onQuizCorrect: quizQuestion != null
            ? (q) {
                viewModel.awardKnowledgeBonus(
                    q.expBonusPercent, baseExp);
                // 刻の番人討伐時は称号チェック
                if (isOverdueBoss) {
                  viewModel.defeatTimeWarden();
                }
              }
            : null,
        onQuizWrong: (isOverdueBoss && wrongAnswerPenaltyExp > 0)
            ? () {
                viewModel.applyWrongAnswerPenalty(
                    wrongAnswerPenaltyExp, wrongAnswerPenaltyCoins);
              }
            : null,
        isOverdueBoss: isOverdueBoss,
        baseExp: baseExp,
        fatigueWarning: fatigueWarning,
        fatigueWarnThreshold: warnThresh,
        dailyTasksCompleted: dailyDone,
      );
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: ParticleBurst(
            onComplete: () {
              navigator.maybePop();
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: child);
      },
    ).then((_) {
      // エフェクトが閉じられた後に戦果報告書を表示
      if (effectClosed) return;
      effectClosed = true;
      Future.delayed(const Duration(milliseconds: 400), () {
        showBattleReport();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final tasks = viewModel.activeTasks;

    return Scaffold(
      key: AppKeys.battleScreen,
      appBar: AppBar(
        title: const Text("修練場"),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/home_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.7), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            // Player Stats Header
            const PlayerStatusHeader(),

            // Active Tasks (Monsters)
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                      key: AppKeys.battleEmptyState,
                      child: Text(
                        "依頼がありません。\n寄合所で受注してください！",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: [
                        // 今日の見積もり時間
                        if (viewModel.dailyEstimatedMinutes > 0)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            color: Colors.black26,
                            child: Row(
                              children: [
                                const Text("📊",
                                    style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Text(
                                  "今日の戦い（見積もり）: ${viewModel.dailyEstimatedMinutes}分",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                      key: AppKeys.battleActiveTaskList,
                      padding: const EdgeInsets.all(16),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return TaskCard(
                          task: task,
                          color: _getRankColor(task.rank),
                          onSubTaskToggle: (idx, _) =>
                              viewModel.toggleSubTask(task.id, idx),
                          actions: [
                            SemanticHelper.interactive(
                              testId: SemanticHelper.createTestId(
                                  SemanticTypes.button, 'cancel_task'),
                              label: '依頼を寄合所に戻す',
                              child: IconButton(
                                key: AppKeys.battleCancel,
                                icon: const Icon(Icons.undo, color: Colors.grey),
                                onPressed: () {
                                  viewModel.cancelTask(task.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("依頼を寄合所に戻しました")),
                                  );
                                },
                                tooltip: "寄合所に戻す",
                              ),
                            ),
                            SemanticHelper.interactive(
                              testId: SemanticHelper.createTestId(
                                  SemanticTypes.button, 'complete_task'),
                              label: '討つ！',
                              child: IconButton(
                                key: index == 0
                                    ? TutorialKeys.battleCompleteKey
                                    : null,
                                icon: const Text('⚔️',
                                    style: TextStyle(fontSize: 24)),
                                onPressed: () => _completeTask(context, task.id),
                                tooltip: "討つ！",
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
