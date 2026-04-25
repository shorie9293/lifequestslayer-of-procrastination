import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/game_view_model.dart';
import '../widgets/player_status_header.dart';
import '../widgets/task_card.dart';
import '../widgets/knowledge_quest_dialog.dart';
import '../widgets/fatigue_gem_popup.dart';
import '../models/task.dart';
import '../data/quiz_data.dart';
import '../utils/tutorial_keys.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Color _getRankColor(QuestRank rank) {
    switch (rank) {
      case QuestRank.S:
        return const Color(0xFF4A148C); // 深い紫 (落ち着いたSランク)
      case QuestRank.A:
        return const Color(0xFF8E3A3A); // くすんだ臙脂色（落ち着いたAランク）
      case QuestRank.B:
        return const Color(0xFF455A64); // 青灰色（落ち着いたBランク）
      default:
        return const Color(0xFF424242);
    }
  }

  void _completeTask(BuildContext context, String taskId) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);

    // 重要: この関数は非同期ダイアログ/SnackBar を多数スケジュールする。
    // タスク討伐後に ListView から当該アイテムが dispose されると `context` が unmounted になるため、
    // Navigator / ScaffoldMessenger は関数冒頭で捕捉しておく（Flutter 公式の async callback パターン）。
    final navigator = Navigator.of(context, rootNavigator: true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final wasActive = viewModel.activeTasks.any((t) => t.id == taskId);
    if (!wasActive) return;

    final result = viewModel.completeTask(taskId);

    if (result == null) {
       final stillActive = viewModel.activeTasks.any((t) => t.id == taskId);
       if (stillActive) {
          final task = viewModel.activeTasks.firstWhere((t) => t.id == taskId);
          if (task.subTasks.any((s) => !s.isCompleted)) {
             scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text("サブタスクが残っています！")),
             );
          }
       }
       return;
    }

    final leveledUp = result['leveledUp'] as bool;
    final coinsGained = result['coinsGained'] as int;
    final bonusMessages = result['bonusMessages'] as List<String>;
    final quizQuestion = result['quizQuestion'] as QuizQuestion?;
    final showFatiguePopup = result['showFatiguePopup'] as bool;
    final baseExp = result['baseExp'] as int;

    // 討伐成功メッセージ (SnackBar)
    if (bonusMessages.isNotEmpty) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Text("討伐成功！ $coinsGained 金貨を獲得しました！"),
               const SizedBox(height: 4),
               ...bonusMessages.map((msg) => Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent))),
            ]
          ),
          duration: const Duration(seconds: 4),
        )
      );
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("討伐成功！ $coinsGained 金貨を獲得しました！")),
      );
    }

    // 討伐完了エフェクト（ダイアログ）
    // navigator を事前捕捉してあるので、リスト項目が dispose されても確実に pop できる。
    bool effectClosed = false;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: DefaultTextStyle(
            style: GoogleFonts.vt323(fontSize: 80, color: Colors.amberAccent, fontWeight: FontWeight.bold),
            child: const Text('討伐完了\n💥', textAlign: TextAlign.center),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.elasticOut.transform(anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (effectClosed) return;
      effectClosed = true;
      // navigator は関数冒頭で捕捉済みなので context の mounted 状態に依存しない
      navigator.maybePop();
    });

    // 討伐完了後のダイアログチェーン（優先度順）:
    //   1. レベルアップ（討伐エフェクト後 1200ms）
    //   2. 知識クエスト（レベルアップと重ならないよう 1600ms / なければ 1200ms）
    //   3. 疲労MAXポップアップ（クイズがない場合のみ 1800ms）
    //      ※ クイズと疲労ポップアップを同日に重ねない（UXアドバイスに従い排他）

    // navigator.context は Navigator State 自体の context。リスト項目が dispose されても有効。
    final dialogContext = navigator.context;

    if (leveledUp) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (dialogContext.mounted) {
          showGeneralDialog(
            context: dialogContext,
            barrierDismissible: true,
            barrierLabel: '',
            barrierColor: Colors.black87,
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, anim1, anim2) {
              return Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B5C00), Color(0xFFFFD700), Color(0xFF7B5C00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Colors.amber, blurRadius: 32, spreadRadius: 4)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("⬆", style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text(
                          "LEVEL UP!",
                          style: GoogleFonts.pressStart2p(
                            fontSize: 24,
                            color: Colors.white,
                            shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Lv. ${viewModel.player.level} に到達！",
                          style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "次のレベルまで ${viewModel.player.expToNextLevel} EXP",
                          style: const TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF7B5C00),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text("さらなる高みへ！", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            transitionBuilder: (context, anim1, anim2, child) {
              return Transform.scale(
                scale: Curves.elasticOut.transform(anim1.value),
                child: Opacity(opacity: anim1.value.clamp(0.0, 1.0), child: child),
              );
            },
          );
        }
      });
    }

    // 知識クエストダイアログ（討伐エフェクト後 or レベルアップ後に表示）
    if (quizQuestion != null) {
      final delay = leveledUp
          ? const Duration(milliseconds: 2600) // レベルアップダイアログの後
          : const Duration(milliseconds: 1200);
      Future.delayed(delay, () {
        if (dialogContext.mounted) {
          KnowledgeQuestDialog.show(
            dialogContext,
            quest: quizQuestion,
            onCorrect: () => viewModel.awardKnowledgeBonus(quizQuestion.expBonusPercent, baseExp),
            onSkip: () {},
          );
        }
      });
    }

    // 疲労MAXポップアップ（クイズがない場合のみ・UX排他設計）
    if (showFatiguePopup && quizQuestion == null) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (dialogContext.mounted) {
          FatigueGemPopup.show(dialogContext);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final tasks = viewModel.activeTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("戦場"),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/home_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
          // Player Stats Header
          const PlayerStatusHeader(),

          // Active Tasks (Monsters)
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      "クエストがありません。\nギルドで受注してください！",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskCard(
                        task: task,
                        color: _getRankColor(task.rank),
                        onSubTaskToggle: (idx, _) => viewModel.toggleSubTask(task.id, idx),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.undo, color: Colors.grey),
                            onPressed: () {
                              viewModel.cancelTask(task.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("クエストをギルドに戻しました")),
                              );
                            },
                            tooltip: "ギルドに戻す",
                          ),
                          IconButton(
                            key: index == 0 ? TutorialKeys.battleCompleteKey : null,
                            icon: const Text('⚔️', style: TextStyle(fontSize: 24)), 
                            onPressed: () => _completeTask(context, task.id),
                            tooltip: "討伐！",
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
    );
  }
}
