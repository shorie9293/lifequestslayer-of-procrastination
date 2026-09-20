// 敵討伐図鑑（改善提案）— 討伐記録から敵の発見状況を俯瞰する画面。
//
// [EnemyCatalogService] を用いて戦績から図鑑エントリを構築し、
// 完成率・希少種・討伐回数を一覧する。
// [BattleRecordRepository] を注入でき、Hive 未初期化環境では
// NoopBattleRecordRepository が既定となり例外を出さない。
import 'package:flutter/material.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/enemy_catalog.dart';
import 'package:rpg_todo/features/battle/presentation/battle_record_screen.dart';

/// 敵討伐図鑑画面。
///
/// - [repository]: 戦績の取得元。null なら Noop（全未討伐として表示）。
/// - [entriesOverride]: 試練用。指定時は repository を読まずにこれで構築。
class EnemyCatalogScreen extends StatefulWidget {
  final BattleRecordRepository? repository;

  /// 試練用: 指定時は repository を読まずにこのエントリで catalog を構築する。
  final List<EnemyCatalogEntry>? entriesOverride;

  const EnemyCatalogScreen({super.key, this.repository, this.entriesOverride});

  @override
  State<EnemyCatalogScreen> createState() => _EnemyCatalogScreenState();
}

class _EnemyCatalogScreenState extends State<EnemyCatalogScreen> {
  bool _loading = true;
  List<EnemyCatalogEntry> _entries = const [];
  // 0=すべて, 1=未討伐, 2=希少種
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final override = widget.entriesOverride;
    if (override != null) {
      setState(() {
        _entries = override;
        _loading = false;
      });
      return;
    }
    final repository = widget.repository ?? NoopBattleRecordRepository();
    try {
      final List<BattleRecord> records = await repository.load();
      if (!mounted) return;
      setState(() {
        _entries = EnemyCatalogService.build(records: records).entries;
        _loading = false;
      });
    } catch (_) {
      // Hive 未初期化等 → 空リスト = 全未討伐として扱う。
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _loading = false;
      });
    }
  }

  List<EnemyCatalogEntry> get _visibleEntries {
    final entries = EnemyCatalogService.sortByRank(_entries);
    return switch (_filter) {
      1 => EnemyCatalogService.filterUndiscovered(entries),
      2 => EnemyCatalogService.filterRare(entries),
      _ => entries,
    };
  }

  void _openDetailDialog(EnemyCatalogEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: AppKeys.enemyCatalogDetailDialog,
          title: Text(entry.isDiscovered ? entry.displayName : '???'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ランク: ${entry.rankLabel}'),
              if (entry.isRare && entry.rarityLabel.isNotEmpty)
                Text('希少種: ${entry.rarityLabel}'),
              Text('討伐回数: ${entry.defeatCount}回'),
              if (entry.isDiscovered) ...[
                if (entry.firstDefeatedAt != null)
                  Text('初討伐: '
                      '${BattleRecordScreen.formatTimestamp(entry.firstDefeatedAt!)}'),
                if (entry.lastDefeatedAt != null)
                  Text('最終討伐: '
                      '${BattleRecordScreen.formatTimestamp(entry.lastDefeatedAt!)}'),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: AppKeys.closeButton,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = EnemyCatalog(_visibleEntries);
    final full = EnemyCatalog(_entries);
    final rareDiscovered = full.rare.where((e) => e.isDiscovered).length;
    final rareTotal = full.rare.length;

    return Scaffold(
      key: AppKeys.enemyCatalogScreen,
      appBar: AppBar(
        title: const Text('敵討伐図鑑'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(catalog, full, rareDiscovered, rareTotal),
    );
  }

  Widget _buildBody(
    EnemyCatalog catalog,
    EnemyCatalog full,
    int rareDiscovered,
    int rareTotal,
  ) {
    if (full.entries.isEmpty) {
      return Center(
        child: Column(
          key: AppKeys.enemyCatalogEmpty,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.menu_book, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '図鑑の情報がありません。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        _buildHeader(full, rareDiscovered, rareTotal),
        _buildFilterChips(),
        Expanded(child: _buildGrid(catalog)),
      ],
    );
  }

  Widget _buildHeader(EnemyCatalog full, int rareDiscovered, int rareTotal) {
    return Card(
      key: AppKeys.enemyCatalogCompletion,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '図鑑完成率: ${full.completionLabel} '
                  '(${full.completionPercent}%)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: full.completionRatio),
            const SizedBox(height: 8),
            Text('累計討伐: ${full.totalDefeats}体'),
            Text('希少種: $rareDiscovered / $rareTotal 種',
                key: AppKeys.enemyCatalogRareProgress),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          key: AppKeys.enemyCatalogFilterAll,
          label: const Text('すべて'),
          selected: _filter == 0,
          onSelected: (_) => setState(() => _filter = 0),
        ),
        FilterChip(
          key: AppKeys.enemyCatalogFilterUndiscovered,
          label: const Text('未討伐'),
          selected: _filter == 1,
          onSelected: (_) => setState(() => _filter = 1),
        ),
        FilterChip(
          key: AppKeys.enemyCatalogFilterRare,
          label: const Text('希少種'),
          selected: _filter == 2,
          onSelected: (_) => setState(() => _filter = 2),
        ),
      ],
    );
  }

  Widget _buildGrid(EnemyCatalog catalog) {
    if (catalog.entries.isEmpty) {
      return Center(
        child: Column(
          key: AppKeys.enemyCatalogEmpty,
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.menu_book, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '該当する敵がいません。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      key: AppKeys.enemyCatalogGrid,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: catalog.entries.length,
      itemBuilder: (context, index) {
        final entry = catalog.entries[index];
        final name = entry.isDiscovered ? entry.displayName : '???';
        return Card(
          key: Key('row_enemy_catalog_${entry.assetPath}'),
          child: InkWell(
            onTap: () => _openDetailDialog(entry),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: entry.isDiscovered
                        ? Image.asset(
                            entry.assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.catching_pokemon, size: 40),
                          )
                        : ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Colors.grey,
                              BlendMode.saturation,
                            ),
                            child: Opacity(
                              opacity: 0.3,
                              child: Image.asset(
                                entry.assetPath,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.catching_pokemon,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (entry.isDiscovered)
                    Text(
                      '×${entry.defeatCount}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (entry.isDiscovered &&
                      entry.isRare &&
                      entry.rarityLabel.isNotEmpty)
                    Text(
                      entry.rarityLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.deepPurple,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
