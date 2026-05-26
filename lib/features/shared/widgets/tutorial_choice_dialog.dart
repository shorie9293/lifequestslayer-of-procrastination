import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

Future<void> showTutorialChoiceDialog(
    BuildContext context, VoidCallback onDismiss) {
  final settingsVM = Provider.of<SettingsViewModel>(context, listen: false);
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Text('📜', style: TextStyle(fontSize: 24)),
          SizedBox(width: 8),
          Text('チュートリアル'),
        ],
      ),
      content: const Text('冒険の基本を学びますか？\n（初めてプレイする方は「学ぶ」を推奨）'),
      actions: [
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'skip_tutorial_choice'),
          label: 'チュートリアルをスキップ',
          child: TextButton(
            key: AppKeys.tutorialSkip,
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              await settingsVM.skipTutorial();
              navigator.pop();
              onDismiss();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('スキップ'),
          ),
        ),
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'start_tutorial'),
          label: 'チュートリアルを学ぶ',
          child: ElevatedButton(
            key: AppKeys.tutorialUnderstood,
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              await settingsVM.markTutorialChoiceMade();
              navigator.pop();
              onDismiss();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('学ぶ'),
          ),
        ),
      ],
    ),
  );
}
