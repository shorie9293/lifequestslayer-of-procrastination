/// バックグラウンド復帰時に再施錠するかを決める純粋ロジック。
///
/// 時刻は必ず引数で受け取り、内部で `DateTime.now` を読まない（試練容易性）。
class LockReloadPolicy {
  /// 設定画面で選べる猶予時間（秒）。
  static const List<int> graceOptionsSeconds = [0, 30, 60, 300];

  /// 猶予時間の表示ラベル。
  static String graceLabel(int seconds) {
    switch (seconds) {
      case 0:
        return '即時';
      case 30:
        return '30秒';
      case 60:
        return '1分';
      case 300:
        return '5分';
      default:
        return '$seconds秒';
    }
  }

  /// 再施錠すべきか。
  ///
  /// - [backgroundedAt] が null（背景化を観測していない）→ true
  /// - 猶予が 0 以下 → true
  /// - 猶予内 → false
  /// - 境界ちょうど・超過 → true
  /// - 時計巻き戻し（now < backgroundedAt）→ true（安全側）
  static bool shouldRelock(
    DateTime? backgroundedAt,
    DateTime now,
    Duration grace,
  ) {
    if (backgroundedAt == null) return true;
    if (grace <= Duration.zero) return true;
    if (now.isBefore(backgroundedAt)) return true;
    final elapsed = now.difference(backgroundedAt);
    return !elapsed.isNegative && elapsed >= grace;
  }
}
