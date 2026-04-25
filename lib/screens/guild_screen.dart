import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/game_view_model.dart';
import '../models/task.dart';
import '../models/player.dart';
import '../utils/tutorial_keys.dart';
import '../widgets/player_status_header.dart';
import '../widgets/task_card.dart';
import '../widgets/help_dialog.dart';
import '../services/notification_service.dart';

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

  void _showFontSizeDialog(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    double current = viewModel.fontSizeScale;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.text_fields, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('文字サイズ'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fontSizeOption(ctx, setState, viewModel, '大', 1.2, current),
                  _fontSizeOption(ctx, setState, viewModel, '中', 1.0, current),
                  _fontSizeOption(ctx, setState, viewModel, '小', 0.85, current),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _fontSizeOption(BuildContext ctx, StateSetter setState, GameViewModel viewModel, String label, double value, double current) {
    return RadioListTile<double>(
      title: Text('$label  (Abc あいう)', style: TextStyle(fontSize: 14 * value / 1.0)),
      value: value,
      groupValue: current,
      onChanged: (v) {
        if (v != null) {
          setState(() => current = v);
          viewModel.setFontSizeScale(v);
        }
      },
    );
  }

  void _showTutorialResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('チュートリアルをリセット'),
        content: const Text('チュートリアルを最初からやり直しますか？\n（ゲームデータは消えません）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<GameViewModel>(ctx, listen: false).resetTutorial();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔄 チュートリアルをリセットしました')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.white),
            child: const Text('リセット'),
          ),
        ],
      ),
    );
  }

  void _showKnowledgeQuestSettingDialog(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final enabled = viewModel.isKnowledgeQuestEnabled;
            return AlertDialog(
              title: const Row(
                children: [
                  Text('📚', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 8),
                  Text('知識クエスト設定'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'タスク討伐後に30%の確率でクイズが出題されます。\n正解するとEXPボーナスがもらえます！',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('知識クエストを有効にする'),
                    subtitle: Text(
                      enabled ? '有効：タスク完了後にクイズが出題されます' : '無効：クイズは表示されません',
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? Colors.green[700] : Colors.grey,
                      ),
                    ),
                    value: enabled,
                    activeColor: Colors.amber[700],
                    onChanged: (v) {
                      viewModel.setKnowledgeQuestEnabled(v);
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('閉じる'),
                ),
              ],
            );
          },
        );
      },
    );
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
        const SnackBar(content: Text("⚔️ 出発！武運を祈る！")),
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

  void _showRecurringTasksDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const RecurringTasksDialog(),
    );
  }


  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final tasks = viewModel.guildTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text("冒険者ギルド"),
        actions: [
          if (viewModel.player.canUseSkill(Job.cleric))
            IconButton(
              icon: const Icon(Icons.loop),
              tooltip: '繰り返し任務一覧',
              onPressed: () => _showRecurringTasksDialog(context),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onSelected: (value) {
              if (value == 'help') {
                showHelpDialog(context);
              } else if (value == 'notification') {
                showDialog(
                  context: context,
                  builder: (context) => const NotificationSettingsDialog(),
                );
              } else if (value == 'font_size') {
                _showFontSizeDialog(context);
              } else if (value == 'knowledge_quest') {
                _showKnowledgeQuestSettingDialog(context);
              } else if (value == 'tutorial_reset') {
                _showTutorialResetDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [Icon(Icons.help_outline, color: Colors.black54), SizedBox(width: 8), Text('遊び方・ヘルプ')],
                ),
              ),
              const PopupMenuItem(
                value: 'notification',
                child: Row(
                  children: [Icon(Icons.notifications_none, color: Colors.black54), SizedBox(width: 8), Text('通知設定')],
                ),
              ),
              const PopupMenuItem(
                value: 'font_size',
                child: Row(
                  children: [Icon(Icons.text_fields, color: Colors.black54), SizedBox(width: 8), Text('文字サイズ')],
                ),
              ),
              const PopupMenuItem(
                value: 'knowledge_quest',
                child: Row(
                  children: [Icon(Icons.quiz_outlined, color: Colors.black54), SizedBox(width: 8), Text('知識クエスト設定')],
                ),
              ),
              const PopupMenuItem(
                value: 'tutorial_reset',
                child: Row(
                  children: [Icon(Icons.replay, color: Colors.black54), SizedBox(width: 8), Text('チュートリアルをリセット')],
                ),
              ),
            ],
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

          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text("🏰", style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(
                          "まだクエストが届いていない。",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "右下の ＋ から最初の依頼を登録しよう！",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80), // FABとの被り対策
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
                               key: index == 0 ? TutorialKeys.acceptTaskKey : null,
                               onPressed: () => _acceptTask(context, task.id),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: Colors.amber[700],
                                 foregroundColor: Colors.white,
                                 textStyle: const TextStyle(fontWeight: FontWeight.bold),
                               ),
                               child: const Text("出発する"),
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
        key: TutorialKeys.fabKey,
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
  late final TextEditingController _targetTimeController;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? "");
    _selectedRank = t?.rank ?? QuestRank.B;
    _selectedRepeat = t?.repeatInterval ?? RepeatInterval.none;
    _selectedWeekdays = t != null ? List.from(t.repeatWeekdays) : [];
    _subTasks = t != null ? List<SubTask>.from(t.subTasks.map((s) => SubTask(title: s.title, isCompleted: s.isCompleted))) : [];
    _targetTimeController = TextEditingController(text: t?.targetTimeMinutes?.toString() ?? "");
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

  void _autoEstimateRank() {
    final title = _titleController.text;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("先にタイトルを入力してください")),
      );
      return;
    }

    QuestRank newRank = QuestRank.B;
    int length = title.length;

    if (length > 30 || title.contains("実装") || title.contains("開発") || title.contains("会議") || title.contains("資料")) {
      newRank = QuestRank.A;
    } else if (length > 15 || title.contains("作成") || title.contains("買い物") || title.contains("連絡")) {
      newRank = QuestRank.B;
    }

    if (title.contains("本番") || title.contains("デプロイ") || title.contains("リリース") || title.contains("重要")) {
      newRank = QuestRank.S;
    }

    setState(() {
      _selectedRank = newRank;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("魔導書による解析: ${newRank.name}ランクと推定")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
    final player = viewModel.player;

    return AlertDialog(
      title: Text(widget.task == null ? "新規クエスト作成" : "クエスト編集"),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        child: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "タイトル（長文入力可）"),
              autofocus: true,
              maxLines: null, // 複数行対応
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _targetTimeController,
              decoration: const InputDecoration(
                labelText: "目標時間（分）",
                hintText: "例: 30 (時間内にクリアでボーナス)",
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: DropdownButtonFormField<QuestRank>(
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
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _autoEstimateRank,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text("魔導書で解析"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
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

    int? targetTime = int.tryParse(_targetTimeController.text);

    final vm = Provider.of<GameViewModel>(context, listen: false);
    if (widget.task == null) {
      vm.addTask(
        _titleController.text,
        rank: _selectedRank,
        repeatInterval: _selectedRepeat,
        repeatWeekdays: _selectedWeekdays.isNotEmpty ? _selectedWeekdays : null,
        subTasks: _subTasks.isNotEmpty ? _subTasks : null,
        targetTimeMinutes: targetTime,
      );
    } else {
      vm.editTask(
        widget.task!.id,
        _titleController.text,
        rank: _selectedRank,
        repeatInterval: _selectedRepeat,
        repeatWeekdays: _selectedWeekdays.isNotEmpty ? _selectedWeekdays : null,
        subTasks: _subTasks.isNotEmpty ? _subTasks : null,
        targetTimeMinutes: targetTime,
      );
    }
    Navigator.pop(context);
  }
}

// ─── 繰り返しタスク一覧ダイアログ ───────────────────────────────────────────

class RecurringTasksDialog extends StatelessWidget {
  const RecurringTasksDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final tasks = viewModel.recurringTasks;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.loop, color: Colors.cyan),
          SizedBox(width: 8),
          Text('定期任務一覧'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: tasks.isEmpty
            ? const Center(
                child: Text('繰り返し設定されたタスクはありません', style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  String intervalText = task.repeatInterval == RepeatInterval.daily ? '毎日' : '毎週';
                  if (task.repeatInterval == RepeatInterval.weekly && task.repeatWeekdays.isNotEmpty) {
                    final days = task.repeatWeekdays.map((d) => ["月", "火", "水", "木", "金", "土", "日"][d - 1]).join(',');
                    intervalText += ' ($days)';
                  }
                  
                  return Card(
                    color: Colors.black45,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'ランク: ${task.rank.name} | 頻度: $intervalText\n状態: ${task.status == TaskStatus.active ? "受諾済み" : "未受注"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                            onPressed: () {
                              Navigator.pop(context);
                              showDialog(
                                context: context,
                                builder: (context) => CreateTaskDialog(task: task),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              viewModel.deleteTask(task.id);
                            },
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}


// ─── 通知設定ダイアログ ───────────────────────────────────────────

class NotificationSettingsDialog extends StatefulWidget {
  const NotificationSettingsDialog({super.key});

  @override
  State<NotificationSettingsDialog> createState() =>
      _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState
    extends State<NotificationSettingsDialog> {
  final _service = NotificationService();

  bool _enabled = true;
  int _morningHour = 8;
  int _morningMinute = 0;
  int _eveningHour = 21;
  int _eveningMinute = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isEnabled();
    final mh = await _service.getMorningHour();
    final mm = await _service.getMorningMinute();
    final eh = await _service.getEveningHour();
    final em = await _service.getEveningMinute();
    setState(() {
      _enabled = enabled;
      _morningHour = mh;
      _morningMinute = mm;
      _eveningHour = eh;
      _eveningMinute = em;
      _loading = false;
    });
  }

  Future<void> _pickTime({required bool isMorning}) async {
    final initial = TimeOfDay(
      hour: isMorning ? _morningHour : _eveningHour,
      minute: isMorning ? _morningMinute : _eveningMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isMorning) {
        _morningHour = picked.hour;
        _morningMinute = picked.minute;
      } else {
        _eveningHour = picked.hour;
        _eveningMinute = picked.minute;
      }
    });
  }

  Future<void> _save() async {
    final granted = await _service.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知の許可が得られませんでした')),
      );
      return;
    }
    await _service.saveSettings(
      enabled: _enabled,
      morningHour: _morningHour,
      morningMinute: _morningMinute,
      eveningHour: _eveningHour,
      eveningMinute: _eveningMinute,
    );
    await _service.scheduleAll();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_enabled ? '通知を設定しました！' : '通知をOFFにしました'),
        ),
      );
    }
  }

  String _fmt(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.notifications_active, color: Colors.amber),
          SizedBox(width: 8),
          Text('通知設定'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            title: const Text('通知を有効にする'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            enabled: _enabled,
            leading: const Text('☀️', style: TextStyle(fontSize: 22)),
            title: const Text('朝の伝令'),
            subtitle: const Text('「本日の依頼書が届いておるぞ！」'),
            trailing: TextButton(
              onPressed: _enabled ? () => _pickTime(isMorning: true) : null,
              child: Text(
                _fmt(_morningHour, _morningMinute),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            enabled: _enabled,
            leading: const Text('🍺', style: TextStyle(fontSize: 22)),
            title: const Text('夜の催促'),
            subtitle: const Text('「討伐報告を忘れるでないぞ！」'),
            trailing: TextButton(
              onPressed: _enabled ? () => _pickTime(isMorning: false) : null,
              child: Text(
                _fmt(_eveningHour, _eveningMinute),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.white,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
