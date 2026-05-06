/// 日付関連のユーティリティ関数
class DateUtils {
  /// 同日かどうかを判定
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// past が now の昨日かどうかを判定
  static bool isYesterday(DateTime past, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return isSameDay(past, yesterday);
  }

  /// ISO 週が異なるかどうかを判定（月またぎに対応）
  static bool isDifferentWeek(DateTime a, DateTime b) {
    final mondayA = a.subtract(Duration(days: a.weekday - 1));
    final mondayB = b.subtract(Duration(days: b.weekday - 1));
    return !isSameDay(
      DateTime(mondayA.year, mondayA.month, mondayA.day),
      DateTime(mondayB.year, mondayB.month, mondayB.day),
    );
  }
}
