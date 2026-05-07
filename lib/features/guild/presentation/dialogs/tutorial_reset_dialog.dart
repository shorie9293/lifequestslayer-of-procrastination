import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';

/// チュートリアルリセット確認ダイアログ
class TutorialResetDialog extends StatelessWidget {
  const TutorialResetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: AppKeys.confirmDialog,
      title: const Text('導きの書をリセット'),
      content: const Text('導きの書を最初からやり直しますか？\n（ゲームデータは消えません）'),
      actions: [
        TextButton(
          key: AppKeys.closeButton,
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Provider.of<GameViewModel>(context, listen: false).resetTutorial();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('🔄 導きの書をリセットしました')),
            );
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white),
          child: const Text('リセット'),
        ),
      ],
    );
  }
}
