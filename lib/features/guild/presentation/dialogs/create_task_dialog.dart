import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/domain/difficulty_estimator.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// クエスト作成/編集ダイアログ
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
  late List<int> _selectedWeekdays;
  late List<SubTask> _subTasks;
  final _subTaskController = TextEditingController();
  late final TextEditingController _targetTimeController;
  DateTime? _deadline;
  int? _estimatedMinutes;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleController = TextEditingController(text: t?.title ?? "");
    _selectedRank = t?.rank ?? QuestRank.B;
    _selectedRepeat = t?.repeatInterval ?? RepeatInterval.none;
    _selectedWeekdays = t != null ? List.from(t.repeatWeekdays) : [];
    _subTasks = t != null
        ? List<SubTask>.from(t.subTasks
            .map((s) => SubTask(title: s.title, isCompleted: s.isCompleted)))
        : [];
    _targetTimeController =
        TextEditingController(text: t?.targetTimeMinutes?.toString() ?? "");
    _deadline = t?.deadline;
    _updateEstimate();
    _titleController.addListener(_updateEstimate);
  }

  void _updateEstimate() {
    final title = _titleController.text;
    if (title.isEmpty) {
      setState(() => _estimatedMinutes = null);
      return;
    }
    final taskVM = Provider.of<TaskViewModel>(context, listen: false);
    setState(() {
      _estimatedMinutes = taskVM.estimateMinutes(title, _selectedRank);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subTaskController.dispose();
    _targetTimeController.dispose();
    super.dispose();
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

    final newRank = DifficultyEstimator.estimateRank(title);
    setState(() {
      _selectedRank = newRank;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("魔導書による解析: ${newRank.name}ランクと推定")),
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

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
      helpText: "完成期限を選択",
      cancelText: "キャンセル",
      confirmText: "決定",
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _saveTask() {
    if (_titleController.text.isEmpty) return;

    if (_selectedRepeat == RepeatInterval.weekly && _selectedWeekdays.isEmpty) {
      _selectedWeekdays.add(DateTime.now().weekday);
    }

    int? targetTime = int.tryParse(_targetTimeController.text);

    final taskVM = Provider.of<TaskViewModel>(context, listen: false);
    if (widget.task == null) {
      taskVM.addTask(
        _titleController.text,
        rank: _selectedRank,
        repeatInterval: _selectedRepeat,
        repeatWeekdays: _selectedWeekdays.isNotEmpty ? _selectedWeekdays : null,
        subTasks: _subTasks.isNotEmpty ? _subTasks : null,
        targetTimeMinutes: targetTime,
        deadline: _deadline,
      );
    } else {
      taskVM.editTask(
        widget.task!.id,
        _titleController.text,
        rank: _selectedRank,
        repeatInterval: _selectedRepeat,
        repeatWeekdays: _selectedWeekdays.isNotEmpty ? _selectedWeekdays : null,
        subTasks: _subTasks.isNotEmpty ? _subTasks : null,
        targetTimeMinutes: targetTime,
        deadline: _deadline,
      );
    }
    taskVM.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final playerVM = Provider.of<PlayerViewModel>(context, listen: false);
    final player = playerVM.player;

    return AlertDialog(
      key: AppKeys.formTaskDialog,
      title: Text(widget.task == null ? "新規依頼作成" : "依頼編集"),
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
                  key: AppKeys.formTaskTitle,
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: "タイトル（長文入力可）"),
                  autofocus: true,
                  maxLines: null,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: AppKeys.formTaskTargetTime,
                  controller: _targetTimeController,
                  decoration: const InputDecoration(
                    labelText: "見積もり時間（分）",
                    hintText: "例: 30",
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (_estimatedMinutes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "📖 魔導書解析: 過去の実績から約$_estimatedMinutes分と推定",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber[200],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // 完成期限（適応神書 原則③+④：Semantics + Key の二重網）
                SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'deadline_picker'),
                  label: "完成期限を選択",
                  hint: "タップして期限日を選択します",
                  child: InkWell(
                    key: AppKeys.formTaskDeadline,
                    onTap: _pickDeadline,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "完成期限",
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        _deadline != null
                            ? "${_deadline!.year}/${_deadline!.month.toString().padLeft(2, '0')}/${_deadline!.day.toString().padLeft(2, '0')}"
                            : "期限なし",
                        style: TextStyle(
                          color: _deadline != null ? Colors.white : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_deadline != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: SemanticHelper.interactive(
                      testId: SemanticHelper.createTestId(
                          SemanticTypes.button, 'deadline_clear'),
                      label: "期限をクリア",
                      child: TextButton(
                        key: AppKeys.formTaskDeadlineClear,
                        onPressed: () => setState(() => _deadline = null),
                        child: const Text("期限をクリア",
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
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
                        onChanged: (val) {
                          setState(() => _selectedRank = val!);
                          _updateEstimate();
                        },
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
                if (player.hasSkill(JobSkill.roninRepeatTask) ||
                    player.canUseSkill(Job.cleric)) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RepeatInterval>(
                    value: _selectedRepeat,
                    decoration: const InputDecoration(
                        labelText: "繰り返し (果てなき挑戦 / Cleric)"),
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
                      children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                        final isSelected = _selectedWeekdays.contains(day);
                        return FilterChip(
                          label: Text(
                              ["月", "火", "水", "木", "金", "土", "日"][day - 1]),
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
                          decoration: const InputDecoration(
                              labelText: "サブ依頼追加 (Wizard Ability)"),
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
                      decoration:
                          BoxDecoration(border: Border.all(color: Colors.grey)),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _subTasks.length,
                        itemBuilder: (context, index) => ListTile(
                          title: Text(_subTasks[index].title),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () =>
                                setState(() => _subTasks.removeAt(index)),
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
          key: AppKeys.formTaskCancel,
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
          child: const Text("キャンセル", style: TextStyle(fontSize: 16)),
        ),
        ElevatedButton(
          key: AppKeys.formTaskSubmit,
          onPressed: _saveTask,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(widget.task == null ? "作成" : "保存",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }
}
