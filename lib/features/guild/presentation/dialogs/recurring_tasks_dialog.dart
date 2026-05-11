import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'create_task_dialog.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 定期任務一覧ダイアログ
class RecurringTasksDialog extends StatelessWidget {
  const RecurringTasksDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final tasks = viewModel.recurringTasks;

    return AlertDialog(
      key: AppKeys.guildRecurringTasksDialog,
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
                child: Text('繰り返し設定された依頼はありません',
                    style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  String intervalText =
                      task.repeatInterval == RepeatInterval.daily ? '毎日' : '毎週';
                  if (task.repeatInterval == RepeatInterval.weekly &&
                      task.repeatWeekdays.isNotEmpty) {
                    final days = task.repeatWeekdays
                        .map((d) => ["月", "火", "水", "木", "金", "土", "日"][d - 1])
                        .join(',');
                    intervalText += ' ($days)';
                  }

                  return Card(
                    color: Colors.black45,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(task.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'ランク: ${task.rank.name} | 頻度: $intervalText\n状態: ${task.status == TaskStatus.active ? "受諾済み" : "未受注"}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SemanticHelper.interactive(
                            testId: SemanticHelper.createTestId(
                                SemanticTypes.button, 'edit_${task.id}'),
                            label: '定期任務を編集',
                            child: IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.grey, size: 20),
                              onPressed: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      CreateTaskDialog(task: task),
                                );
                              },
                            ),
                          ),
                          SemanticHelper.interactive(
                            testId: SemanticHelper.createTestId(
                                SemanticTypes.button, 'delete_${task.id}'),
                            label: '定期任務を削除',
                            child: IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.redAccent, size: 20),
                              onPressed: () {
                                viewModel.deleteTask(task.id);
                              },
                            ),
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
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'close_recurring_tasks'),
          label: '定期任務一覧を閉じる',
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ),
      ],
    );
  }
}
