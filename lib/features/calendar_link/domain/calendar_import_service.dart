import 'package:rpg_todo/domain/models/task.dart';

import 'linked_calendar_event.dart';

/// 取り込み対象の期間。
enum CalendarImportRange {
  today('今日', 1),
  next3Days('3日以内', 3),
  next7Days('7日以内', 7);

  const CalendarImportRange(this.label, this.days);

  final String label;

  /// 期間の日数（今日を含む）。
  final int days;
}

/// カレンダー予定 → クエストへの変換を担う純粋サービス。
///
/// 端末APIには一切触れない（[LinkedCalendarEvent] を受け取るだけ）ので、
/// 選別・重複除外・ランク付けはすべて単体試練で検証できる。
class CalendarImportService {
  CalendarImportService._();

  /// 取り込んだクエストに付ける札（後から出所を辿るため）。
  static const String importTag = 'カレンダー';

  /// 期間内・未取り込みの予定を、開始が早い順で返す。
  ///
  /// - タイトルが空の予定は除外（クエスト名が無いと討伐できない）
  /// - 期間外は除外（[now] の当日を 1 日目とする）
  /// - 既存クエストと「題名＋日付」が一致するものは除外（二重取り込み防止）
  /// - 予定同士の重複も除外（同一題名・同一日は最初の1件のみ）
  static List<LinkedCalendarEvent> selectCandidates(
    List<LinkedCalendarEvent> events, {
    required DateTime now,
    required CalendarImportRange range,
    List<Task> existing = const <Task>[],
  }) {
    final today = _dayOf(now);
    final lastDay = today.add(Duration(days: range.days - 1));
    final taken = existing
        .where((t) => t.cancelledAt == null)
        .map((t) => dedupeKey(t.title, t.deadline))
        .toSet();
    final seen = <String>{};
    final selected = <LinkedCalendarEvent>[];

    for (final event in events) {
      final title = event.title.trim();
      if (title.isEmpty) continue;
      final day = _dayOf(event.start);
      if (day.isBefore(today) || day.isAfter(lastDay)) continue;
      final key = dedupeKey(title, event.start);
      if (taken.contains(key)) continue;
      if (!seen.add(key)) continue;
      selected.add(event);
    }

    selected.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.title.compareTo(b.title);
    });
    return selected;
  }

  /// 予定1件をクエストへ変換する。[id] は呼び出し側が採番する（試練容易性のため）。
  static Task buildTask(LinkedCalendarEvent event, {required String id}) {
    final minutes = event.allDay ? null : event.durationMinutes;
    return Task(
      id: id,
      title: event.title.trim(),
      rank: rankFor(minutes),
      targetTimeMinutes: (minutes != null && minutes >= 5) ? minutes : null,
      deadline: deadlineFor(event),
      tags: const <String>[importTag],
    );
  }

  /// 予定をまとめてクエストへ変換する。
  static List<Task> buildTasks(
    List<LinkedCalendarEvent> events, {
    required String Function() idGenerator,
  }) {
    return events
        .map((e) => buildTask(e, id: idGenerator()))
        .toList(growable: false);
  }

  /// 所要時間からランクを決める（長いほど高位の討伐対象）。
  /// 終日予定・所要時間不明は B。
  static QuestRank rankFor(int? minutes) {
    if (minutes == null) return QuestRank.B;
    if (minutes >= 90) return QuestRank.S;
    if (minutes >= 45) return QuestRank.A;
    return QuestRank.B;
  }

  /// 完成期限。時刻付き予定は開始時刻、終日予定はその日の終わり。
  static DateTime deadlineFor(LinkedCalendarEvent event) {
    if (!event.allDay) return event.start;
    return DateTime(event.start.year, event.start.month, event.start.day, 23, 59);
  }

  /// 二重取り込み判定のキー（題名の正規化＋日付）。
  static String dedupeKey(String title, DateTime? date) {
    final normalized =
        title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (date == null) return '$normalized|';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$normalized|$y-$m-$d';
  }

  static DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
