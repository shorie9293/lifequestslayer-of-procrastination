import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/domain/models/habit_calendar.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/habit_calendar_service.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/habits/presentation/widgets/habit_month_grid.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';

/// 勤行の習慣カレンダー画面（道標§五 #31）。
///
/// 連続勤行日数（ストリーク）と日別の出席マップを月単位で俯瞰し、
/// 目標リマインドを添える。データ源は勤行完了履歴
/// （[Task.lastCompletedAt]）と討伐後の振り返り（[Reflection.date]）。
class HabitCalendarScreen extends StatefulWidget {
  /// テスト用に注入可能な振り返りリポジトリ。
  final ReflectionRepository? repository;

  /// 基準日（テスト用。既定は現在時刻）。
  final DateTime? now;

  const HabitCalendarScreen({super.key, this.repository, this.now});

  @override
  State<HabitCalendarScreen> createState() => _HabitCalendarScreenState();
}

class _HabitCalendarScreenState extends State<HabitCalendarScreen> {
  late final ReflectionRepository _repo;
  List<Reflection> _reflections = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ReflectionRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _reflections = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('screen_habit_calendar'),
      appBar: AppBar(title: const Text('勤行の習慣カレンダー')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<TaskViewModel>(
              builder: (context, taskVM, _) {
                final activityDates = <DateTime>[
                  for (final t in taskVM.tasks)
                    if (t.lastCompletedAt != null) t.lastCompletedAt!,
                  for (final r in _reflections) r.date,
                ];
                return HabitCalendarView(
                  activityDates: activityDates,
                  now: widget.now ?? DateTime.now(),
                );
              },
            ),
    );
  }
}

/// 勤行カレンダーの本体（Provider非依存・試練可能）。
class HabitCalendarView extends StatefulWidget {
  final List<DateTime> activityDates;
  final DateTime now;

  const HabitCalendarView({
    super.key,
    required this.activityDates,
    required this.now,
  });

  @override
  State<HabitCalendarView> createState() => _HabitCalendarViewState();
}

class _HabitCalendarViewState extends State<HabitCalendarView> {
  /// 観測月からの相対オフセット（0=当月、-1=前月…）。
  int _monthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final base = DateTime(widget.now.year, widget.now.month);
    final target = DateTime(base.year, base.month + _monthOffset);
    final cal = HabitCalendarService.buildMonth(
      activityDates: widget.activityDates,
      year: target.year,
      month: target.month,
      today: widget.now,
    );

    return ListView(
      key: const Key('habit_calendar_view'),
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(cal),
        const SizedBox(height: 16),
        _monthHeader(target),
        const SizedBox(height: 8),
        HabitMonthGrid(month: cal.month),
        const SizedBox(height: 16),
        _goalReminder(cal),
      ],
    );
  }

  Widget _summaryCard(HabitCalendar cal) {
    return Card(
      key: const Key('habit_calendar_summary'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔥 現在の連続勤行 ${cal.currentStreak}日',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _stat('最長連続', '${cal.longestStreak}日'),
                _stat('今月の勤行', '${cal.month.activeDays}日'),
                _stat('通算の勤行', '${cal.totalActiveDays}日'),
                _stat(
                  '今月の達成率',
                  '${(cal.month.completionRate * 100).round()}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader(DateTime target) {
    return Row(
      children: [
        IconButton(
          key: const Key('habit_prev_month'),
          icon: const Icon(Icons.chevron_left),
          tooltip: '前の月',
          onPressed: () => setState(() => _monthOffset--),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${target.year}年${target.month}月',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        IconButton(
          key: const Key('habit_next_month'),
          icon: const Icon(Icons.chevron_right),
          tooltip: '次の月',
          onPressed: () => setState(() => _monthOffset++),
        ),
      ],
    );
  }

  Widget _goalReminder(HabitCalendar cal) {
    final String message;
    if (cal.month.isEmpty) {
      message = '今月はまだ勤行の記録がありません。今日の一歩から始めよう。';
    } else if (cal.month.completionRate >= 0.8) {
      message = '見事な継続なり。この調子で連続記録を伸ばそう。';
    } else if (cal.currentStreak >= 1) {
      message = '${cal.currentStreak}日連続を維持中。明日も勤行を積み重ねよう。';
    } else {
      message = '今日の勤行でストリークを再開しよう。';
    }
    return Card(
      key: const Key('habit_goal_reminder'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
