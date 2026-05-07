import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';

Future<void> showLoginBonusDialog(BuildContext context, int amount) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, anim1, anim2) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('＼ 本日の賜り物 ／',
                  style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('💰 +$amount 文',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 48,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'claim_login_bonus'),
                label: 'ボーナスを受け取る',
                child: ElevatedButton(
                  key: AppKeys.tutorialReward,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[800],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ありがたき幸せ！',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: Curves.elasticOut.transform(anim1.value),
        child: child,
      );
    },
  );
}
