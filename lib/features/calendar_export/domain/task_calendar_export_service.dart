import 'package:rpg_todo/domain/models/task.dart';

import 'calendar_event.dart';
import 'ics_writer.dart';

/// 書き出し対象の範囲。
enum CalendarExportRange {
  all('すべて'),
  withDeadline('期限あり'),
  next7Days('7日以内'),
  next30Days('30日以内');

  const CalendarExportRange(this.label);

  final String label;
}

/// 未完了クエストの期限を iCalendar へ変換する純粋サービス。
class TaskCalendarExportService {
  TaskCalendarExportService._();

  /// 範囲に応じた対象クエストを選別し、deadline 昇順 → id 昇順で返す。
  ///
  /// 完了済み・取消済みは常に除外する。期限なしは末尾に置く。
  static List<Task> selectTasks(
    List<Task> tasks,
    CalendarExportRange range, {
    required DateTime now,
  }) {
    final active =
        tasks.where((t) => !t.isCompleted && t.cancelledAt == null).toList();

    switch (range) {
      case CalendarExportRange.all:
        return _sorted(active);
      case CalendarExportRange.withDeadline:
        return _sorted(active.where((t) => t.deadline != null).toList());
      case CalendarExportRange.next7Days:
      case CalendarExportRange.next30Days:
        final end = _dayOf(now).add(
            Duration(days: range == CalendarExportRange.next7Days ? 7 : 30));
        return _sorted(active.where((t) {
          final d = t.deadline;
          if (d == null) return false;
          final day = _dayOf(d);
          final today = _dayOf(now);
          return !day.isBefore(today) && !day.isAfter(end);
        }).toList());
    }
  }

  /// 期限付きクエストを CalendarEvent へ変換する。
  static List<CalendarEvent> buildEvents(List<Task> tasks) {
    return tasks.where((t) => t.deadline != null).map((t) {
      final estimate = t.targetTimeMinutes;
      return CalendarEvent(
        uid: 'task-${t.id}@takamagahara',
        date: t.deadline!,
        summary: t.title,
        description: estimate == null
            ? 'ランク ${t.rank.name}'
            : 'ランク ${t.rank.name} / 見積 $estimate分',
      );
    }).toList();
  }

  /// 選別 → 変換 → .ics 文字列。
  static String exportIcs(
    List<Task> tasks,
    CalendarExportRange range, {
    required DateTime now,
  }) {
    final selected = selectTasks(tasks, range, now: now);
    return IcsWriter.write(buildEvents(selected));
  }

  static List<Task> _sorted(List<Task> tasks) {
    final list = [...tasks]..sort((a, b) {
        final da = a.deadline;
        final db = b.deadline;
        if (da == null && db == null) return a.id.compareTo(b.id);
        if (da == null) return 1;
        if (db == null) return -1;
        final byDate = da.compareTo(db);
        if (byDate != 0) return byDate;
        return a.id.compareTo(b.id);
      });
    return list;
  }

  static DateTime _dayOf(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day);
}
