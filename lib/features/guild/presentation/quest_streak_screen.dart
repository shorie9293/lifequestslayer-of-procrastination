import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/quest_streak.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';

import 'quest_streak_keys.dart';

/// クエスト別ストリーク画面。
///
/// 各クエストの連続完了記録を [QuestStreakService] で集計して一覧表示する。
///
/// [tasksOverride]・[streaksOverride]・[now] を注入でき、
/// GameViewModel に依存せず試練可能。未注入時の既定値は
/// `context.read<GameViewModel>()` から読む（getIt 未登録の試練環境でも
/// override 注入なら provider を参照しない）。
class QuestStreakScreen extends StatefulWidget {
  const QuestStreakScreen({
    super.key,
    this.tasksOverride,
    this.streaksOverride,
    this.now,
  });

  /// 表示するクエスト一覧（試練用に注入できる）。
  final List<Task>? tasksOverride;

  /// クエストごとのストリーク記録（試練用に注入できる）。
  final Map<String, TaskStreak>? streaksOverride;

  /// 「今日」の日付（試練用に固定値を注入できる）。未指定時は DateTime.now()。
  final DateTime? now;

  @override
  State<QuestStreakScreen> createState() => _QuestStreakScreenState();
}

class _QuestStreakScreenState extends State<QuestStreakScreen> {
  String _query = '';
  bool _bonusOnly = false;

  /// widget 由来の値は getter で参照する（State 再利用に耐える）。
  /// GameViewModel 未提供の環境（試練の push 先ルート等）では安全側の空値。
  List<Task> get _tasks {
    final override = widget.tasksOverride;
    if (override != null) return override;
    try {
      return context.read<GameViewModel>().tasks;
    } catch (_) {
      return const [];
    }
  }

  Map<String, TaskStreak> get _streaks {
    final override = widget.streaksOverride;
    if (override != null) return override;
    try {
      return context.read<GameViewModel>().player.taskStreaks;
    } catch (_) {
      return const {};
    }
  }

  DateTime get _now => widget.now ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final entries = QuestStreakService.sortEntries(
      QuestStreakService.build(
        tasks: _tasks,
        streaks: _streaks,
        now: now,
      ),
    );
    final summary = QuestStreakService.summarize(entries);
    var filtered = _query.isEmpty
        ? entries
        : QuestStreakService.searchByTitle(entries, _query);
    if (_bonusOnly) {
      filtered = QuestStreakService.filterBonusActive(filtered);
    }

    return Scaffold(
      key: QuestStreakKeys.screen,
      appBar: AppBar(
        title: const Text('クエスト別ストリーク'),
      ),
      body: Column(
        children: [
          _buildSummaryCard(summary),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              key: QuestStreakKeys.searchField,
              decoration: const InputDecoration(
                hintText: 'クエストを検索',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                key: QuestStreakKeys.bonusFilterChip,
                label: const Text('ボーナス中のみ'),
                selected: _bonusOnly,
                onSelected: (value) => setState(() => _bonusOnly = value),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(entries.isEmpty)
                : _buildEntryList(filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(QuestStreakSummary summary) {
    return Card(
      key: QuestStreakKeys.summaryCard,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '追跡中 ${summary.trackedCount}件',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(summary.longestStreakLabel,
                    style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 16),
                Text(summary.bonusActiveLabel,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool noRecords) {
    return Center(
      key: QuestStreakKeys.emptyState,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(noRecords ? 'まだストリークがありません。' : '該当するクエストがありません。'),
          const SizedBox(height: 8),
          const Text('クエストを完了すると連続記録が育ちます。'),
        ],
      ),
    );
  }

  Widget _buildEntryList(List<QuestStreakEntry> entries) {
    return ListView.builder(
      key: QuestStreakKeys.list,
      itemCount: entries.length,
      itemBuilder: (context, index) => _buildEntryRow(entries[index]),
    );
  }

  Widget _buildEntryRow(QuestStreakEntry entry) {
    return ListTile(
      title: Text(
        entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(entry.streakLabel, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Text(entry.lastCompletedLabel, style: const TextStyle(fontSize: 12)),
          if (entry.isBonusActive) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.bonusLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}