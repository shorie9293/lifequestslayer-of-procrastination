import 'package:flutter/material.dart';
import 'package:rpg_todo/features/battle/domain/battle_record.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_summary.dart';
import 'package:rpg_todo/features/battle/domain/battle_record_service.dart';
import 'package:rpg_todo/features/battle/data/battle_record_repository.dart';
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

  @override
  State<BattleRecordScreen> createState() => _BattleRecordScreenState();
}

class _BattleRecordScreenState extends State<BattleRecordScreen> {
  static const int _maxHistoryEntries = 50;

  bool _loading = true;
  List<BattleRecord> _records = const [];
  // 0=すべて, 1=勝利のみ, 2=敗北のみ
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _records = const [];
        _loading = false;
      });
    }
  }

  /// `yyyy/MM/dd HH:mm` 形式に整形する（intl 不依存・試練可能な純粋関数）。
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmpty()
              : ListView(
                  key: AppKeys.battleRecordHistoryList,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSummaryCard(summary),
                    const SizedBox(height: 12),
                    _buildFilterChips(),
                    const SizedBox(height: 8),
                    ...visible.map(_buildRecordTile),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        key: AppKeys.battleRecordEmpty,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'まだ討伐戦績がありません。\nクエストを討伐すると記録されます。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
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
