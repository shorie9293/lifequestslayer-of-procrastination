import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';
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
    final scale = viewModel.townScale;
    final hd = homeData(player);
    final next = scale.nextScale;
    final nextLv = scale.nextLevelForUpgrade;

    return Scaffold(
      key: AppKeys.townScreen,
      appBar: AppBar(title: Text("${scale.displayName} — ${hd['name']}")),
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
            // 町発展情報バー
            _TownScaleBar(scale: scale, nextScale: next, nextLevel: nextLv),
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

/// 町の発展段階を表示するバー
class _TownScaleBar extends StatelessWidget {
  const _TownScaleBar({
    required this.scale,
    required this.nextScale,
    required this.nextLevel,
  });

  final TownScale scale;
  final TownScale? nextScale;
  final int? nextLevel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.brown.withValues(alpha: 0.7),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFD4A574), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_city, color: Color(0xFFFFD700), size: 18),
          const SizedBox(width: 8),
          Text(
            scale.displayName,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (nextScale != null && nextLevel != null) ...[
            const Icon(Icons.arrow_forward, color: Colors.white54, size: 14),
            const SizedBox(width: 4),
            Text(
              '次の発展: ${nextScale?.displayName} （Lv.$nextLevel）',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ] else ...[
            const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
            const SizedBox(width: 4),
            const Text(
              '最大発展',
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
