import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';

/// 知識クエスト設定ダイアログ
class KnowledgeQuestDialog extends StatefulWidget {
  const KnowledgeQuestDialog({super.key});

  @override
  State<KnowledgeQuestDialog> createState() => _KnowledgeQuestDialogState();
}

class _KnowledgeQuestDialogState extends State<KnowledgeQuestDialog> {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context, listen: false);
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
            'クエスト討伐後に30%の確率でクイズが出題されます。\n正解するとEXPボーナスがもらえます！',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            key: AppKeys.guildKnowledgeQuestToggle,
            title: const Text('知識クエストを有効にする'),
            subtitle: Text(
              enabled ? '有効：クエスト完了後にクイズが出題されます' : '無効：クイズは表示されません',
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
          key: AppKeys.closeButton,
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
