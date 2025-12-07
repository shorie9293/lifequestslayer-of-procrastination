
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_state.dart';
import '../models/task.dart';
import '../widgets/player_status_header.dart';
import 'guild_screen.dart';
import 'temple_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool _completeTask(BuildContext context, String taskId) {
    final gameState = Provider.of<GameState>(context, listen: false);
    final leveledUp = gameState.completeTask(taskId);
    
    if (leveledUp) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("レベルアップ！"),
          content: Text("おめでとうございます！ レベル ${gameState.player.level} になりました！"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("やった！"),
            ),
          ],
        ),
      );
    }
    return leveledUp || gameState.activeTasks.every((t) => t.id != taskId);
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final tasks = gameState.activeTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("戦場"),
        actions: [
          IconButton(
            icon: const Icon(Icons.temple_buddhist),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TempleScreen()),
              );
            },
            tooltip: "神殿へ",
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GuildScreen()),
              );
            },
            tooltip: "ギルドへ行く",
          ),
        ],
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
                      return Card(
                        color: Colors.red[900],
                        child: ExpansionTile(
                          collapsedIconColor: Colors.white,
                          iconColor: Colors.white,
                          leading: const Icon(Icons.bug_report, size: 40, color: Colors.white),
                          title: Text(
                            "[${task.rank.name}] ${task.title}",
                            style: GoogleFonts.vt323(fontSize: 24, color: Colors.white),
                          ),
                          children: [
                            if (task.subTasks.isNotEmpty)
                               ...task.subTasks.asMap().entries.map((entry) {
                                 final idx = entry.key;
                                 final sub = entry.value;
                                 return ListTile(
                                   title: Text(sub.title, style: const TextStyle(color: Colors.white)),
                                   leading: Checkbox(
                                     value: sub.isCompleted,
                                     onChanged: (val) {
                                       Provider.of<GameState>(context, listen: false).toggleSubTask(task.id, idx);
                                     },
                                     checkColor: Colors.black,
                                     activeColor: Colors.white,
                                   ),
                                 );
                               }),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.undo, color: Colors.grey),
                                    onPressed: () {
                                      Provider.of<GameState>(context, listen: false).cancelTask(task.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("クエストをギルドに戻しました")),
                                      );
                                    },
                                    tooltip: "ギルドに戻す",
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.filter_vintage, color: Colors.yellow), 
                                    onPressed: () {
                                       final success = _completeTask(context, task.id);
                                       if (!success && task.subTasks.any((s) => !s.isCompleted)) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("サブタスクが残っています！")),
                                          );
                                       }
                                    },
                                    tooltip: "討伐！",
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GuildScreen()),
          );
        },
        label: const Text("ギルドへ"),
        icon: const Icon(Icons.arrow_forward),
      ),
    );
  }
}

