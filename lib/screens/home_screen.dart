import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/game_view_model.dart';
import '../widgets/player_status_header.dart';
import '../widgets/task_card.dart';
import '../models/task.dart';


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
    
    // We need to check if task still exists/active to show errors if needed
    // But completeTask handles logic.
    // If completeTask returns true (Leveled Up), we show dialog.
    // If it returns false, it might be (1) Not leveled up (Success), or (2) Blocked (Failure).
    // We can check if task is still in activeTasks to see if it was removed?
    
    final wasActive = viewModel.activeTasks.any((t) => t.id == taskId);
    if (!wasActive) return; // Already gone?

    final result = viewModel.completeTask(taskId);
    
    if (result == null) {
       // Check if task is still active (meaning it failed to complete)
       final stillActive = viewModel.activeTasks.any((t) => t.id == taskId);
       if (stillActive) {
          final task = viewModel.activeTasks.firstWhere((t) => t.id == taskId);
          if (task.subTasks.any((s) => !s.isCompleted)) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("サブタスクが残っています！")),
             );
          }
       }
       return;
    }

    final leveledUp = result['leveledUp'] as bool;
    final coinsGained = result['coinsGained'] as int;
    final bonusMessages = result['bonusMessages'] as List<String>;

    // 討伐成功メッセージ
    if (bonusMessages.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("討伐成功！ $coinsGained 金貨を獲得しました！")),
      );
    }

    if (leveledUp) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("レベルアップ！"),
          content: Text("おめでとうございます！ レベル ${viewModel.player.level} になりました！"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("やった！"),
            ),
          ],
        ),
      );
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
          if (viewModel.tutorialStep == 2)
            Container(
              color: Colors.redAccent.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                   Icon(Icons.info_outline, color: Colors.redAccent),
                   SizedBox(width: 8),
                   Expanded(child: Text("【チュートリアル】\nクエストの「討伐！」ボタンを押して完了させよう！", style: TextStyle(fontWeight: FontWeight.bold))),
                ]
              ),
            ),
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
