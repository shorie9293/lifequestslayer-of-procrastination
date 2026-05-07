import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'widgets/coin_gem_balance_bar.dart';
import 'widgets/home_shop_section.dart';
import 'widgets/skin_section.dart';
import 'widgets/inn_section.dart';
import 'widgets/title_section.dart';

class TownScreen extends StatelessWidget {
  const TownScreen({super.key});

  static Map<String, String> homeData(player) {
    if (player.homeItems.contains("home_4")) return {'name': '寄合長屋', 'image': 'assets/images/home_4.png'};
    if (player.homeItems.contains("home_3")) return {'name': '石蔵', 'image': 'assets/images/home_3.png'};
    if (player.homeItems.contains("home_2")) return {'name': '木造長屋', 'image': 'assets/images/home_2.png'};
    if (player.homeItems.contains("home_1")) return {'name': '粗末な庵', 'image': 'assets/images/home_1.png'};
    return {'name': '野宿', 'image': 'assets/images/home_0.png'};
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<GameViewModel>(context);
    final player = viewModel.player;
    final hd = homeData(player);

    return Scaffold(
      key: AppKeys.townScreen,
      appBar: AppBar(title: Text("門前町 - ${hd['name']}")),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(hd['image']!),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
          ),
        ),
        child: Column(
          children: [
            CoinGemBalanceBar(player: player),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    HomeShopSection(viewModel: viewModel, player: player),
                    const SizedBox(height: 24),
                    SkinSection(viewModel: viewModel, player: player),
                    const SizedBox(height: 24),
                    InnSection(viewModel: viewModel, player: player),
                    const SizedBox(height: 24),
                    TitleSection(viewModel: viewModel, player: player),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
