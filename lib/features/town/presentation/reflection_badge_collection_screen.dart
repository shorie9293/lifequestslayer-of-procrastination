import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/reflection_badge.dart';
import 'package:rpg_todo/domain/services/reflection_badge_collection.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
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
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final tiers = ReflectionBadgeCollection.groupByTier(_progress);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 20),
          for (final entry in tiers.entries) ...[
            KeyedSubtree(
              key: AppKeys.reflectionBadgeTierSection(entry.key),
              child: _buildTierHeader(entry.key),
            ),
            const SizedBox(height: 8),
            ...entry.value.map(_buildBadgeRow),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final summary = ReflectionBadgeCollection.summaryLabel(_progress);
    final earned = ReflectionBadgeCollection.earnedCount(_progress);
    final total = _progress.length;
    return KeyedSubtree(
      key: AppKeys.reflectionBadgeSummaryCard,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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

  Widget _buildTierHeader(int tier) {
    return Text(
      '— ${reflectionBadgeTierLabel(tier)} —',
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4CAF50),
      ),
    );
  }

  Widget _buildBadgeRow(ReflectionBadgeProgress p) {
    final unlocked = p.isUnlocked;
    final rowColor = unlocked ? Colors.white : Colors.white30;
    return KeyedSubtree(
      key: AppKeys.reflectionBadgeRow(p.def.id),
      child: Opacity(
        opacity: unlocked ? 1.0 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: unlocked ? const Color(0xFF4CAF50) : Colors.white12,
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
                              ? const Color(0xFF4CAF50)
                              : Colors.white24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.def.description,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white54),
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
