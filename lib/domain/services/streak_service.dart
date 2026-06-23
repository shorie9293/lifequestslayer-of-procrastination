import 'dart:math';
import 'package:rpg_todo/domain/models/player.dart';

/// ストリーク更新の結果。
class StreakResult {
  /// 付与されたコイン報酬（0の場合は報酬なし）
  final int reward;

  /// ストリークが切断されたかどうか
  final bool wasBroken;

  /// 切断前のストリーク日数（切断されなかった場合は0）
  final int previousStreak;

  /// 新しいストリーク日数
  final int newStreak;

  const StreakResult({
    required this.reward,
    this.wasBroken = false,
    this.previousStreak = 0,
    required this.newStreak,
  });

  /// 切断なし・報酬なしのデフォルト結果
  static const noChange = StreakResult(reward: 0, newStreak: 0);
}

/// ストリーク（連続ログインボーナス）の計算と報酬付与を担当するサービス。
class StreakService {
  /// ストリークを更新し、報酬を付与する。
  /// 戻り値: [StreakResult] — 報酬額・切断情報・新しいストリーク日数
  static StreakResult checkAndUpdateStreak(Player player, DateTime now) {
    final last = player.lastLoginDate;
    final previousStreak = player.streakDays;
    bool wasBroken = false;

    if (last == null) {
      // 初回ログイン
      player.streakDays = 1;
    } else if (_isSameDay(last, now)) {
      // 同日の再起動は何もしない
      return StreakResult(reward: 0, newStreak: player.streakDays);
    } else if (_isYesterday(last, now)) {
      // 昨日ログイン済み → ストリーク継続
      player.streakDays++;
    } else {
      // 2日以上空白 → ストリーク切断
      // 1日以上ストリークがあった場合のみ「切断」とみなす
      if (previousStreak > 1) {
        wasBroken = true;
      }
      player.streakDays = 1;
    }

    player.longestStreak = max(player.longestStreak, player.streakDays);
    player.lastLoginDate = now;

    // ストリーク報酬
    final reward = calcStreakReward(player.streakDays);
    if (reward > 0) {
      player.coins += reward;
    }

    return StreakResult(
      reward: reward,
      wasBroken: wasBroken,
      previousStreak: wasBroken ? previousStreak : 0,
      newStreak: player.streakDays,
    );
  }

  /// ストリーク日数に応じた報酬を計算
  static int calcStreakReward(int days) {
    if (days >= 100) return 10000;
    if (days >= 60) return 8000;
    if (days >= 30) return 5000;
    if (days == 14) return 2000;
    if (days == 7) return 1000;
    if (days == 5) return 500;
    if (days == 3) return 200;
    if (days == 2) return 100;
    return 0;
  }

  /// ストリーク日数に応じたEXP倍率を計算する純粋関数。
  static double calcExpMultiplier(int streakDays) {
    if (streakDays >= 30) return 2.0;
    if (streakDays >= 14) return 1.5;
    if (streakDays >= 7) return 1.2;
    return 1.0;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isYesterday(DateTime past, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return _isSameDay(past, yesterday);
  }
}
