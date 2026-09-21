// 寄合所のクエスト検索・絞り込み・並び替え画面（改善提案 #80）
//
// ドメイン層 GuildQuestQuery / GuildQuestQueryService に全ロジックを委譲する
// 薄いプレゼンテーション層。tasksOverride / now は試練（テスト）用の注入点。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query_service.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';

class GuildQuestSearchScreen extends StatefulWidget {
  const GuildQuestSearchScreen({super.key, this.tasksOverride, this.now});

  /// 試練用: Provider なしでクエスト一覧を注入できる
  final List<Task>? tasksOverride;

  /// 試練用: 期日超過判定の基準時刻を固定できる
  final DateTime? now;

  @override
  State<GuildQuestSearchScreen> createState() => _GuildQuestSearchScreenState();
}

class _GuildQuestSearchScreenState extends State<GuildQuestSearchScreen> {
  GuildQuestQuery _query = const GuildQuestQuery();

  Color _rankColor(QuestRank rank) => RankColors.forRank(rank);

  void _toggleStatus(GuildQuestStatusFilter f) {
    setState(() {
      final next = Set<GuildQuestStatusFilter>.of(_query.statuses);
      if (!next.add(f)) {
        next.remove(f);
      }
      _query = _query.copyWith(statuses: next);
    });
  }

  void _toggleRank(QuestRank r) {
    setState(() {
      final next = Set<QuestRank>.of(_query.ranks);
      if (!next.add(r)) {
        next.remove(r);
      }
      _query = _query.copyWith(ranks: next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasksOverride ??
        Provider.of<TaskViewModel>(context, listen: false).guildTasks;
    final results = GuildQuestQueryService.apply(tasks, _query, now: widget.now);

    return Scaffold(
      key: AppKeys.guildQuestSearchScreen,
      appBar: AppBar(title: const Text('クエスト検索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              key: AppKeys.guildQuestSearchField,
              decoration: InputDecoration(
                hintText: 'クエスト名・タグで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isNotEmpty
                    ? IconButton(
                        key: AppKeys.guildQuestSearchClear,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() => _query = _query.copyWith(text: ''));
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() => _query = _query.copyWith(text: value));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final f in GuildQuestStatusFilter.values)
                  FilterChip(
                    key: AppKeys.guildQuestStatusChip(f.name),
                    label: Text(f.label),
                    selected: _query.statuses.contains(f),
                    onSelected: (_) => _toggleStatus(f),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final r in QuestRank.values)
                  FilterChip(
                    key: AppKeys.guildQuestRankChip(r.name),
                    label: Text('${r.name}ランク'),
                    selected: _query.ranks.contains(r),
                    onSelected: (_) => _toggleRank(r),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                PopupMenuButton<GuildQuestSortOrder>(
                  key: AppKeys.guildQuestSortMenu,
                  tooltip: '並び替え',
                  onSelected: (order) {
                    setState(() => _query = _query.copyWith(sortOrder: order));
                  },
                  itemBuilder: (context) => [
                    for (final order in GuildQuestSortOrder.values)
                      PopupMenuItem<GuildQuestSortOrder>(
                        value: order,
                        child: Text(order.label),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sort),
                      const SizedBox(width: 4),
                      Text(_query.sortOrder.label),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
                IconButton(
                  key: AppKeys.guildQuestSearchReset,
                  icon: const Icon(Icons.restart_alt),
                  tooltip: '絞り込みを解除',
                  onPressed: () {
                    setState(() => _query = const GuildQuestQuery());
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${results.length}件',
                key: AppKeys.guildQuestResultCount,
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    key: AppKeys.guildQuestEmptyState,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.search_off, size: 48),
                        SizedBox(height: 8),
                        Text('条件に合うクエストがない。'),
                      ],
                    ),
                  )
                : ListView.builder(
                    key: AppKeys.guildQuestResultList,
                    itemCount: results.length,
                    itemBuilder: (_, i) {
                      final task = results[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TaskCard(
                          task: task,
                          actions: const [],
                          isUrgent: task.deadline != null &&
                              task.deadline!.isBefore(
                                  DateTime.now().add(const Duration(days: 1))),
                          color: _rankColor(task.rank),
                          titleOverride: '[${task.rank.name}] ${task.title}',
                          hideCountdown: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}