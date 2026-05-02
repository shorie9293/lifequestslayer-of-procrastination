import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/game_view_model.dart';
import '../models/title_definition.dart';
import 'gem_shop_screen.dart';
import '../core/testing/widget_keys.dart';

class TownScreen extends StatelessWidget {
  const TownScreen({super.key});

  Map<String, dynamic> _getHomeData(player) {
    if (player.homeItems.contains("home_4")) return {'name': 'ギルドハウス', 'image': 'assets/images/home_4.png'};
    if (player.homeItems.contains("home_3")) return {'name': '石造りの家', 'image': 'assets/images/home_3.png'};
    if (player.homeItems.contains("home_2")) return {'name': '木の小屋', 'image': 'assets/images/home_2.png'};
    if (player.homeItems.contains("home_1")) return {'name': '小さなテント', 'image': 'assets/images/home_1.png'};
    return {'name': '野宿', 'image': 'assets/images/home_0.png'};
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final player = viewModel.player;
    final homeData = _getHomeData(player);

    return Scaffold(
      key: AppKeys.townScreen,
      appBar: AppBar(
        title: Text("はじまりの街 - ${homeData['name']}"),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(homeData['image']),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black45,
              child: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                  const SizedBox(width: 6),
                  Text(
                    key: AppKeys.townCoinBalance,
                    "${player.coins} 金貨",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                  const Spacer(),
                  const Icon(Icons.diamond, color: Colors.purpleAccent, size: 24),
                  const SizedBox(width: 4),
                  Text(
                    key: AppKeys.townGemBalance,
                    "${player.gems} 宝石",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: AppKeys.townGemShopButton,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('購入'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GemShopScreen()),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInnSection(context, player, viewModel),
                  const SizedBox(height: 24),
                  _buildTitlesSection(context, player, viewModel),
                  const SizedBox(height: 24),
                  _buildShopSection(
                    context, 
                    title: "拠点拡張 (家づくり)", 
                    icon: Icons.home,
                    items: [
                      _ShopItem(id: "home_1", name: "小さなテント", price: 1000, description: "とりあえず雨風はしのげる。"),
                      _ShopItem(id: "home_2", name: "木の小屋", price: 5000, description: "ちゃんとした壁がある拠点。"),
                      _ShopItem(id: "home_3", name: "石造りの家", price: 20000, description: "魔物にも壊されない頑丈な家。"),
                      _ShopItem(id: "home_4", name: "ギルドハウス", price: 100000, description: "立派なギルドの拠点。機能美が光る。"),
                    ], 
                    player: player, 
                    viewModel: viewModel
                  ),
                  const SizedBox(height: 24),
                  _buildSkinSection(
                    context, 
                    title: "キャラクリエイト (装飾)", 
                    icon: Icons.person,
                    items: [
                      _ShopItem(id: "skin_1", name: "旅人のマント", price: 500, description: "長旅に耐える丈夫なマント。"),
                      _ShopItem(id: "skin_2", name: "戦士の勲章", price: 3000, description: "歴戦の戦士だけが身につける勲章。"),
                      _ShopItem(id: "skin_3", name: "大魔導士の杖", price: 15000, description: "魔力を底上げする伝説の杖のレプリカ。"),
                      _ShopItem(id: "skin_4", name: "王冠", price: 500000, description: "王者が被るにふさわしい冠。"),
                    ], 
                    player: player, 
                    viewModel: viewModel
                  ),
                ],
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopSection(BuildContext context, {required String title, required IconData icon, required List<_ShopItem> items, required player, required GameViewModel viewModel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final isOwned = player.homeItems.contains(item.id);
          return Card(
            color: Colors.black54,
            child: ListTile(
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.description),
              trailing: isOwned
                  ? const Text("所有済", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_cart, size: 16),
                      label: Text("${item.price}"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: player.coins >= item.price ? Colors.amber[700] : Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (player.coins >= item.price) {
                          _buyItem(context, viewModel, item);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("お金が足りません！")),
                          );
                        }
                      },
                    ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSkinSection(BuildContext context, {required String title, required IconData icon, required List<_ShopItem> items, required player, required GameViewModel viewModel}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) {
          final isOwned = player.homeItems.contains(item.id);
          final isEquipped = player.equippedSkin == item.id;
          return Card(
            color: Colors.black54,
            child: ListTile(
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.description),
              trailing: isEquipped
                  ? const Text("装備中", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))
                  : isOwned
                      ? ElevatedButton(
                          child: const Text("装備する"),
                          onPressed: () { 
                            viewModel.equipSkin(item.id); 
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${item.name}を装備した！"))); 
                          },
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.shopping_cart, size: 16),
                          label: Text("${item.price}"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: player.coins >= item.price ? Colors.amber[700] : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (player.coins >= item.price) {
                              _buyItem(context, viewModel, item);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("お金が足りません！")),
                              );
                            }
                          },
                        ),
            ),
          );
        }),
        if (player.equippedSkin != null)
          Card(
            color: Colors.black54,
            child: ListTile(
              title: const Text("装備を外す", style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: ElevatedButton(
                child: const Text("外す"),
                onPressed: () { 
                  viewModel.equipSkin(""); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("スキンを外した"))); 
                },
              ),
            ),
          )
      ],
    );
  }

  void _buyItem(BuildContext context, GameViewModel viewModel, _ShopItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: AppKeys.townBuyConfirmDialog,
        title: const Text("購入確認"),
        content: Text("「${item.name}」を ${item.price} 金貨で購入しますか？"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("やめる"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
            onPressed: () {
              Navigator.pop(ctx);
              viewModel.buyShopItem(item.id, item.price);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("「${item.name}」を手に入れた！")),
              );
            },
            child: const Text("購入", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 宿屋システム（新機能：疲労回復） ---
  Widget _buildInnSection(BuildContext context, player, GameViewModel viewModel) {
    return Column(
      key: AppKeys.townInnSection,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.hotel, color: Colors.white),
            SizedBox(width: 8),
            Text("宿屋 (疲労軽減バフ)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        _buildInnItem(context, viewModel, player, 0, "裏路地のテント", 50, "翌日の疲労限界+2(微回復)"),
        _buildInnItem(context, viewModel, player, 1, "ふかふかのベッド", 200, "翌日の疲労限界+5(中回復)"),
        _buildInnItem(context, viewModel, player, 2, "王様のスイートルーム", 1000, "翌日の疲労限界+12(完全回復)"),
      ],
    );
  }

  Widget _buildInnItem(BuildContext context, GameViewModel viewModel, player, int type, String name, int price, String desc) {
    return Card(
      color: Colors.black54,
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
        trailing: ElevatedButton.icon(
          icon: const Icon(Icons.bed, size: 16),
          label: Text("$price"),
          style: ElevatedButton.styleFrom(
            backgroundColor: player.coins >= price ? Colors.amber[700] : Colors.grey,
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (player.coins >= price) {
              _restAtInn(context, viewModel, type, name, price);
            } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("金貨が足りないぜ")));
            }
          },
        ),
      ),
    );
  }

  void _restAtInn(BuildContext context, GameViewModel viewModel, int type, String name, int price) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: AppKeys.townInnConfirmDialog,
        title: const Text("宿泊確認"),
        content: Text("「$name」に $price 金貨で泊まりますか？\n(※1日1回のみ。明日の疲労バフ上限を引き上げます)"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("やめる")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
            onPressed: () {
              Navigator.pop(ctx);
              final err = viewModel.restAtInn(type);
              if (err != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ぐっすり休んだ！明日はもっと頑張れそうだ！")));
              }
            },
            child: const Text("泊まる", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 称号システム ---
  Widget _buildTitlesSection(BuildContext context, player, GameViewModel viewModel) {
    final titleProgress = viewModel.titleProgressList;
    final unlockedCount = titleProgress.where((e) => e.isUnlocked).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.military_tech, color: Colors.white),
            SizedBox(width: 8),
            Text("称号セット (EXP+5%ボーナス)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        // 現在装備中
        Card(
          color: Colors.black54,
          child: ListTile(
            title: Text(player.equippedTitle ?? "称号なし",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            subtitle: const Text("現在装備中の称号"),
            trailing: ElevatedButton(
              child: const Text("変更する"),
              onPressed: () => _showTitleSelectDialog(context, viewModel, player),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 称号アーカイブ（進捗バー付き）
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.black38,
            collapsedBackgroundColor: Colors.black38,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            title: Text(
              "📜 称号アーカイブ  $unlockedCount / ${kAllTitles.length}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            children: titleProgress.map((entry) {
              return _buildTitleProgressCard(
                context: context,
                def: entry.def,
                isUnlocked: entry.isUnlocked,
                currentProgress: entry.progress,
                isEquipped: player.equippedTitle == entry.def.id,
                onEquip: () {
                  viewModel.equipTitle(entry.def.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("【${entry.def.id}】を装備した！")),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTitleProgressCard({
    required BuildContext context,
    required TitleDefinition def,
    required bool isUnlocked,
    required int currentProgress,
    required bool isEquipped,
    required VoidCallback onEquip,
  }) {
    final progressRate = (currentProgress / def.requiredCount).clamp(0.0, 1.0);
    final isNearlyDone = progressRate >= 0.9;

    return Card(
      color: Colors.black45,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isUnlocked ? Colors.amber.withValues(alpha: 0.6) : Colors.white12,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isUnlocked ? Icons.military_tech : Icons.lock_outline,
                  color: isUnlocked ? Colors.amber : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "【${def.id}】",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isUnlocked ? Colors.orange : Colors.white38,
                    ),
                  ),
                ),
                if (isEquipped)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: const Text("装備中", style: TextStyle(fontSize: 10, color: Colors.orange)),
                  )
                else if (isUnlocked)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onEquip,
                    child: const Text("装備", style: TextStyle(color: Colors.amber)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              def.condition,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
            if (!isUnlocked) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progressRate,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNearlyDone ? Colors.orangeAccent : Colors.amber,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "$currentProgress / ${def.requiredCount}",
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showTitleSelectDialog(BuildContext context, GameViewModel viewModel, player) {
    showDialog(
      context: context,
      builder: (ctx) {
        List<String> titles = ["", ...player.titles];
        return AlertDialog(
          key: AppKeys.townTitleSelectDialog,
          title: const Text("称号一覧"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: titles.length,
              itemBuilder: (context, index) {
                final t = titles[index];
                return ListTile(
                  title: Text(t.isEmpty ? "称号を外す" : t, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: t == player.equippedTitle ? Colors.orange : Colors.white,
                  )),
                  onTap: () {
                    viewModel.equipTitle(t);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ShopItem {
  final String id;
  final String name;
  final int price;
  final String description;

  _ShopItem({required this.id, required this.name, required this.price, required this.description});
}
