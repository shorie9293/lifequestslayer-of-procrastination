import 'dart:math' as math;

/// パスコード試行回数とロックアウトを決める純粋ロジック。
///
/// 時刻は必ず引数で受け取り、内部で `DateTime.now` を読まない（試練容易性）。
class LockAttemptPolicy {
  /// 猶予される失敗回数（これ未満はロックアウトしない）。
  static const int maxFreeAttempts = 5;

  /// 最初のロックアウト時間。
  static const Duration baseLockout = Duration(seconds: 30);

  /// ロックアウトの上限。
  static const Duration maxLockout = Duration(minutes: 15);

  /// ロックアウト中か。
  static bool isLockedOut(DateTime? lockedUntil, DateTime now) =>
      lockedUntil != null && now.isBefore(lockedUntil);

  /// 失敗回数に対するロックアウト時間。
  ///
  /// 5回未満は 0。5回で 30 秒、以降 5 回ごとに倍々、15 分で頭打ち。
  static Duration lockoutFor(int failedAttempts) {
    if (failedAttempts < maxFreeAttempts) return Duration.zero;
    final steps = (failedAttempts - maxFreeAttempts) ~/ 5;
    var seconds = baseLockout.inSeconds;
    for (var i = 0; i < steps; i++) {
      if (seconds >= maxLockout.inSeconds) break;
      seconds *= 2;
    }
    return Duration(seconds: math.min(seconds, maxLockout.inSeconds));
  }

  /// 残り秒数（切り上げ・過去/負は 0）。
  static int remainingSeconds(DateTime lockedUntil, DateTime now) {
    final diff = lockedUntil.difference(now);
    if (diff <= Duration.zero) return 0;
    return (diff.inMilliseconds / 1000).ceil();
  }

  /// ロックアウト中の案内文。
  static String lockoutLabel(int remainingSeconds) =>
      'しばらく待ってから再試行してください（残り$remainingSeconds秒）';
}
