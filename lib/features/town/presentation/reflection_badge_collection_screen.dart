import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection_badge.dart';
import 'package:rpg_todo/domain/services/reflection_badge_collection.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// 内省バッジのコレクション画面。
///
/// 全12バッジをtier別セクションで一覧表示し、分母つきの進捗を可視化する。
///
/// [repository] はテスト注入用（既定は実物）。Hive未初期化環境では
/// フェイクを注入すること（Hive.openBoxのzone汚染を防ぐため）。
/// [playerViewModel] もテスト注入可（省略時は Provider 経由で取得）。
class ReflectionBadgeCollectionScreen extends StatefulWidget {
  final ReflectionRepository? repository;
  final PlayerViewModel? playerViewModel;
  final VoidCallback? onBack;

  const ReflectionBadgeCollectionScreen({
    super.key,
    this.repository,
    this.playerViewModel,
    this.onBack,
  });

  @override
  State<ReflectionBadgeCollectionScreen> createState() =>
      _ReflectionBadgeCollectionScreenState();
}

class _ReflectionBadgeCollectionScreenState
    extends State<ReflectionBadgeCollectionScreen> {
  final ReflectionRepository _defaultRepo = ReflectionRepository();
  List<ReflectionBadgeProgress> _progress = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.repository ?? _defaultRepo;
    final reflections = await repo.getAll();
    if (!mounted) return;
    PlayerViewModel? vm;
    try {
      vm = widget.playerViewModel ?? context.read<PlayerViewModel>();
    } catch (_) {
      vm = null;
    }
    final player = vm?.player ?? Player();
    if (!mounted) return;
    setState(() {
      _progress = ReflectionBadgeCollection.build(
        player: player,
        reflections: reflections,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = GamePalette.of(context);
    return Scaffold(
      key: AppKeys.reflectionBadgeCollectionScreen,
      appBar: AppBar(
        title: const Text('🏅 内省バッジ'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(palette),
    );
  }

  Widget _buildBody(GamePalette palette) {
    final tiers = ReflectionBadgeCollection.groupByTier(_progress);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(palette),
          const SizedBox(height: 20),
          for (final entry in tiers.entries) ...[
            KeyedSubtree(
              key: AppKeys.reflectionBadgeTierSection(entry.key),
              child: _buildTierHeader(entry.key, palette),
            ),
            const SizedBox(height: 8),
            ...entry.value.map((p) => _buildBadgeRow(p, palette)),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(GamePalette palette) {
    final summary = ReflectionBadgeCollection.summaryLabel(_progress);
    final earned = ReflectionBadgeCollection.earnedCount(_progress);
    final total = _progress.length;
    return KeyedSubtree(
      key: AppKeys.reflectionBadgeSummaryCard,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.cardBackgroundStrong,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              key: AppKeys.reflectionBadgeSummaryProgress,
              value: total > 0 ? earned / total : 0.0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierHeader(int tier, GamePalette palette) {
    return Text(
      '— ${reflectionBadgeTierLabel(tier)} —',
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: palette.success,
      ),
    );
  }

  Widget _buildBadgeRow(ReflectionBadgeProgress p, GamePalette palette) {
    final unlocked = p.isUnlocked;
    // 未獲得行は Opacity 0.55 で減光する（無効状態の演出）。色はその手前で
    // 明背景でも沈まない濃さにしておく。
    final rowColor =
        unlocked ? palette.onSurface : palette.onSurfaceMuted;
    return KeyedSubtree(
      key: AppKeys.reflectionBadgeRow(p.def.id),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.cardBackgroundStrong,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: unlocked ? palette.success : palette.border,
            ),
          ),
          child: Row(
            children: [
              Text(p.def.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.def.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: rowColor,
                            ),
                          ),
                        ),
                        Icon(
                          unlocked ? Icons.check_circle : Icons.lock_outline,
                          size: 18,
                          color: unlocked
                              ? palette.success
                              : palette.onSurfaceFaintest,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.def.description,
                      style: TextStyle(
                          fontSize: 11, color: palette.onSurfaceFaint),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: unlocked ? 1.0 : p.ratio,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.progressLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: rowColor,
                            fontFeatures: const [],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
