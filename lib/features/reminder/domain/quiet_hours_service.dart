import 'quiet_hours.dart';
import 'quiet_hours_settings.dart';

/// 静穏時間（おやすみモード）の判定ロジック。
///
/// すべて static・純粋関数。[DateTime.now] は内部で呼ばない
/// （現在時刻は必ず呼び出し側から渡す）。
abstract final class QuietHoursService {
  /// [now] が [startMinutes]〜[endMinutes] の静穏時間内か。
  ///
  /// - start == end は常に false（抑止なし）
  /// - end > start は通常区間 [start, end)
  /// - end < start は日跨ぎ区間 [start, 24:00) ∪ [0:00, end)
  /// 比較は分単位。[now] はローカル時刻として扱う。
  static bool isWithinQuietHours(
    DateTime now,
    int startMinutes,
    int endMinutes,
  ) {
    if (startMinutes == endMinutes) return false;
    final current = now.hour * 60 + now.minute;
    if (endMinutes > startMinutes) {
      return current >= startMinutes && current < endMinutes;
    }
    return current >= startMinutes || current < endMinutes;
  }

  /// 静穏時間内なら終了時刻まで繰り延べた時刻を返す。
  ///
  /// 静穏時間外なら [now] をそのまま返す。繰り延べ先の秒以下は 0。
  static DateTime deferUntil(
    DateTime now,
    int startMinutes,
    int endMinutes,
  ) {
    if (!isWithinQuietHours(now, startMinutes, endMinutes)) return now;
    final endHour = endMinutes ~/ 60;
    final endMin = endMinutes % 60;
    var target = DateTime(now.year, now.month, now.day, endHour, endMin);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return target;
  }

  /// 通知の配送時刻を決める。
  ///
  /// 無効・静穏時間外は [scheduled] をそのまま返す。静穏時間内は
  /// policy が defer なら [deferUntil]、skip なら null（送出しない）。
  static DateTime? resolveDelivery(
    QuietHoursSettings s,
    DateTime scheduled,
  ) {
    if (!s.enabled) return scheduled;
    if (!isWithinQuietHours(scheduled, s.startMinutes, s.endMinutes)) {
      return scheduled;
    }
    if (s.policy == QuietHoursPolicy.skip) return null;
    return deferUntil(scheduled, s.startMinutes, s.endMinutes);
  }

  /// 'HH:mm' 形式（ゼロ埋め）。
  static String formatMinutes(int minutes) =>
      QuietHoursServiceLabel.formatMinutes(minutes);
}

/// 通知送出前の静穏時間ガード。
///
/// [adjust] は送出予定時刻を受け取り、実際に送出する時刻を返す。
/// null は「送出しない」を表す。
abstract class QuietHoursGuard {
  Future<DateTime?> adjust(DateTime scheduled);
}
