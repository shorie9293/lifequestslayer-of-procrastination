import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:rpg_todo/features/town/presentation/gem_shop_screen.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

/// 金貨・宝石残高＋宝石ショップへのボタンを表示するバー
class CoinGemBalanceBar extends StatelessWidget {
  final dynamic player;

  const CoinGemBalanceBar({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    final coinColor = palette.readable(Colors.amber);
    final gemColor = palette.readable(Colors.purpleAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: palette.isLight ? palette.cardBackgroundStrong : Colors.black45,
      child: Row(
        children: [
          Icon(Icons.monetization_on, color: coinColor, size: 28),
          const SizedBox(width: 6),
          Text(
            key: AppKeys.townCoinBalance,
            "${player.coins} 文",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: coinColor,
            ),
          ),
          const Spacer(),
          Icon(Icons.diamond, color: gemColor, size: 24),
          const SizedBox(width: 4),
          Text(
            key: AppKeys.townGemBalance,
            "${player.gems} 宝石",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: gemColor,
            ),
          ),
          const SizedBox(width: 8),
          SemanticHelper.interactive(
            testId: SemanticHelper.createTestId(
                SemanticTypes.button, 'goto_gem_shop'),
            label: '宝石ショップへ',
            child: ElevatedButton.icon(
              key: AppKeys.townGemShopButton,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('購入'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple[700],
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GemShopScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
