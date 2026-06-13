import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';
import 'package:rpg_todo/features/town/domain/building.dart';
import 'package:rpg_todo/features/character_customization/presentation/equipment_tab.dart';
import 'package:rpg_todo/features/shared/widgets/help_dialog.dart';
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
    final playerVM = context.watch<PlayerViewModel>();
    final shopVM = context.watch<ShopViewModel>();
    final townVM = context.watch<TownViewModel>();
    final player = playerVM.player;
    final scale = townVM.townScale;
    final hd = homeData(player);
    final next = scale.nextScale;
    final nextLv = scale.nextLevelForUpgrade;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: AppKeys.townScreen,
        appBar: AppBar(
          title: Text("${scale.displayName} — ${hd['name']}"),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: '神託補佐（ヘルプ）',
              onPressed: () =>
                  showHelpDialog(context, screen: HelpScreen.town),
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFFFFD700),
            unselectedLabelColor: Colors.white54,
            indicatorColor: Color(0xFFFFD700),
            tabs: [
              Tab(icon: Icon(Icons.location_city), text: '町'),
              Tab(icon: Icon(Icons.face), text: '装備'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // ── 町タブ（既存コンテンツ） ──
            _TownTab(
              player: player,
              playerVM: playerVM,
              shopVM: shopVM,
              townVM: townVM,
              hd: hd,
              scale: scale,
              nextScale: next,
              nextLevel: nextLv,
            ),
            // ── 装備タブ（新規：5部位カスタマイズ） ──
            EquipmentTab(
              currentSkin: player.characterSkin,
              playerLevel: player.level,
              streakDays: player.streakDays,
              totalTasks: player.totalTasksCompleted,
              titles: player.titles,
              onEquip: (slot, skinId) {
                playerVM.equipCharacterSkin(slot, skinId); playerVM.save();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 町タブ — TownScreen の既存コンテンツを抽出
class _TownTab extends StatelessWidget {
  final dynamic player;
  final PlayerViewModel playerVM;
  final ShopViewModel shopVM;
  final TownViewModel townVM;
  final Map<String, String> hd;
  final TownScale scale;
  final TownScale? nextScale;
  final int? nextLevel;

  const _TownTab({
    required this.player,
    required this.playerVM,
    required this.shopVM,
    required this.townVM,
    required this.hd,
    required this.scale,
    required this.nextScale,
    required this.nextLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _backgroundColor(scale),
        image: DecorationImage(
          image: AssetImage(hd['image']!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.6), BlendMode.darken),
        ),
      ),
      child: Column(
        children: [
          CoinGemBalanceBar(player: player),
          // 町レベル・XPバー（新設）
          _TownLevelBar(
            level: townVM.townLevel.level,
            xp: townVM.townLevel.xp,
            xpToNext: townVM.townLevel.xpToNext,
          ),
          _TownScaleBar(scale: scale, nextScale: nextScale, nextLevel: nextLevel),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 建物セクション（新設）
                  _BuildingsSection(
                    buildings: townVM.buildings,
                    townLevel: townVM.townLevel.level,
                    playerCoins: player.coins,
                    onUpgrade: (building) {
                      townVM.upgradeBuilding(
                        building,
                        playerCoins: player.coins,
                        spendCoins: (amount) {
                          playerVM.spendCoins(amount);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  HomeShopSection(viewModel: shopVM, player: player),
                  const SizedBox(height: 24),
                  SkinSection(viewModel: shopVM, player: player, playerVM: playerVM),
                  const SizedBox(height: 24),
                  InnSection(viewModel: shopVM, player: player),
                  const SizedBox(height: 24),
                  TitleSection(viewModel: playerVM, player: player),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 町の発展段階に応じた背景色。
  Color _backgroundColor(TownScale scale) {
    switch (scale) {
      case TownScale.wildernessCamp:
        return const Color(0xFF2E4A1E); // 深緑（荒野）
      case TownScale.smallSettlement:
        return const Color(0xFF5C4033); // 茶色（木造集落）
      case TownScale.livelyTown:
        return const Color(0xFF4A3728); // 明るい茶（活気ある町）
      case TownScale.royalCapital:
        return const Color(0xFF3D2B1F); // 濃茶（王都）
      case TownScale.skyCity:
        return const Color(0xFF1A237E); // 深青（天空）
    }
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

/// 町レベル・XP進捗バー
class _TownLevelBar extends StatelessWidget {
  const _TownLevelBar({
    required this.level,
    required this.xp,
    required this.xpToNext,
  });

  final int level;
  final int xp;
  final int xpToNext;

  @override
  Widget build(BuildContext context) {
    final progress = xpToNext > 0 ? (xp / xpToNext).clamp(0.0, 1.0) : 1.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.5),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF607D8B), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_work, color: Color(0xFF4FC3F7), size: 16),
              const SizedBox(width: 6),
              Text(
                '町 Lv.$level',
                style: const TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '$xp / $xpToNext XP',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

/// 建物一覧セクション
class _BuildingsSection extends StatelessWidget {
  const _BuildingsSection({
    required this.buildings,
    required this.townLevel,
    required this.playerCoins,
    required this.onUpgrade,
  });

  final Map<Building, BuildingState> buildings;
  final int townLevel;
  final int playerCoins;
  final void Function(Building) onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.store, color: Color(0xFFFFD700), size: 18),
            SizedBox(width: 6),
            Text(
              '町の施設',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...buildings.entries.map((entry) {
          final building = entry.key;
          final state = entry.value;
          final unlocked = state.isUnlocked(townLevel);
          return _BuildingTile(
            building: building,
            state: state,
            unlocked: unlocked,
            playerCoins: playerCoins,
            townLevel: townLevel,
            onUpgrade: () => onUpgrade(building),
          );
        }),
      ],
    );
  }
}

/// 個別の建物タイル
class _BuildingTile extends StatelessWidget {
  const _BuildingTile({
    required this.building,
    required this.state,
    required this.unlocked,
    required this.playerCoins,
    required this.townLevel,
    required this.onUpgrade,
  });

  final Building building;
  final BuildingState state;
  final bool unlocked;
  final int playerCoins;
  final int townLevel;
  final VoidCallback onUpgrade;

  IconData get _icon {
    switch (building) {
      case Building.inn:
        return Icons.bed;
      case Building.shop:
        return Icons.storefront;
      case Building.blacksmith:
        return Icons.build;
      case Building.watchtower:
        return Icons.visibility;
    }
  }

  Color get _iconColor {
    if (!unlocked) return Colors.grey;
    switch (building) {
      case Building.inn:
        return const Color(0xFF81C784); // 緑
      case Building.shop:
        return const Color(0xFFFFD54F); // 黄
      case Building.blacksmith:
        return const Color(0xFFFF8A65); // 橙
      case Building.watchtower:
        return const Color(0xFF64B5F6); // 青
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = playerCoins >= state.upgradeCoinCost;
    final canUpgrade = unlocked && state.canUpgrade && canAfford;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: unlocked
            ? Colors.brown.withValues(alpha: 0.4)
            : Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: unlocked ? const Color(0xFF8D6E63) : Colors.grey[700]!,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(_icon, color: _iconColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      building.displayName,
                      style: TextStyle(
                        color: unlocked ? Colors.white : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unlocked) ...[
                      const SizedBox(width: 6),
                      _LevelStars(level: state.level),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? state.getEffect()
                      : '町Lv.${building.unlockTownLevel}で解放',
                  style: TextStyle(
                    color: unlocked ? Colors.white54 : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!unlocked)
            Icon(Icons.lock, color: Colors.grey[600], size: 18)
          else if (state.canUpgrade)
            GestureDetector(
              onTap: canUpgrade ? onUpgrade : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: canAfford
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'UP ${state.upgradeCoinCost}文',
                  style: TextStyle(
                    color: canAfford ? Colors.white : Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ),
            )
          else
            const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
        ],
      ),
    );
  }
}

/// 建物レベルを星で表示するウィジェット
class _LevelStars extends StatelessWidget {
  const _LevelStars({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < level ? Icons.star : Icons.star_border,
          color: i < level ? const Color(0xFFFFD700) : Colors.grey[600],
          size: 12,
        );
      }),
    );
  }
}
