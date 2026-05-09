import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
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
        const SnackBar(content: Text("依頼内容を入力してください")),
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
        const SnackBar(content: Text("依頼内容を入力してください")),
      );
      return;
    }

    final vm = Provider.of<GameViewModel>(context, listen: false);
    vm.addTasks(titles, _selectedRank);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${titles.length}件の依頼を登録しました（${_selectedRank.name}ランク）"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: AppKeys.bulkCreateTaskDialog,
      title: const Text("一括依頼作成"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: AppKeys.bulkCreateTaskInput,
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "依頼内容（1行に1つ）",
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
                labelText: "ランク（全タスク共通）",
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
        TextButton(
          key: AppKeys.formTaskCancel,
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey[400]),
          child: const Text("キャンセル", style: TextStyle(fontSize: 16)),
        ),
        ElevatedButton(
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
      ],
    );
  }
}
