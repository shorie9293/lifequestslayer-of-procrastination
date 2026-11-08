// 寄合所のクエスト検索・絞り込み・並び替え画面（改善提案 #80）
//
// ドメイン層 GuildQuestQuery / GuildQuestQueryService に全ロジックを委譲する
// 薄いプレゼンテーション層。tasksOverride / now は試練（テスト）用の注入点。
//
// 検索条件（検索語・絞り込み・並び順）の永続化は queryPreferences 注入時のみ有効。
// 未注入なら従来どおりメモリ内の状態だけで動く。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:rpg_todo/core/search/search_history.dart';
import 'package:rpg_todo/core/search/search_history_chips.dart';
import 'package:rpg_todo/core/search/search_history_store.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/core/theme/rank_colors.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/guild_quest_query_preferences.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query.dart';
import 'package:rpg_todo/features/guild/domain/guild_quest_query_service.dart';
import 'package:rpg_todo/features/guild/domain/quest_tag_service.dart';
import 'package:rpg_todo/features/guild/presentation/dialogs/quest_tag_edit_dialog.dart';
import 'package:rpg_todo/features/guild/presentation/widgets/task_card.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';

class GuildQuestSearchScreen extends StatefulWidget {
  const GuildQuestSearchScreen({
    super.key,
    this.tasksOverride,
    this.now,
    this.onTagsSaved,
    this.queryPreferences,
    this.searchHistoryStore,
  });

  /// 試練用: Provider なしでクエスト一覧を注入できる
  final List<Task>? tasksOverride;

  /// 試練用: 期日超過判定の基準時刻を固定できる
  final DateTime? now;

  /// 札（タグ）編集の保存先。null なら札編集導線を出さない。
  final void Function(Task task, List<String> tags)? onTagsSaved;

  /// 検索条件の保存先。null なら永続化しない（従来の挙動）。
  final GuildQuestQueryPreferencesStore? queryPreferences;

  /// 検索語履歴の保存先。null なら本番の SharedPreferences 実装を使う。
  final SearchHistoryStore? searchHistoryStore;

  @override
  State<GuildQuestSearchScreen> createState() => _GuildQuestSearchScreenState();
}

class _GuildQuestSearchScreenState extends State<GuildQuestSearchScreen> {
  GuildQuestQuery _query = const GuildQuestQuery();

  /// 検索語の編集コントローラ（復元時に保存済みの検索語を流し込む）
  final TextEditingController _textController = TextEditingController();

  /// 利用者が一度でも条件を触ったか。復元の遅延到着で入力を潰さないための番人。
  bool _userTouched = false;

  /// 検索語の履歴（新しい順）。
  SearchHistory _history = const SearchHistory.empty();

  @override
  void initState() {
    super.initState();
    final store = widget.queryPreferences;
    if (store != null) {
      unawaited(_restore(store));
    }
    unawaited(_loadHistory(widget.searchHistoryStore ??
        const SharedPreferencesSearchHistoryStore()));
  }

  @override
  void dispose() {
    // 検索語は確定（onSubmitted）まで書かないため、画面を閉じる時に一度だけ保存する
    _persist();
    // 履歴も同じ方針: 1文字ごとではなく、閉じる時に非空の語だけを積む
    _rememberHistory(_query.text);
    _textController.dispose();
    super.dispose();
  }

  /// 保存済みの検索語履歴を読み込む。既に積んだ語があれば上書きしない。
  Future<void> _loadHistory(SearchHistoryStore store) async {
    final loaded = await store.load();
    if (!mounted || _history.isNotEmpty) return;
    setState(() => _history = loaded);
  }

  /// 現在の語を履歴の先頭へ積み、投げっぱなしで保存する。
  ///
  /// 空語は積まない。保存失敗は検索の邪魔をしない。
  void _rememberHistory(String raw) {
    final store = widget.searchHistoryStore ??
        const SharedPreferencesSearchHistoryStore();
    if (raw.trim().isEmpty) return;
    final next = _history.add(raw);
    if (identical(next, _history)) return;
    _history = next;
    unawaited(store.save(next).catchError((Object _) {}));
  }

  /// 履歴チップの語を検索欄へ反映し、結果を再計算する。
  void _applyHistoryTerm(String term) {
    _userTouched = true;
    _applyTextToController(term);
    setState(() => _query = _query.copyWith(text: term));
  }

  /// 保存済み条件を復元する。利用者が先に触っていたら上書きしない。
  Future<void> _restore(GuildQuestQueryPreferencesStore store) async {
    final loaded = await store.load();
    if (!mounted || loaded == null) return;
    if (_userTouched) return;
    setState(() {
      _query = loaded;
      _applyTextToController(loaded.text);
    });
  }

  void _applyTextToController(String text) {
    if (_textController.text == text) return;
    _textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 現在の条件を投げっぱなしで保存する（失敗しても検索は続く）。
  void _persist() {
    final store = widget.queryPreferences;
    if (store == null) return;
    unawaited(store.save(_query).catchError((Object _) {}));
  }

  Color _rankColor(QuestRank rank) => RankColors.forRank(rank);

  void _toggleStatus(GuildQuestStatusFilter f) {
    _userTouched = true;
    setState(() {
      final next = Set<GuildQuestStatusFilter>.of(_query.statuses);
      if (!next.add(f)) {
        next.remove(f);
      }
      _query = _query.copyWith(statuses: next);
    });
    _persist();
  }

  void _toggleRank(QuestRank r) {
    _userTouched = true;
    setState(() {
      final next = Set<QuestRank>.of(_query.ranks);
      if (!next.add(r)) {
        next.remove(r);
      }
      _query = _query.copyWith(ranks: next);
    });
    _persist();
  }

  /// 札（タグ）の選択トグル。選択は OR（QuestTagService.matchesTags の意味論）。
  void _toggleTag(String tag) {
    _userTouched = true;
    setState(() {
      final next = Set<String>.of(_query.tags);
      if (!next.add(tag)) {
        next.remove(tag);
      }
      _query = _query.copyWith(tags: next);
    });
    _persist();
  }

  /// 札編集ダイアログを開く。onTagsSaved 未注入（試練の後方互換）なら何もしない。
  Future<void> _openTagEditor(Task task) async {
    if (widget.onTagsSaved == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => QuestTagEditDialog(
        taskTitle: task.title,
        initialTags: List<String>.of(task.tags),
        onSave: (tags) {
          widget.onTagsSaved?.call(task, tags);
          // 呼び出し元が同じ Task を書き換える場合に備え、表示を同期する
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasksOverride ??
        Provider.of<TaskViewModel>(context, listen: false).guildTasks;
    final results =
        GuildQuestQueryService.apply(tasks, _query, now: widget.now);
    // 札の件数は絞り込み前の全件から集計する
    final tagCounts = QuestTagService.counts(tasks);
    final showTagEdit =
        widget.tasksOverride == null || widget.onTagsSaved != null;

    return Scaffold(
      key: AppKeys.guildQuestSearchScreen,
      appBar: AppBar(title: const Text('クエスト検索')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: TextField(
              key: AppKeys.guildQuestSearchField,
              controller: _textController,
              decoration: InputDecoration(
                hintText: 'クエスト名・タグで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isNotEmpty
                    ? IconButton(
                        key: AppKeys.guildQuestSearchClear,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _userTouched = true;
                          _textController.clear();
                          setState(() => _query = _query.copyWith(text: ''));
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                // 検索語は1文字ごとには保存しない（確定時と閉じる時のみ）
                _userTouched = true;
                setState(() => _query = _query.copyWith(text: value));
              },
              onSubmitted: (_) {
                _userTouched = true;
                _persist();
                // 履歴へ積むのは確定時のみ（1文字ごとには積まない）
                setState(() => _rememberHistory(_query.text));
              },
            ),
          ),
          SearchHistoryChips(
            entries: _history.entries,
            onSelected: _applyHistoryTerm,
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
          if (tagCounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final stat in tagCounts)
                    FilterChip(
                      key: AppKeys.guildQuestTagChip(stat.tag),
                      label: Text('${stat.tag} (${stat.count})'),
                      selected: _query.tags.contains(stat.tag),
                      onSelected: (_) => _toggleTag(stat.tag),
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
                    _userTouched = true;
                    setState(() => _query = _query.copyWith(sortOrder: order));
                    _persist();
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
                    _userTouched = true;
                    _textController.clear();
                    setState(() => _query = const GuildQuestQuery());
                    _persist();
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
                          trailing: showTagEdit
                              ? IconButton(
                                  key: AppKeys.questTagEditButton(task.id),
                                  icon: const Icon(Icons.label_outline),
                                  tooltip: '札を編集',
                                  onPressed: () => _openTagEditor(task),
                                )
                              : null,
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
