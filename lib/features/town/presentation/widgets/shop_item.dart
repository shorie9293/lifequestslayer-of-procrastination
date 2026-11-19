import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:takamagahara_ui/takamagahara_ui.dart' hide AppKeys;

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
            child: Text("購入",
                style: TextStyle(color: GamePalette.of(ctx).onSurface)),
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
  ShopViewModel viewModel,
  ShopItem item,
) {
  final palette = GamePalette.of(context);
  final hasEnough = player.coins >= item.price;
  return SemanticHelper.interactive(
    testId: SemanticHelper.createTestId(SemanticTypes.button, 'buy_${item.id}'),
    label: '${item.name}を${item.price}文で購入',
    child: ElevatedButton.icon(
      icon: const Icon(Icons.shopping_cart, size: 16),
      label: Text("${item.price}"),
      style: ElevatedButton.styleFrom(
        backgroundColor: hasEnough
            ? Colors.amber[700]
            : (palette.isLight ? palette.onSurfaceFaintest : Colors.grey),
        // 金地(#FFA000)はライトでは墨、ダークでは白（従来どおり）。
        // 買えない時（灰地）はライトのみ白：墨(#2B2B2B) on #6B6B6B は 2.66:1 で不足する。
        foregroundColor: hasEnough
            ? palette.onSurface
            : (palette.isLight ? Colors.white : palette.onSurface),
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
