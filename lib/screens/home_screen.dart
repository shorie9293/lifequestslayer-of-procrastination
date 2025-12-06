
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/game_state.dart';
import '../models/task.dart';
import 'guild_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _completeTask(BuildContext context, String taskId) {
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
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context);
    final player = gameState.player;
    final tasks = gameState.activeTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("戦場"),
        actions: [
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black12,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Lv.${player.level} 勇者", style: GoogleFonts.pressStart2p(fontSize: 16)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("S: ${tasks.where((t) => t.rank == QuestRank.S).length}/${player.questSlots[QuestRank.S] ?? 0}"),
                        Text("A: ${tasks.where((t) => t.rank == QuestRank.A).length}/${player.questSlots[QuestRank.A] ?? 0}"),
                        Text("B: ${tasks.where((t) => t.rank == QuestRank.B).length}/${player.questSlots[QuestRank.B] ?? 0}"),
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
          ),
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
                        child: ListTile(
                          leading: const Icon(Icons.bug_report, size: 40, color: Colors.white),
                          title: Text(
                            "[${task.rank.name}] ${task.title}",
                            style: GoogleFonts.vt323(fontSize: 24, color: Colors.white),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
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
                                icon: const Icon(Icons.filter_vintage, color: Colors.yellow), // Sword-like icon?
                                onPressed: () => _completeTask(context, task.id),
                                tooltip: "討伐！",
                              ),
                            ],
                          ),
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
