import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/game_view_model.dart';
import '../models/task.dart';
import '../models/player.dart';
import '../widgets/player_status_header.dart';
import '../widgets/task_card.dart';
import '../widgets/help_dialog.dart';

class GuildScreen extends StatelessWidget {
  const GuildScreen({super.key});

  Color _getRankColor(QuestRank rank) {
    switch (rank) {
      case QuestRank.S:
        return const Color(0xFF4A148C); // 深い紫
      case QuestRank.A:
        return const Color(0xFF8E3A3A); // くすんだ臙脂色
      case QuestRank.B:
        return const Color(0xFF455A64); // 青灰色
      default:
        return const Color(0xFF424242);
    }
  }

  void _showCreateTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateTaskDialog(),
    );
  }

  void _showEditTaskDialog(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (context) => CreateTaskDialog(task: task),
    );
  }

  void _acceptTask(BuildContext context, String taskId) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    final error = viewModel.acceptTask(taskId);
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
    Provider.of<GameViewModel>(context, listen: false).deleteTask(taskId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("クエストを破棄しました。")),
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

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final tasks = viewModel.guildTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("冒険者ギルド"),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'アプリについて',
            onPressed: () => showHelpDialog(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/guild_bg.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            const PlayerStatusHeader(),
          if (viewModel.tutorialStep == 0)
            Container(
              color: Colors.blueAccent.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                   Icon(Icons.info_outline, color: Colors.blueAccent),
                   SizedBox(width: 8),
                   Expanded(child: Text("【チュートリアル】\n右下の「＋」ボタンを押して、最初のクエストを登録しよう！", style: TextStyle(fontWeight: FontWeight.bold))),
                ]
              ),
            ),
          if (viewModel.tutorialStep == 1)
            Container(
              color: Colors.blueAccent.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                   Icon(Icons.info_outline, color: Colors.blueAccent),
                   SizedBox(width: 8),
                   Expanded(child: Text("【チュートリアル】\n登録したクエストの「受注」ボタンを押そう！", style: TextStyle(fontWeight: FontWeight.bold))),
                ]
              ),
            ),
          if (viewModel.tutorialStep == 2)
            Container(
              color: Colors.orangeAccent.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                   Icon(Icons.info_outline, color: Colors.orangeAccent),
                   SizedBox(width: 8),
                   Expanded(child: Text("【チュートリアル】\nクエストを受注した！下のメニューから「戦場」へ移動しよう！", style: TextStyle(fontWeight: FontWeight.bold))),
                ]
              ),
            ),
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text("クエスト依頼はありません。", style: TextStyle(fontSize: 18, color: Colors.grey)))
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskCard(
                        task: task,
                        color: _getRankColor(task.rank),
                        subtitle: _getTaskDetails(task),
                        actions: [
                           TextButton(
                             onPressed: () => _showEditTaskDialog(context, task),
                             child: const Text("編集", style: TextStyle(color: Colors.grey)),
                           ),
                           TextButton(
                             onPressed: () => _deleteTask(context, task.id),
                             child: const Text("破棄", style: TextStyle(color: Colors.grey)),
                           ),
                           const SizedBox(width: 8),
                           ElevatedButton(
                             onPressed: () => _acceptTask(context, task.id),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: Colors.amber[700], // 目立つ落ち着いた色
                               foregroundColor: Colors.white,
                               textStyle: const TextStyle(fontWeight: FontWeight.bold),
                             ),
                             child: const Text("受注"),
                           ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTaskDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CreateTaskDialog extends StatefulWidget {
  final Task? task;
  const CreateTaskDialog({super.key, this.task});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  late final TextEditingController _titleController;
  late QuestRank _selectedRank;
  late RepeatInterval _selectedRepeat;
  late List<int> _selectedWeekdays; // 1=Mon
  late List<SubTask> _subTasks;
  final _subTaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? "");
    _selectedRank = t?.rank ?? QuestRank.B;
    _selectedRepeat = t?.repeatInterval ?? RepeatInterval.none;
    _selectedWeekdays = t != null ? List.from(t.repeatWeekdays) : [];
    _subTasks = t != null ? List<SubTask>.from(t.subTasks.map((s) => SubTask(title: s.title, isCompleted: s.isCompleted))) : [];
  }

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
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    final player = viewModel.player;

    return AlertDialog(
      title: Text(widget.task == null ? "新規クエスト作成" : "クエスト編集"),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
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
            if (player.canUseSkill(Job.cleric)) ...[
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
            if (player.canUseSkill(Job.wizard)) ...[
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
          child: const Text("キャンセル", style: TextStyle(fontSize: 16)),
        ),
        ElevatedButton(
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(widget.task == null ? "作成" : "保存", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _saveTask() {
    if (_titleController.text.isEmpty) return;
    
    if (_selectedRepeat == RepeatInterval.weekly && _selectedWeekdays.isEmpty) {
      _selectedWeekdays.add(DateTime.now().weekday);
    }

    final vm = Provider.of<GameViewModel>(context, listen: false);
    if (widget.task == null) {
      vm.addTask(
        _titleController.text,
        rank: _selectedRank,
        repeatInterval: _selectedRepeat,
        repeatWeekdays: _selectedWeekdays.isNotEmpty ? _selectedWeekdays : null,
        subTasks: _subTasks.isNotEmpty ? _subTasks : null,
      );
    } else {
      vm.editTask(
        widget.task!.id,
        _titleController.text,
        rank: _selectedRank,
        repeatInterval: _selectedRepeat,
        repeatWeekdays: _selectedWeekdays.isNotEmpty ? _selectedWeekdays : null,
        subTasks: _subTasks.isNotEmpty ? _subTasks : null,
      );
    }
    Navigator.pop(context);
  }
}
