import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/game_view_model.dart';
import '../widgets/player_status_header.dart';
import '../widgets/task_card.dart';


class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _completeTask(BuildContext context, String taskId) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    
    // We need to check if task still exists/active to show errors if needed
    // But completeTask handles logic.
    // If completeTask returns true (Leveled Up), we show dialog.
    // If it returns false, it might be (1) Not leveled up (Success), or (2) Blocked (Failure).
    // We can check if task is still in activeTasks to see if it was removed?
    
    final wasActive = viewModel.activeTasks.any((t) => t.id == taskId);
    if (!wasActive) return; // Already gone?

    final leveledUp = viewModel.completeTask(taskId);
    
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
    } else {
       // Check if task is still active (meaning it failed to complete)
       final stillActive = viewModel.activeTasks.any((t) => t.id == taskId);
       if (stillActive) {
          // Why did it fail?
          final task = viewModel.activeTasks.firstWhere((t) => t.id == taskId);
          if (task.subTasks.any((s) => !s.isCompleted)) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("サブタスクが残っています！")),
             );
          }
       }
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
      body: Column(
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
                      style: GoogleFonts.vt323(fontSize: 24, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskCard(
                        task: task,
                        color: Colors.red[900],
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
                            icon: const Icon(Icons.filter_vintage, color: Colors.yellow), 
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
    );
  }
}
