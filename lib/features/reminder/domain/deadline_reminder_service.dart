/// 締切リマインドの純粋ロジック。
///
/// Flutter / IO 依存なし。全メソッドは入力（クエスト群・now・設定）のみから
/// 決定的に算出する。`DateTime.now()` を直読みしない（時限爆弾の回避）。
library;

import '../../../domain/models/task.dart';
import 'deadline_reminder_settings.dart';

/// 締切の区分。
enum DeadlineBucket {
  /// 当日締切。
  today,

  /// 翌日締切。
  tomorrow,

  /// それ以降（設定した範囲内）。
  later,
}

class DeadlineReminderService {
  const DeadlineReminderService();

  /// その日の 0:00:00。
  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// その日の 23:59:59.999。
  DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// 期限間近のクエストを抽出する。
  ///
  /// 条件:
  /// - 未完了（`isCompleted == false`）かつ取消済みでない（`cancelledAt == null`）
  /// - `deadline != null` かつ [now] の当日 0:00 以降
  /// - [now] の当日から `withinDays` 日後（当日を含む）の 23:59:59.999 以前
  ///
  /// 並び順は期限昇順、同時刻は id 昇順（安定）。入力を破壊しない。
  List<Task> selectUpcoming(
    List<Task> tasks,
    DateTime now, {
    required int withinDays,
  }) {
    if (withinDays < 1) {
      throw ArgumentError.value(withinDays, 'withinDays', '1以上で指定せよ');
    }
    final from = startOfDay(now);
    final until = endOfDay(from.add(Duration(days: withinDays - 1)));
    final selected = <Task>[];
    for (final t in tasks) {
      if (t.isCompleted) continue;
      if (t.cancelledAt != null) continue;
      final d = t.deadline;
      if (d == null) continue;
      if (d.isBefore(from)) continue;
      if (d.isAfter(until)) continue;
      selected.add(t);
    }
    selected.sort((a, b) {
      final byDeadline = a.deadline!.compareTo(b.deadline!);
      if (byDeadline != 0) return byDeadline;
      return a.id.compareTo(b.id);
    });
    return selected;
  }

  /// [task] がどの区分に属するか。期限なしは [DeadlineBucket.later] を返す
  /// （抽出対象外の要素を渡した場合の安全側の既定）。
  DeadlineBucket bucketOf(Task task, DateTime now) {
    final d = task.deadline;
    if (d == null) return DeadlineBucket.later;
    final today = startOfDay(now);
    final dd = startOfDay(d);
    if (dd == today) return DeadlineBucket.today;
    if (dd == today.add(const Duration(days: 1))) {
      return DeadlineBucket.tomorrow;
    }
    return DeadlineBucket.later;
  }

  /// 区分の日本語ラベル。
  String bucketLabel(DeadlineBucket bucket) {
    switch (bucket) {
      case DeadlineBucket.today:
        return '本日締切';
      case DeadlineBucket.tomorrow:
        return '明日締切';
      case DeadlineBucket.later:
        return '以降の締切';
    }
  }

  /// 通知本文を組み立てる。対象が空なら null（＝通知しない）。
  ///
  /// [maxNames] は **全体**で列挙するクエスト名の上限。超えた分は
  /// 「ほかN件」として総件数とともに示す。
  String? buildBody(
    List<Task> selected,
    DateTime now, {
    int maxNames = 3,
  }) {
    if (selected.isEmpty) return null;
    if (maxNames < 1) {
      throw ArgumentError.value(maxNames, 'maxNames', '1以上で指定せよ');
    }
    final grouped = <DeadlineBucket, List<String>>{
      DeadlineBucket.today: <String>[],
      DeadlineBucket.tomorrow: <String>[],
      DeadlineBucket.later: <String>[],
    };
    for (final t in selected) {
      grouped[bucketOf(t, now)]!.add(t.title);
    }
    final lines = <String>[];
    var listed = 0;
    for (final bucket in const [
      DeadlineBucket.today,
      DeadlineBucket.tomorrow,
      DeadlineBucket.later,
    ]) {
      final names = grouped[bucket]!;
      if (names.isEmpty) continue;
      final remainingSlots = maxNames - listed;
      final shown = remainingSlots <= 0
          ? const <String>[]
          : names.take(remainingSlots).toList();
      listed += shown.length;
      final hiddenInBucket = names.length - shown.length;
      final buffer = StringBuffer('${bucketLabel(bucket)}: ');
      if (shown.isEmpty) {
        buffer.write('${names.length}件');
      } else {
        buffer.write(shown.join('、'));
        if (hiddenInBucket > 0) {
          buffer.write(' ほか$hiddenInBucket件');
        }
      }
      lines.add(buffer.toString());
    }
    if (selected.length > listed) {
      lines.add('（3日以内の合計${selected.length}件）');
    }
    return lines.join('\n');
  }

  /// 通知タイトル。件数を含める。
  String buildTitle(int total) => '⏳ 締切の刻（$total件）';

  /// 'HH:mm'（ゼロ埋め）。
  String timeLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// [now] 以降で次に通知が発火する日時。無効なら null。
  DateTime? nextOccurrence(DeadlineReminderSettings s, DateTime now) {
    if (!s.enabled) return null;
    final todayAtTime = DateTime(now.year, now.month, now.day, s.hour, s.minute);
    if (now.isBefore(todayAtTime)) return todayAtTime;
    final tomorrow = todayAtTime.add(const Duration(days: 1));
    return DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      s.hour,
      s.minute,
    );
  }

  /// 画面表示用の要約。対象0件なら「対象なし」。
  String previewLabel(List<Task> selected, DateTime now) {
    if (selected.isEmpty) return '本日から対象期間内に締切のクエストはありません';
    final body = buildBody(selected, now);
    return '対象 ${selected.length}件\n$body';
  }
}
