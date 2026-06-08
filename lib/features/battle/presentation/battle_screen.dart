import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/widgets/player_status_header.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'widgets/battle_report_dialog.dart';
import 'widgets/particle_effect.dart';
import 'widgets/fatigue_gem_popup.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';
import 'package:rpg_todo/core/testing/tutorial_keys.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// M4禍津対策: 連打ガード用セット
final Set<String> _completingTaskIds = {};

class BattleScreen extends StatelessWidget {
  const BattleScreen({super.key});

  Color _getRankColor(QuestRank rank) => RankColors.forRank(rank);

  void _completeTask(BuildContext context, String taskId) {
    // M4禍津対策: 連打ガード。同一タスクの二重実行を防止する。
    if (_completingTaskIds.contains(taskId)) return;
    _completingTaskIds.add(taskId);

    final taskVM = context.read<TaskViewModel>();
    final playerVM = context.read<PlayerViewModel>();
    final settingsVM = context.read<SettingsViewModel>();

    // 重要: この関数は非同期ダイアログ/SnackBar を多数スケジュールする。
    // タスク討伐後に ListView から当該アイテムが dispose されると `context` が unmounted になるため、
    // Navigator / ScaffoldMessenger は関数冒頭で捕捉しておく（Flutter 公式の async callback パターン）。
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final wasActive = taskVM.activeTasks.any((t) => t.id == taskId);
    if (!wasActive) {
      _completingTaskIds.remove(taskId);
      return;
    }

    // レベルアップ前のレベルを記録（completeTask 後に比較するため）
    final previousLevel = playerVM.player.level;

    final result = taskVM.completeTask(taskId);

    if (result == null) {
      final stillActive = taskVM.activeTasks.any((t) => t.id == taskId);
      if (stillActive) {
        final task = taskVM.activeTasks.firstWhere((t) => t.id == taskId);
        if (task.subTasks.any((s) => !s.isCompleted)) {
          // UX-3: 討伐失敗時、未完了サブタスクの名前を表示
          final remaining = task.subTasks
              .where((s) => !s.isCompleted)
              .map((s) => '・${s.title}')
              .join('\n');
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text("サブクエストが残っています:\n$remaining"),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
      _completingTaskIds.remove(taskId);
      return;
    }

    // completeTask後のサイドエフェクト（GameViewModelから移行）
    settingsVM.completeTutorialStep(2);
    playerVM.checkAndResetMissions(DateTime.now());
    if (settingsVM.showJobTutorial && !settingsVM.jobTutorialCompleted) {
      settingsVM.markJobTutorialSeen();
      playerVM.addExp(50);
    }
    playerVM.save();
    taskVM.save();

    final leveledUp = result['leveledUp'] as bool;
    final coinsGained = result['coinsGained'] as int;
    final bonusMessages = result['bonusMessages'] as List<String>;
    final quizQuestion = result['quizQuestion'] as QuizQuestion?;
    final baseExp = result['baseExp'] as int;
    final isOverdueBoss = result['isOverdueBoss'] as bool? ?? false;
    final wrongAnswerPenaltyExp = result['wrongAnswerPenaltyExp'] as int? ?? 0;
    final wrongAnswerPenaltyCoins = result['wrongAnswerPenaltyCoins'] as int? ?? 0;
    final showFatiguePopup = result['showFatiguePopup'] as bool? ?? false;

    // UX-6: 戦果報告書の統合 — SnackBarを廃止し、全てのフィードバックを戦果報告書ダイアログに集約

    // 討伐完了パーティクルエフェクト → 戦果報告書（統合ダイアログ）
    // navigator を事前捕捉してあるので、リスト項目が dispose されても確実に pop できる。
    final dialogContext = navigator.context;
    bool effectClosed = false;

    Future<void> showBattleReport() async {
      if (!dialogContext.mounted) return;
      final player = playerVM.player;
      // 疲労警告用の判定
      final warnThresh = playerVM.fatigueWarnThreshold;
      final severeThresh = playerVM.fatigueSevereThreshold;
      final dailyDone = player.dailyTasksCompleted;
      String? fatigueWarning;
      if (dailyDone >= severeThresh) {
        fatigueWarning = '疲労が限界に達しています。宿屋で休むことをお勧めします。';
      } else if (dailyDone >= warnThresh) {
        fatigueWarning = '疲れが溜まってきました。宿屋で一息つきませんか？';
      }

      await BattleReportDialog.show(
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
                taskVM.awardKnowledgeBonus(
                    q.expBonusPercent, baseExp); taskVM.save();
                // 刻の番人討伐時は称号チェック
                if (isOverdueBoss) {
                  playerVM.defeatTimeWarden();
                  playerVM.save();
                }
              }
            : null,
        onQuizWrong: (isOverdueBoss && wrongAnswerPenaltyExp > 0)
            ? () {
                playerVM.applyWrongAnswerPenalty(
                    wrongAnswerPenaltyExp, wrongAnswerPenaltyCoins);
                playerVM.save();
              }
            : null,
        isOverdueBoss: isOverdueBoss,
        baseExp: baseExp,
        fatigueWarning: fatigueWarning,
        fatigueWarnThreshold: warnThresh,
        dailyTasksCompleted: dailyDone,
      );

      // UX-12: 疲労ポップアップを戦果報告書の後に表示
      // rootNavigator経由で二重遷移を防止する
      if (showFatiguePopup && dialogContext.mounted) {
        await FatigueGemPopup.show(dialogContext);
      }
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
              // M5禍津対策: maybePop() は最上面のルートを閉じてしまう。
              // 無関係なダイアログ（知識クエスト等）を閉じないよう、
              // ParticleBurst のコンテキストで明示的に pop する。
              Navigator.of(ctx).pop();
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
      // ガード解除: ダイアログ連鎖完了後に解放
      _completingTaskIds.remove(taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskVM = context.watch<TaskViewModel>();
    final tasks = taskVM.activeTasks;

    // UX-9: save()失敗時のSnackBar表示コールバック
    if (taskVM.onSaveError == null) {
      final messenger = ScaffoldMessenger.of(context);
      taskVM.onSaveError = () {
        messenger.showSnackBar(
          const SnackBar(content: Text("タスクデータの保存に失敗しました")),
        );
      };
    }
    final playerVM = context.read<PlayerViewModel>();
    if (playerVM.onSaveError == null) {
      final messenger = ScaffoldMessenger.of(context);
      playerVM.onSaveError = () {
        messenger.showSnackBar(
          const SnackBar(content: Text("プレイヤーデータの保存に失敗しました")),
        );
      };
    }

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
                        "クエストがありません。\n寄合所で受注してください！",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: [
                        // 今日の見積もり時間
                        if (taskVM.dailyEstimatedMinutes > 0)
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
                                  "今日の戦い（見積もり）: ${taskVM.dailyEstimatedMinutes}分",
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
                          onSubTaskToggle: (idx, _) {
                            taskVM.toggleSubTask(task.id, idx);
                            taskVM.save();
                          },
                          actions: [
                            SemanticHelper.interactive(
                              testId: SemanticHelper.createTestId(
                                  SemanticTypes.button, 'cancel_task'),
                              label: 'クエストを寄合所に戻す',
                              child: IconButton(
                                key: AppKeys.battleCancel,
                                icon: const Icon(Icons.undo, color: Colors.grey),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      key: AppKeys.confirmDialog,
                                      title: const Text("クエストを戻す"),
                                      content: const Text("このクエストを寄合所に戻しますか？"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("キャンセル"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            taskVM.cancelTask(task.id); taskVM.save();
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                  content: Text("クエストを寄合所に戻しました")),
                                            );
                                          },
                                          child: const Text("戻す"),
                                        ),
                                      ],
                                    ),
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
