import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_state.dart';
import '../models/task.dart';
import '../models/player.dart';
import 'home_screen.dart';

class GuildScreen extends StatelessWidget {
  const GuildScreen({super.key});

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateTaskDialog(),
    );
  }

  void _acceptTask(BuildContext context, String taskId) {
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

  void _deleteTask(BuildContext context, String taskId) {
    Provider.of<GameState>(context, listen: false).deleteTask(taskId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("クエストを破棄しました。")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = Provider.of<GameState>(context).guildTasks;
    final player = Provider.of<GameState>(context).player;

    return Scaffold(
      appBar: AppBar(
        title: const Text("冒険者ギルド"),
        actions: [
          IconButton(
            icon: const Icon(Icons.map), // Battle icon
            onPressed: () {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            },
            tooltip: "戦場へ",
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text("クエスト依頼はありません。"))
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ExpansionTile(
                          title: Text("[${task.rank.name}] ${task.title}"),
                          subtitle: Text(_getTaskDetails(task)),
                          children: [
                             if (task.subTasks.isNotEmpty)
                                ...task.subTasks.map((s) => ListTile(
                                  title: Text(s.title),
                                  leading: const Icon(Icons.check_box_outline_blank, size: 16),
                                  dense: true,
                                )),
                             Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.end,
                                 children: [
                                   TextButton(
                                     onPressed: () => _deleteTask(context, task.id),
                                     child: const Text("破棄", style: TextStyle(color: Colors.grey)),
                                   ),
                                   const SizedBox(width: 8),
                                   ElevatedButton(
                                     onPressed: () => _acceptTask(context, task.id),
                                     child: const Text("受注"),
                                   ),
                                 ],
                               ),
                             )
                          ]
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getTaskDetails(Task task) {
    String details = "状態: 未受注";
    if (task.repeatInterval != RepeatInterval.none) {
      details += " | 繰り返し: ${task.repeatInterval.name}";
    }
    if (task.subTasks.isNotEmpty) {
      details += " | サブタスク: ${task.subTasks.length}個";
    }
    return details;
  }
}

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({super.key});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _titleController = TextEditingController();
  QuestRank _selectedRank = QuestRank.B;
  RepeatInterval _selectedRepeat = RepeatInterval.none;
  final List<int> _selectedWeekdays = []; // 1=Mon
  final List<SubTask> _subTasks = [];
  final _subTaskController = TextEditingController();

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeekdays.contains(day)) {
        _selectedWeekdays.remove(day);
      } else {
        _selectedWeekdays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = Provider.of<GameState>(context, listen: false);
    final job = gameState.player.currentJob;

    return AlertDialog(
      title: const Text("新規クエスト作成"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "タイトル"),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<QuestRank>(
              value: _selectedRank,
              decoration: const InputDecoration(labelText: "ランク"),
              items: QuestRank.values.map((rank) {
                return DropdownMenuItem(
                  value: rank,
                  child: Text(rank.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedRank = val!),
            ),
            if (job == Job.cleric) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<RepeatInterval>(
                value: _selectedRepeat,
                decoration: const InputDecoration(labelText: "繰り返し (Cleric Ability)"),
                items: RepeatInterval.values.map((r) {
                  return DropdownMenuItem(
                    value: r,
                    child: Text(r.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedRepeat = val!),
              ),
              if (_selectedRepeat == RepeatInterval.weekly) ...[
                const SizedBox(height: 8),
                const Text("曜日指定"),
                Wrap(
                  spacing: 4,
                  children: [1,2,3,4,5,6,7].map((day) {
                    final isSelected = _selectedWeekdays.contains(day);
                    return FilterChip(
                      label: Text(["月","火","水","木","金","土","日"][day - 1]),
                      selected: isSelected,
                      onSelected: (_) => _toggleWeekday(day),
                    );
                  }).toList(),
                )
              ]
            ],
            if (job == Job.wizard) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subTaskController,
                      decoration: const InputDecoration(labelText: "サブタスク追加 (Wizard Ability)"),
                      onSubmitted: (_) => _addSubTask(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addSubTask,
                  )
                ],
              ),
              if (_subTasks.isNotEmpty)
                Container(
                  height: 100,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _subTasks.length,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(_subTasks[index].title),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => setState(() => _subTasks.removeAt(index)),
                      ),
                      dense: true,
                    ),
                  ),
                ),
            ]
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("キャンセル"),
        ),
        ElevatedButton(
          onPressed: _addTask,
          child: const Text("作成"),
        ),
      ],
    );
  }

  void _addSubTask() {
    if (_subTaskController.text.isNotEmpty) {
      setState(() {
        _subTasks.add(SubTask(title: _subTaskController.text));
        _subTaskController.clear();
      });
    }
  }

  void _addTask() {
    if (_titleController.text.isEmpty) return;
    
    // For weekly, ensure at least one day selected if weekly is chosen, default to Today if empty? 
    // Or just let it be empty (never shows up?). Let's default to Today if empty and Weekly.
    if (_selectedRepeat == RepeatInterval.weekly && _selectedWeekdays.isEmpty) {
      _selectedWeekdays.add(DateTime.now().weekday);
    }

    Provider.of<GameState>(context, listen: false).addTask(
      _titleController.text,
      rank: _selectedRank,
      repeatInterval: _selectedRepeat,
      repeatWeekdays: _selectedWeekdays.isNotEmpty ? _selectedWeekdays : null,
      subTasks: _subTasks.isNotEmpty ? _subTasks : null,
    );
    Navigator.pop(context);
  }
}
