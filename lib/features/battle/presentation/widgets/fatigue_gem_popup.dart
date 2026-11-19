import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/presentation/gem_shop_screen.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 暗色の塗りボタン（purple 700 / blueGrey 700 等）の上の前景。
///
/// パレットは「面の上の文字」を解決する道具で、塗りボタンの上は明度テーマに
/// 依らず白が正しい（実測 7:1 前後）。パレットに白トークンが無いため、
/// 塗り専用の前景としてここに固定する。
const Color _onFilledButton = Color(0xFFFFFFFF);

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
    final palette = GamePalette.of(context);
    final playerVM = context.watch<PlayerViewModel>();
    final gems = playerVM.player.gems;
    final canAfford = gems >= 50;

    return SemanticHelper.container(
      testId: '${SemanticTypes.dialog}_fatigue_gem',
      child: AlertDialog(
        key: AppKeys.confirmDialog,
        // ダークは従来の暗幕色のまま、ライトはテーマ既定の明るい面へ。
        backgroundColor: palette.isLight ? null : const Color(0xFF1C1C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.blueGrey.shade700, width: 1),
        ),
        title: Column(
          children: [
            const Text('🌙',
                style: TextStyle(fontSize: 40), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              '今日の冒険、お疲れ様！',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: palette.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '疲労がMAXに達しました。\n今日はここまでにしましょう。',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: palette.onSurfaceMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Divider(color: palette.border),
            const SizedBox(height: 12),
            Text(
              '続けたい場合は宝石で疲労を回復できます',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: palette.onSurfaceFaint, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.diamond,
                      color: palette.readable(Colors.purpleAccent), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '50宝石で疲労リセット',
                    style: TextStyle(
                      color: palette.readable(Colors.purpleAccent),
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
                Icon(Icons.diamond,
                    color: palette.onSurfaceFaintest, size: 14),
                const SizedBox(width: 4),
                Text('所持: $gems 宝石',
                    style:
                        TextStyle(color: palette.onSurfaceFaint, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'rest_today'),
            label: '今日は休む',
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('今日は休む',
                  style: TextStyle(color: palette.onSurfaceFaint)),
            ),
          ),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'recover_fatigue'),
            label: canAfford ? '50宝石で疲労回復' : '宝石を購入する',
            child: ElevatedButton.icon(
              icon: const Icon(Icons.diamond, size: 16),
              label: Text(canAfford ? '回復する (50💎)' : '宝石を購入する'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canAfford ? Colors.purple[700] : Colors.blueGrey[700],
                foregroundColor: _onFilledButton,
              ),
              onPressed: () {
                if (canAfford) {
                  final shopVM = context.read<ShopViewModel>();
                  final success = shopVM.resetFatigueWithGems();
                  if (success) { context.read<PlayerViewModel>().save(); }
                  Navigator.of(context).pop();
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('⚡ 疲労がリセットされた！さらなる討伐へ！')),
                    );
                  }
                } else {
                  // UX-12: 二重遷移防止 — pop前にrootNavigatorを捕捉し、pop後に安全に遷移
                  final rootNav = Navigator.of(context, rootNavigator: true);
                  Navigator.of(context).pop();
                  rootNav.push(
                    MaterialPageRoute(builder: (_) => const GemShopScreen()),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
