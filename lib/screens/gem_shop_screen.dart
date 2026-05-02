import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/iap_service.dart';
import '../viewmodels/game_view_model.dart';
import '../core/accessibility/semantic_helper.dart';
import '../core/testing/widget_keys.dart';

/// 宝石パックの表示名・ボーナス表記
const _gemTierInfo = {
  'gems_tier1': (label: '100 💎', bonus: ''),
  'gems_tier2': (label: '550 💎', bonus: '+50 ボーナス！'),
  'gems_tier3': (label: '1200 💎', bonus: '+200 お得！'),
  'gems_tier4': (label: '2600 💎', bonus: '+600 激お得！'),
};

class GemShopScreen extends StatefulWidget {
  const GemShopScreen({super.key});

  @override
  State<GemShopScreen> createState() => _GemShopScreenState();
}

class _GemShopScreenState extends State<GemShopScreen> {
  @override
  void initState() {
    super.initState();
    // IAPServiceが通知したら宝石をGameViewModelに付与する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<IAPService>().addListener(_onIAPUpdate);
    });
  }

  @override
  void dispose() {
    context.read<IAPService>().removeListener(_onIAPUpdate);
    super.dispose();
  }

  void _onIAPUpdate() async {
    if (!mounted) return;
    final iap = context.read<IAPService>();
    final gems = await iap.consumePendingGems();
    if (gems > 0 && mounted) {
      context.read<GameViewModel>().addGems(gems);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💎 $gems 宝石を受け取りました！'),
          backgroundColor: Colors.purple[700],
        ),
      );
    }
    if (!mounted) return;
    // エラー表示
    final err = iap.errorMessage;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('購入エラー: $err'), backgroundColor: Colors.red),
      );
      iap.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iap = context.watch<IAPService>();
    final viewModel = context.watch<GameViewModel>();
    final player = viewModel.player;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('💎 宝石ショップ'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Chip(
              avatar: const Text('💎'),
              label: Text('${player.gems}'),
              backgroundColor: Colors.purple[900],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPurchaseSection(context, iap, player),
          const SizedBox(height: 24),
          _buildUseSection(context, viewModel, player),
        ],
      ),
    );
  }

  // ── 宝石パック購入 ──────────────────────────────────
  Widget _buildPurchaseSection(BuildContext context, IAPService iap, player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.diamond, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text('宝石を購入', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '宝石はゲーム内の特別な機能に使えます。\n購入した宝石は端末に保存されます。',
          style: TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 12),
        if (!iap.available)
          const Card(
            color: Colors.black45,
            child: ListTile(
              leading: Icon(Icons.store_mall_directory, color: Colors.grey),
              title: Text('ストアに接続できません'),
              subtitle: Text('ネットワーク接続を確認してください'),
            ),
          )
        else if (iap.loading)
          const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ))
        else if (iap.products.isEmpty)
          const Card(
            color: Colors.black45,
            child: ListTile(
              title: Text('商品を読み込めませんでした'),
              subtitle: Text('しばらくしてから再度お試しください'),
            ),
          )
        else
          ...iap.products.map((product) => _buildProductCard(context, iap, product)),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, IAPService iap, ProductDetails product) {
    final info = _gemTierInfo[product.id];
    final label = info?.label ?? product.title;
    final bonus = info?.bonus ?? '';
    final isPopular = product.id == 'gems_tier3';

    return Card(
      color: isPopular ? Colors.purple[900] : Colors.black54,
      margin: const EdgeInsets.only(bottom: 8),
      shape: isPopular
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.purpleAccent, width: 2),
            )
          : null,
      child: ListTile(
        leading: const Icon(Icons.diamond, color: Colors.purpleAccent, size: 32),
        title: Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isPopular) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                child: const Text('おすすめ', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: bonus.isNotEmpty ? Text(bonus, style: const TextStyle(color: Colors.amberAccent)) : null,
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple[700],
            foregroundColor: Colors.white,
          ),
          onPressed: () => _confirmPurchase(context, iap, product, label),
          child: Text(product.price, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  void _confirmPurchase(BuildContext context, IAPService iap, ProductDetails product, String label) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('購入確認'),
        content: Text('$label を ${product.price} で購入しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
            onPressed: () {
              Navigator.pop(ctx);
              iap.buy(product);
            },
            child: const Text('購入', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 宝石の使いみち ───────────────────────────────────
  Widget _buildUseSection(BuildContext context, GameViewModel viewModel, player) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('宝石の使いみち', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        // 金貨交換
        _buildUseCard(
          icon: Icons.monetization_on,
          iconColor: Colors.amber,
          title: '金貨に両替',
          description: '10宝石 → 1,000金貨',
          cost: 10,
          playerGems: player.gems,
          onConfirm: () {
            final ok = viewModel.exchangeGemsForCoins(10);
            _showResult(context, ok, '1,000金貨を受け取った！', '宝石が足りません');
          },
        ),
        const SizedBox(height: 8),
        // 疲労リセット
        _buildUseCard(
          icon: Icons.local_hospital,
          iconColor: Colors.greenAccent,
          title: '疲労を即時回復',
          description: '50宝石 → 今日の疲労度をリセット',
          cost: 50,
          playerGems: player.gems,
          onConfirm: () {
            final ok = viewModel.resetFatigueWithGems();
            _showResult(context, ok, '疲労がリセットされた！', '宝石が足りません');
          },
        ),
      ],
    );
  }

  Widget _buildUseCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required int cost,
    required int playerGems,
    required VoidCallback onConfirm,
  }) {
    final canAfford = playerGems >= cost;
    return Card(
      color: Colors.black54,
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: ElevatedButton.icon(
          icon: const Text('💎'),
          label: Text('$cost'),
          style: ElevatedButton.styleFrom(
            backgroundColor: canAfford ? Colors.purple[700] : Colors.grey,
            foregroundColor: Colors.white,
          ),
          onPressed: canAfford
              ? () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(title),
                      content: Text('💎 $cost 宝石を使いますか？'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[700]),
                          onPressed: () {
                            Navigator.pop(ctx);
                            onConfirm();
                          },
                          child: const Text('使う', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
              : null,
        ),
      ),
    );
  }

  void _showResult(BuildContext context, bool ok, String successMsg, String failMsg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? successMsg : failMsg),
        backgroundColor: ok ? Colors.purple[700] : Colors.red,
      ),
    );
  }
}
