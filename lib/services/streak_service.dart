import 'dart:math';
import '../models/player.dart';

/// ストリーク（連続ログインボーナス）の計算と報酬付与を担当するサービス。
class StreakService {
  /// ストリークを更新し、報酬を付与する。
  /// 戻り値: 付与された金貨の量（0の場合は報酬なし）
  static int checkAndUpdateStreak(Player player, DateTime now) {
    final last = player.lastLoginDate;

    if (last == null) {
      // 初回ログイン
      player.streakDays = 1;
    } else if (_isSameDay(last, now)) {
      // 同日の再起動は何もしない
      return 0;
    } else if (_isYesterday(last, now)) {
      // 昨日ログイン済み → ストリーク継続
      player.streakDays++;
    } else {
      // 2日以上空白 → リセット
      player.streakDays = 1;
    }

    player.longestStreak = max(player.longestStreak, player.streakDays);
    player.lastLoginDate = now;

    // ストリーク報酬
    final reward = calcStreakReward(player.streakDays);
    if (reward > 0) {
      player.coins += reward;
    }
    return reward;
  }

  /// ストリーク日数に応じた報酬を計算
  static int calcStreakReward(int days) {
    if (days == 30) return 5000;
    if (days == 14) return 2000;
    if (days == 7)  return 1000;
    if (days == 5)  return 500;
    if (days == 3)  return 200;
    if (days == 2)  return 100;
    return 0;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isYesterday(DateTime past, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return _isSameDay(past, yesterday);
  }
}
