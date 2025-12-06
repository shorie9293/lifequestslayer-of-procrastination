
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/task.dart';

class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key});

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  final _controller = TextEditingController();
  QuestRank _selectedRank = QuestRank.B;

  void _addTask() {
    if (_controller.text.isEmpty) return;
    Provider.of<GameState>(context, listen: false).addTask(_controller.text, rank: _selectedRank);
    _controller.clear();
  }

  void _acceptTask(String taskId) {
    final gameState = Provider.of<GameState>(context, listen: false);
    final error = gameState.acceptTask(taskId);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("クエストを受注しました！")),
      );
    }
  }

  void _deleteTask(String taskId) {
    Provider.of<GameState>(context, listen: false).deleteTask(taskId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("クエストを破棄しました。")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = Provider.of<GameState>(context).guildTasks;

    return Scaffold(
      appBar: AppBar(title: const Text("冒険者ギルド")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                DropdownButton<QuestRank>(
                  value: _selectedRank,
                  items: QuestRank.values.map((rank) {
                    return DropdownMenuItem(
                      value: rank,
                      child: Text(rank.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedRank = value);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: "新規クエスト",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add_circle, size: 32),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text("[${task.rank.name}] ${task.title}"),
                    subtitle: const Text("状態: 未受注"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => _deleteTask(task.id),
                          tooltip: "破棄",
                        ),
                        ElevatedButton(
                          onPressed: () => _acceptTask(task.id),
                          child: const Text("受注"),
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
    );
  }
}
