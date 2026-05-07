import 'package:flutter/material.dart';
import 'package:rpg_todo/features/town/presentation/widgets/shop_item.dart';

/// 拠点拡張（家づくり）ショップセクション
class HomeShopSection extends StatelessWidget {
  final dynamic player;
  final dynamic viewModel;

  const HomeShopSection({
    super.key,
    required this.player,
    required this.viewModel,
  });

  static const List<ShopItem> _items = [
    ShopItem(
        id: "home_1",
        name: "粗末な庵",
        price: 1000,
        description: "藁葺き屋根の小さな庵。雨風はしのげる。"),
    ShopItem(
        id: "home_2",
        name: "木造長屋",
        price: 5000,
        description: "板壁の長屋。ようやく落ち着ける我が家。"),
    ShopItem(
        id: "home_3",
        name: "石蔵",
        price: 20000,
        description: "魔物にも壊されぬ頑丈な蔵。"),
    ShopItem(
        id: "home_4",
        name: "寄合長屋",
        price: 100000,
        description: "寄合所に構える大店。機能美が光る。"),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.home, color: Colors.white),
            SizedBox(width: 8),
            Text("拠点拡張 (家づくり)",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        ..._items.map((item) {
          final isOwned = player.homeItems.contains(item.id);
          return Card(
            color: Colors.black54,
            child: ListTile(
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.description),
              trailing: isOwned
                  ? const Text("所有済",
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold))
                  : buildBuyButton(context, player, viewModel, item),
            ),
          );
        }),
      ],
    );
  }
}
