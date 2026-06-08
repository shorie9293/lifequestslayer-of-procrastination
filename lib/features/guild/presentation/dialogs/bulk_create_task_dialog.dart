import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;
/// 一括クエスト作成ダイアログ
/// 複数のタスクを一度に登録するためのテキストエリアとランクセレクターを提供する。
class BulkCreateTaskDialog extends StatefulWidget {
  const BulkCreateTaskDialog({super.key});

  @override
  State<BulkCreateTaskDialog> createState() => _BulkCreateTaskDialogState();
}

class _BulkCreateTaskDialogState extends State<BulkCreateTaskDialog> {
  final _controller = TextEditingController();
  late QuestRank _selectedRank;

  @override
  void initState() {
    super.initState();
    _selectedRank = QuestRank.B;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("クエスト内容を入力してください")),
      );
      return;
    }

    // 空行・空白のみの行を除去してタイトルリストを作成
    final titles = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (titles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("クエスト内容を入力してください")),
      );
      return;
    }

    final taskVM = Provider.of<TaskViewModel>(context, listen: false);
    final settingsVM = context.read<SettingsViewModel>();
    taskVM.addTasks(titles, _selectedRank);
    settingsVM.completeTutorialStep(0);
    taskVM.save();

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${titles.length}件のクエストを登録しました（${_selectedRank.name}ランク）"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: AppKeys.bulkCreateTaskDialog,
      title: const Text("一括クエスト登録"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: AppKeys.bulkCreateTaskInput,
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "クエスト内容（1行に1つ）",
                hintText: "書類作成\n買い物\n報告書提出",
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
              minLines: 4,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<QuestRank>(
              key: AppKeys.bulkCreateTaskRank,
              value: _selectedRank,
              decoration: const InputDecoration(
                labelText: "ランク（全クエスト共通）",
                border: OutlineInputBorder(),
              ),
              items: QuestRank.values.map((rank) {
                return DropdownMenuItem(
                  value: rank,
                  child: Text(rank.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRank = val);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'cancel_bulk_create'),
          label: '一括作成をキャンセル',
          child: TextButton(
            key: AppKeys.formTaskCancel,
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
            child: const Text("キャンセル", style: TextStyle(fontSize: 16)),
          ),
        ),
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'submit_bulk_create'),
          label: '一括登録する',
          child: ElevatedButton(
            key: AppKeys.bulkCreateTaskSubmit,
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("一括登録",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
