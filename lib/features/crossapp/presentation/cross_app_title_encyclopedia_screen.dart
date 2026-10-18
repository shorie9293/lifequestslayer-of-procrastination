import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_collection.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

/// クロスアプリ称号図鑑（tsundoku-quest 連携称号の一覧・獲得状況）
///
/// 暗色系の図鑑画面。称号定義 [definitions] と所持称号名 [ownedTitles] から
/// 図鑑を組み立て、絞り込み・グループ表示・サマリーを提供する。
///
/// [ownedTitles] が null の場合は Provider の [PlayerViewModel] から取得する。
/// State に捕捉すると widget 差し替え時に陳腐化するため、毎 build 解決する。
class CrossAppTitleEncyclopediaScreen extends StatefulWidget {
  final List<String>? ownedTitles;
  final List<CrossAppTitleDefinition> definitions;

  const CrossAppTitleEncyclopediaScreen({
    super.key,
    this.ownedTitles,
    this.definitions = kCrossAppTitles,
  });

  @override
  State<CrossAppTitleEncyclopediaScreen> createState() =>
      _CrossAppTitleEncyclopediaScreenState();
}

class _CrossAppTitleEncyclopediaScreenState
    extends State<CrossAppTitleEncyclopediaScreen> {
  CrossAppTitleFilter _filter = CrossAppTitleFilter.all;

  @override
  Widget build(BuildContext context) {
    // widget 差し替えに追従するため、State へ捕捉せず毎 build 解決する。
    final ownedTitles = widget.ownedTitles ??
        context.watch<PlayerViewModel>().player.titles;
    final collection = const CrossAppTitleService().build(
      ownedTitles: ownedTitles,
      definitions: widget.definitions,
    );
    final filtered = collection.filter(_filter);

    return Scaffold(
      key: AppKeys.crossAppTitleEncyclopediaScreen,
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('📖 クロスアプリ称号図鑑'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSummaryCard(collection),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 12),
          if (filtered.total == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '該当する称号はありません',
                  key: AppKeys.crossAppTitleEmpty,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
              ),
            )
          else
            ..._buildGroups(filtered),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CrossAppTitleCollection collection) {
    return Card(
      key: AppKeys.crossAppTitleSummary,
      color: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    collection.summaryLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  collection.ratioLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: collection.achievementRatio,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: CrossAppTitleFilter.values.map((filter) {
        return FilterChip(
          key: AppKeys.crossAppTitleFilterChip(filter.name),
          label: Text(filter.label),
          selected: _filter == filter,
          selectedColor: Colors.amber.withValues(alpha: 0.3),
          checkmarkColor: Colors.amber,
          backgroundColor: Colors.black45,
          labelStyle: TextStyle(
            fontSize: 12,
            color: _filter == filter ? Colors.amber : Colors.white70,
          ),
          onSelected: (_) => setState(() => _filter = filter),
        );
      }).toList(),
    );
  }

  List<Widget> _buildGroups(CrossAppTitleCollection collection) {
    final widgets = <Widget>[];
    for (final group in collection.groups) {
      widgets.add(_buildGroupHeader(group));
      for (final entry in group.entries) {
        widgets.add(_buildEntryRow(entry));
      }
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
  }

  Widget _buildGroupHeader(CrossAppTitleGroup group) {
    final earned = group.entries.where((e) => e.isEarned).length;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            '獲得 $earned / ${group.entries.length}',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(CrossAppTitleEntry entry) {
    final earned = entry.isEarned;
    return Card(
      key: AppKeys.crossAppTitleRow(entry.id),
      color: Colors.black45,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: earned ? Colors.amber.withValues(alpha: 0.6) : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              earned ? Icons.military_tech : Icons.lock_outline,
              color: earned ? Colors.amber : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.id,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: earned ? Colors.orange : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.conditionLabel,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              entry.statusLabel,
              style: TextStyle(
                fontSize: 11,
                color: earned ? Colors.amber : Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
