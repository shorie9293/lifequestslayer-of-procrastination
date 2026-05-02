import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/game_view_model.dart';
import '../screens/gem_shop_screen.dart';
import '../core/accessibility/semantic_helper.dart';
import '../core/testing/widget_keys.dart';

/// 疲労MAX到達時に表示するポップアップ（1日1回）
///
/// - 宝石が50以上あれば「即時回復」ボタンを表示
/// - 不足時は「宝石ショップへ」ボタンを表示（課金誘導を押しつけない設計）
class FatigueGemPopup {
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _FatigueGemDialog(),
    );
  }
}

class _FatigueGemDialog extends StatelessWidget {
  const _FatigueGemDialog();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GameViewModel>();
    final gems = vm.player.gems;
    final canAfford = gems >= 50;

    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_fatigue_gem',
      child: AlertDialog(
        key: AppKeys.confirmDialog,
        backgroundColor: const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.blueGrey.shade700, width: 1),
        ),
        title: const Column(
          children: [
            Text('🌙', style: TextStyle(fontSize: 40), textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text(
              '今日の冒険、お疲れ様！',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '疲労がMAXに達しました。\n今日はここまでにしましょう。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            const Text(
              '続けたい場合は宝石で疲労を回復できます',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.diamond, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '50宝石で疲労リセット',
                    style: TextStyle(
                      color: Colors.purpleAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.diamond, color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text('所持: $gems 宝石', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('今日は休む', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.diamond, size: 16),
            label: Text(canAfford ? '回復する (50💎)' : '宝石を購入する'),
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? Colors.purple[700] : Colors.blueGrey[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (canAfford) {
                final success = context.read<GameViewModel>().resetFatigueWithGems();
                Navigator.of(context).pop();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ 疲労がリセットされた！さらなる討伐へ！')),
                  );
                }
              } else {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GemShopScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
