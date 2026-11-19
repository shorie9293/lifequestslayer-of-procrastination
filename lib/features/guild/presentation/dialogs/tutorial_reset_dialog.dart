import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// チュートリアルリセット確認ダイアログ
class TutorialResetDialog extends StatelessWidget {
  const TutorialResetDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    return AlertDialog(
      key: AppKeys.confirmDialog,
      title: const Text('導きの書をリセット'),
      content: const Text('導きの書を最初からやり直しますか？\n（ゲームデータは消えません）'),
      actions: [
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'cancel_tutorial_reset'),
          label: 'キャンセル',
          child: TextButton(
            key: AppKeys.closeButton,
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
                foregroundColor: palette.isLight
                    ? palette.onSurfaceMuted
                    : Colors.grey),
            child: const Text('キャンセル'),
          ),
        ),
        SemanticHelper.interactive(
          testId: SemanticHelper.createTestId(
              SemanticTypes.button, 'confirm_tutorial_reset'),
          label: 'チュートリアルをリセット',
          child: ElevatedButton(
            onPressed: () {
              Provider.of<SettingsViewModel>(context, listen: false).resetTutorial();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('🔄 導きの書をリセットしました')),
              );
            },
            style: ElevatedButton.styleFrom(
                // ライトでは琥珀地に白が 2.2:1。地を白が載る濃金へ落とす。
                backgroundColor: palette.isLight
                    ? palette.readable(Colors.amber[700]!)
                    : Colors.amber[700],
                foregroundColor: Colors.white),
            child: const Text('リセット'),
          ),
        ),
      ],
    );
  }
}
