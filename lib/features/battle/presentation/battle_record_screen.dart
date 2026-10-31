import 'package:flutter/material.dart';
import 'package:rpg_todo/core/utils/load_state.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_aggregation.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_summary.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_service.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
import 'package:rpg_todo/features/battle/presentation/enemy_catalog_screen.dart';
import 'package:rpg_todo/features/shared/widgets/load_state_views.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// 討伐戦績の俯瞰画面（改善提案 #56）。
///
/// [BattleRecordRepository] を注入でき、日時も [now] で差し替え可能なため
/// 実 Hive に依存せず試練可能。
class BattleRecordScreen extends StatefulWidget {
  final BattleRecordRepository repository;

  /// 表示基準日時（試練用に注入できる）。null なら現在時刻。
  final DateTime? now;

  const BattleRecordScreen({super.key, required this.repository, this.now});

  /// `yyyy/MM/dd HH:mm` 形式（他画面からも再利用可能な公開ラッパ）。
  static String formatTimestamp(DateTime dt) =>
      _BattleRecordScreenState.formatTimestamp(dt);

  @override
  State<BattleRecordScreen> createState() => _BattleRecordScreenState();
}

class _BattleRecordScreenState extends State<BattleRecordScreen> {
  static const int _maxHistoryEntries = 50;

  /// 既存の空状態文言（不変）。
  static const String _emptyMessage =
      'まだ討伐戦績がありません。\nクエストを討伐すると記録されます。';

  LoadState<List<BattleRecord>> _state = LoadState.loading();
  List<BattleRecord> _records = const [];
  // 0=すべて, 1=勝利のみ, 2=敗北のみ
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BattleRecordScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // リポジトリ差し替え時は読み直す（試練・配線切替用）。
    if (!identical(oldWidget.repository, widget.repository)) {
      _load();
    }
  }

  Future<void> _load() async {
    LoadResult<List<BattleRecord>> result;
    try {
      result = await widget.repository.tryLoad();
    } catch (error) {
      result = LoadResult<List<BattleRecord>>.failure(
        '討伐戦績を読み込めませんでした',
        cause: error,
      );
    }
    if (!mounted) return;
    setState(() {
      if (result.isSuccess) {
        final records = result.valueOrNull ?? const <BattleRecord>[];
        _records = records;
        _state = records.isEmpty ? LoadState.empty() : LoadState.data(records);
      } else {
        // 失敗時は既存データを消さない（従来は空リストへ潰していた）。
        _state = LoadState.error(
          result.message ?? '討伐戦績を読み込めませんでした',
          retryable: result.retryable,
          cause: result.cause,
        );
      }
    });
  }

  static String formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y/$m/$d $hh:$mm';
  }

  List<BattleRecord> get _visibleRecords {
    final filtered = switch (_filter) {
      1 => BattleRecordService.filterByResult(_records, true),
      2 => BattleRecordService.filterByResult(_records, false),
      _ => _records,
    };
    return BattleRecordService.recent(filtered, _maxHistoryEntries);
  }

  @override
  Widget build(BuildContext context) {
    final summary = BattleRecordService.summarize(_records);
    final visible = _visibleRecords;

    return Scaffold(
      key: AppKeys.battleRecordScreen,
      appBar: AppBar(
        title: const Text('討伐戦績'),
        actions: [
          IconButton(
            key: AppKeys.enemyCatalogEntry,
            icon: const Icon(Icons.menu_book),
            tooltip: '敵討伐図鑑',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      EnemyCatalogScreen(repository: widget.repository),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(summary, visible),
    );
  }

  Widget _buildBody(BattleRecordSummary summary, List<BattleRecord> visible) {
    if (_state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_state.isError) {
      final message = _state.message ?? '討伐戦績を読み込めませんでした';
      final retry = _state.retryable ? _load : null;
      if (_records.isEmpty) {
        return LoadErrorView(message: message, onRetry: retry);
      }
      // 既存データは保持したまま、失敗を上部の帯で知らせる。
      return Column(
        children: [
          Container(
            key: const ValueKey('load_error_banner'),
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
                if (retry != null)
                  TextButton(
                    key: const ValueKey('load_retry_button'),
                    onPressed: retry,
                    child: const Text('再試行'),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildList(summary, visible)),
        ],
      );
    }
    if (_state.isEmpty) {
      // 既存の空状態 Key と文言は不変に保つ。
      return KeyedSubtree(
        key: AppKeys.battleRecordEmpty,
        child: const LoadEmptyView(message: _emptyMessage),
      );
    }
    return _buildList(summary, visible);
  }

  Widget _buildList(BattleRecordSummary summary, List<BattleRecord> visible) {
    return ListView(
      key: AppKeys.battleRecordHistoryList,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(summary),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildEnemyStatsSection()),
            const SizedBox(width: 8),
            Expanded(child: _buildMonthlyStatsSection()),
          ],
        ),
        const SizedBox(height: 12),
        _buildFilterChips(),
        const SizedBox(height: 8),
        ...visible.map(_buildRecordTile),
      ],
    );
  }

  Widget _buildSummaryCard(BattleRecordSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '通算戦績: ${summary.wins}勝 ${summary.losses}敗',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('勝率: ${BattleRecordService.winRateLabel(summary.winRate)}'),
            if (summary.currentWinStreak > 0)
              Text('現在の連勝: ${summary.currentWinStreak}連勝'),
            if (summary.currentLoseStreak > 0)
              Text('現在の連敗: ${summary.currentLoseStreak}連敗'),
            Text('最長連勝: ${summary.longestWinStreak}連勝'),
          ],
        ),
      ),
    );
  }

  Widget _buildEnemyStatsSection() {
    final stats = BattleRecordAggregationService.buildEnemyStats(_records);
    return Card(
      key: AppKeys.battleRecordEnemyStatsSection,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '敵別戦績',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...stats.map(
              (stat) => ListTile(
                key: AppKeys.battleRecordEnemyStatRow(stat.assetPath),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(stat.displayName),
                subtitle: Text(
                  '最終: '
                  '${stat.lastDefeatedAt == null ? '—' : _formatDateOnly(stat.lastDefeatedAt!)}',
                ),
                trailing: Text('${stat.wins}勝 ${stat.losses}敗'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStatsSection() {
    final stats = BattleRecordAggregationService.buildMonthlyStats(_records);
    return Card(
      key: AppKeys.battleRecordMonthlyStatsSection,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '月別戦績',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...stats.map(
              (stat) => ListTile(
                key: AppKeys.battleRecordMonthlyStatRow(stat.yearMonth),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(stat.label),
                subtitle: Text('${stat.wins}勝 ${stat.losses}敗'),
                trailing: Text('${stat.defeats}回'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  Widget _buildFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          key: AppKeys.battleRecordFilterAll,
          label: const Text('すべて'),
          selected: _filter == 0,
          onSelected: (_) => setState(() => _filter = 0),
        ),
        FilterChip(
          key: AppKeys.battleRecordFilterVictory,
          label: const Text('勝利のみ'),
          selected: _filter == 1,
          onSelected: (_) => setState(() => _filter = 1),
        ),
        FilterChip(
          key: AppKeys.battleRecordFilterDefeat,
          label: const Text('敗北のみ'),
          selected: _filter == 2,
          onSelected: (_) => setState(() => _filter = 2),
        ),
      ],
    );
  }

  Widget _buildRecordTile(BattleRecord record) {
    final color = record.isVictory ? Colors.green : Colors.red;
    final mark = record.isVictory ? '⚔ 勝利' : '💀 敗北';
    return Card(
      child: ListTile(
        leading: Icon(
          record.isVictory ? Icons.emoji_events : Icons.sentiment_very_dissatisfied,
          color: color,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.title),
            Text(
              mark,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ],
        ),
        subtitle: Text(formatTimestamp(record.occurredAt)),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (record.comboCount > 0) Text('${record.comboCount}コンボ'),
            if (record.remainingSubTasks > 0)
              Text('残り${record.remainingSubTasks}件'),
          ],
        ),
      ),
    );
  }
}
