import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/widgets/empty_state.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_collection.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/shared/domain/theme_palette.dart';

/// 図鑑の金アクセント。ダークは従来の [Colors.amber] を厳密に保ち、
/// ライトだけ和紙白地で読める濃金（[GamePalette.accent]）へ落とす。
Color _gold(GamePalette palette) =>
    palette.isLight ? palette.accent : Colors.amber;

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
    final palette = GamePalette.of(context);
    // widget 差し替えに追従するため、State へ捕捉せず毎 build 解決する。
    final ownedTitles = widget.ownedTitles ??
        context.watch<PlayerViewModel>().player.titles;
    final collection = const CrossAppTitleService().build(
      ownedTitles: ownedTitles,
      definitions: widget.definitions,
    );
    final filtered = collection.filter(_filter);
    // 図鑑は元は常時ダーク（#121212）だった。ライトでは和紙白地へ合わせる。
    final screenColor = palette.isLight
        ? Theme.of(context).scaffoldBackgroundColor
        : const Color(0xFF121212);

    return Scaffold(
      key: AppKeys.crossAppTitleEncyclopediaScreen,
      backgroundColor: screenColor,
      appBar: AppBar(
        backgroundColor: palette.isLight
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.black,
        foregroundColor: palette.isLight ? palette.onSurface : Colors.white,
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
            EmptyStateView(
              key: AppKeys.crossAppTitleEmpty,
              padding: const EdgeInsets.symmetric(vertical: 32),
              titleStyle:
                  TextStyle(fontSize: 14, color: palette.onSurfaceFaint),
              spec: EmptyStateSpec(
                title: '該当する称号はありません',
                actionLabel: _filter == CrossAppTitleFilter.all ? null : '絞り込みを解除',
                onAction: _filter == CrossAppTitleFilter.all
                    ? null
                    : () => setState(() => _filter = CrossAppTitleFilter.all),
              ),
            )
          else
            ..._buildGroups(filtered),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(CrossAppTitleCollection collection) {
    final palette = GamePalette.of(context);
    return Card(
      key: AppKeys.crossAppTitleSummary,
      color: palette.isLight ? palette.cardBackgroundStrong : Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: _gold(palette), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    collection.summaryLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.onSurface,
                    ),
                  ),
                ),
                Text(
                  collection.ratioLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _gold(palette),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: collection.achievementRatio,
              minHeight: 6,
              backgroundColor: palette.grid,
              valueColor: AlwaysStoppedAnimation<Color>(_gold(palette)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final palette = GamePalette.of(context);
    return Wrap(
      spacing: 8,
      children: CrossAppTitleFilter.values.map((filter) {
        return FilterChip(
          key: AppKeys.crossAppTitleFilterChip(filter.name),
          label: Text(filter.label),
          selected: _filter == filter,
          selectedColor: palette.isLight
              ? palette.accent.withValues(alpha: 0.18)
              : Colors.amber.withValues(alpha: 0.3),
          checkmarkColor: _gold(palette),
          backgroundColor:
              palette.isLight ? palette.cardBackgroundStrong : Colors.black45,
          labelStyle: TextStyle(
            fontSize: 12,
            // 選択中の明地では影付きの金が見えないため、墨色＋チェックで示す。
            color: _filter == filter
                ? (palette.isLight ? palette.onSurface : Colors.amber)
                : palette.onSurfaceMuted,
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
    final palette = GamePalette.of(context);
    final earned = group.entries.where((e) => e.isEarned).length;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              group.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: palette.onSurface,
              ),
            ),
          ),
          Text(
            '獲得 $earned / ${group.entries.length}',
            style:
                TextStyle(fontSize: 11, color: palette.onSurfaceFaint),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(CrossAppTitleEntry entry) {
    final palette = GamePalette.of(context);
    final earned = entry.isEarned;
    return Card(
      key: AppKeys.crossAppTitleRow(entry.id),
      color: palette.isLight ? palette.cardBackgroundStrong : Colors.black45,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: earned ? _gold(palette).withValues(alpha: 0.6) : palette.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              earned ? Icons.military_tech : Icons.lock_outline,
              color: earned ? _gold(palette) : palette.onSurfaceFaintest,
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
                      // ダークの獲得行は従来のオレンジ（金とは別色）を保つ。
                      color: earned
                          ? (palette.isLight ? palette.accent : Colors.orange)
                          : palette.onSurfaceFaintest,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.conditionLabel,
                    style: TextStyle(
                        fontSize: 11, color: palette.onSurfaceFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              entry.statusLabel,
              style: TextStyle(
                fontSize: 11,
                color: earned ? _gold(palette) : palette.onSurfaceFaintest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
