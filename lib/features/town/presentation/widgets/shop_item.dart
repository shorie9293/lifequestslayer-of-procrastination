import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/accessibility/semantic_helper.dart';

/// ショップアイテムのデータクラス
class ShopItem {
  final String id;
  final String name;
  final int price;
  final String description;

  const ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
  });
}

/// 購入確認ダイアログを表示する
void showBuyConfirmDialog(
  BuildContext context,
  dynamic viewModel,
  ShopItem item,
) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      key: AppKeys.townBuyConfirmDialog,
      title: const Text("購入確認"),
      content: Text("「${item.name}」を ${item.price} 文で購入しますか？"),
      actions: [
        SemanticHelper.interactive(
          testId:
              SemanticHelper.createTestId(SemanticTypes.button, 'cancel_buy'),
          label: '購入をやめる',
          child: TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("やめる"),
          ),
        ),
        SemanticHelper.interactive(
          testId:
              SemanticHelper.createTestId(SemanticTypes.button, 'confirm_buy'),
          label: '購入する',
          child: ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.amber[700]),
            onPressed: () {
              Navigator.pop(ctx);
              viewModel.buyShopItem(item.id, item.price);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("「${item.name}」を手に入れた！")),
              );
            },
            child: const Text("購入", style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    ),
  );
}

/// 購入ボタン（金貨不足チェック付き）
Widget buildBuyButton(
  BuildContext context,
  dynamic player,
  dynamic viewModel,
  ShopItem item,
) {
  return SemanticHelper.interactive(
    testId: SemanticHelper.createTestId(SemanticTypes.button, 'buy_${item.id}'),
    label: '${item.name}を${item.price}文で購入',
    child: ElevatedButton.icon(
      icon: const Icon(Icons.shopping_cart, size: 16),
      label: Text("${item.price}"),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            player.coins >= item.price ? Colors.amber[700] : Colors.grey,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        if (player.coins >= item.price) {
          showBuyConfirmDialog(context, viewModel, item);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("お金が足りません！")),
          );
        }
      },
    ),
  );
}
