import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';

Future<void> showStreakRewardDialog(
    BuildContext context, int reward, int streakDays) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 600),
    pageBuilder: (context, anim1, anim2) {
      final milestoneEmoji = streakDays >= 30
          ? '⭐'
          : streakDays >= 14
              ? '🌟'
              : streakDays >= 7
                  ? '🔥'
                  : '✨';
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: streakDays >= 30
                    ? [
                        Colors.purple[900]!,
                        Colors.amber[700]!,
                        Colors.purple[900]!
                      ]
                    : [
                        Colors.orange[900]!,
                        Colors.deepOrange[700]!,
                        Colors.orange[900]!
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: streakDays >= 7 ? Colors.orange : Colors.amber,
                  blurRadius: streakDays >= 30 ? 48 : 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(milestoneEmoji,
                    style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(
                  '$streakDays日連続ログイン！',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '💰 +$reward 文',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 40,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                SemanticHelper.interactive(
                  testId: SemanticHelper.createTestId(
                      SemanticTypes.button, 'claim_streak_reward'),
                  label: 'ストリーク報酬を受け取る',
                  child: ElevatedButton(
                    key: AppKeys.closeButton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.orange[900],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('受け取る！',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return Transform.scale(
        scale: Curves.elasticOut.transform(anim1.value),
        child: Opacity(opacity: anim1.value.clamp(0.0, 1.0), child: child),
      );
    },
  );
}
