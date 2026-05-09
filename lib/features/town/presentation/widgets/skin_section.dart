import 'package:flutter/material.dart';
import 'package:rpg_todo/features/town/presentation/widgets/shop_item.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart';

/// キャラクリエイト（装飾）セクション
class SkinSection extends StatelessWidget {
  final dynamic player;
  final dynamic viewModel;

  const SkinSection({
    super.key,
    required this.player,
    required this.viewModel,
  });

  static const List<ShopItem> _items = [
    ShopItem(
        id: "skin_1",
        name: "旅衣",
        price: 500,
        description: "長旅に耐える丈夫な旅衣。"),
    ShopItem(
        id: "skin_2",
        name: "武功の感状",
        price: 3000,
        description: "主君より賜る武功の証。"),
    ShopItem(
        id: "skin_3",
        name: "高僧の錫杖",
        price: 15000,
        description: "法力漲る高僧の錫杖。"),
    ShopItem(
        id: "skin_4",
        name: "天の冠",
        price: 500000,
        description: "天に選ばれし者だけが戴く冠。"),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.person, color: Colors.white),
            SizedBox(width: 8),
            Text("キャラクリエイト (装飾)",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 12),
        ..._items.map((item) {
          final isOwned = player.homeItems.contains(item.id);
          final isEquipped = player.equippedSkin == item.id;
          return Card(
            color: Colors.black54,
            child: ListTile(
              title: Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.description),
              trailing: isEquipped
                  ? const Text("装備中",
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold))
                  : isOwned
                      ? _buildEquipButton(context, item)
                      : buildBuyButton(context, player, viewModel, item),
            ),
          );
        }),
        if (player.equippedSkin != null)
          Card(
            color: Colors.black54,
            child: ListTile(
              title: const Text("装備を外す",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: SemanticHelper.interactive(
                testId: SemanticHelper.createTestId(
                    SemanticTypes.button, 'unequip_skin'),
                label: '装備を外す',
                child: ElevatedButton(
                  child: const Text("外す"),
                  onPressed: () {
                    viewModel.equipSkin("");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("スキンを外した")),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEquipButton(BuildContext context, ShopItem item) {
    return SemanticHelper.interactive(
      testId: SemanticHelper.createTestId(
          SemanticTypes.button, 'equip_${item.id}'),
      label: '${item.name}を装備する',
      child: ElevatedButton(
        child: const Text("装備する"),
        onPressed: () {
          viewModel.equipSkin(item.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${item.name}を装備した！")),
          );
        },
      ),
    );
  }
}
