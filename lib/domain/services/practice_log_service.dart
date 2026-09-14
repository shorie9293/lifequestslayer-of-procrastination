import 'package:rpg_todo/domain/models/practice_log.dart';

/// 勤行の日別履歴ログ（道標§五 #50）を扱う純粋サービス。
///
/// 状態・IO・乱数を持たず、すべて静的関数で完結する（試練可能）。
/// ログは常に「日付昇順・同日重複なし」に正規化して扱う。
class PracticeLogService {
  const PracticeLogService();

  /// [at] の日の完遂を [amount] 件記録した新しいログ一覧を返す。
  ///
  /// 既存の同日ログがあれば回数を加算し、無ければ新規作成する。
  /// [amount] が1未満なら [ArgumentError]。
  static List<PracticeLog> record(
    List<PracticeLog> logs, {
    required DateTime at,
    int amount = 1,
  }) {
    if (amount < 1) {
      throw ArgumentError.value(amount, 'amount', 'must be >= 1');
    }
    final key = PracticeLog.keyOf(at);
    final next = <PracticeLog>[];
    var found = false;
    for (final l in logs) {
      if (l.id == key) {
        found = true;
        next.add(l.copyWith(count: l.count + amount, updatedAt: at));
      } else {
        next.add(l);
      }
    }
    if (!found) {
      next.add(PracticeLog(date: at, count: amount, updatedAt: at));
    }
    return normalize(next);
  }

  /// 日付昇順・同日重複を統合（回数は合算、updatedAt は新しい方）した一覧。
  static List<PracticeLog> normalize(List<PracticeLog> logs) {
    final byKey = <String, PracticeLog>{};
    for (final l in logs) {
      final existing = byKey[l.id];
      if (existing == null) {
        byKey[l.id] = l;
      } else {
        byKey[l.id] = existing.copyWith(
          count: existing.count + l.count,
          updatedAt: l.updatedAt.isAfter(existing.updatedAt)
              ? l.updatedAt
              : existing.updatedAt,
        );
      }
    }
    final list = byKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  /// 日別の完遂回数マップ（日付昇順）。
  static Map<DateTime, int> countsByDay(List<PracticeLog> logs) {
    final map = <DateTime, int>{};
    for (final l in normalize(logs)) {
      map[l.date] = l.count;
    }
    return map;
  }

  /// 「1完遂 = 1件」の日時リストへ展開する。
  ///
  /// [HabitCalendarService] や [GrowthTrajectoryService] が従来受け取っていた
  /// 「日時のリスト」と互換の形。同日複数回は同日付が複数件並ぶ。
  static List<DateTime> expand(List<PracticeLog> logs) {
    final out = <DateTime>[];
    for (final l in normalize(logs)) {
      for (var i = 0; i < l.count; i++) {
        out.add(l.date);
      }
    }
    return out;
  }

  /// 総完遂回数。
  static int totalCount(List<PracticeLog> logs) =>
      normalize(logs).fold(0, (sum, l) => sum + l.count);

  /// ログが記録されている日はログを正とし、ログが無い日だけ旧来ソース
  /// （[Task.lastCompletedAt] / [Reflection.date]）で補完する。
  ///
  /// これによりログ導入前の履歴を失わず、かつログ導入後を二重計上しない。
  /// 旧来ソースの日時も日単位（00:00）に正規化して返す。
  static List<DateTime> mergeActivityDates({
    required List<PracticeLog> logs,
    required List<DateTime> legacyDates,
  }) {
    final normalized = normalize(logs);
    final coveredKeys = {for (final l in normalized) l.id};
    final out = expand(normalized);
    for (final d in legacyDates) {
      if (coveredKeys.contains(PracticeLog.keyOf(d))) continue;
      out.add(PracticeLog.normalizeDate(d));
    }
    return out;
  }

  /// 指定期間（[from], [to] 両端含む）のログのみ抽出（日付昇順）。
  static List<PracticeLog> within(
    List<PracticeLog> logs, {
    required DateTime from,
    required DateTime to,
  }) {
    final start = PracticeLog.normalizeDate(from);
    final end = PracticeLog.normalizeDate(to);
    if (end.isBefore(start)) return const [];
    return normalize(logs)
        .where((l) => !l.date.isBefore(start) && !l.date.isAfter(end))
        .toList();
  }
}
