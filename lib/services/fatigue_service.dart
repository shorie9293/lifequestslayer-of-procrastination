import '../models/player.dart';

/// 疲労度の計算と宿屋ロジックを担当するサービス。
class FatigueService {
  /// 疲労警告しきい値
  static int warnThreshold(Player player) => 5 + player.todayTaskLimitOffset;

  /// 疲労重度しきい値
  static int severeThreshold(Player player) => 10 + player.todayTaskLimitOffset;

  /// 疲労ステータス文字列
  static String status(Player player) {
    final completed = player.dailyTasksCompleted;
    if (completed >= severeThreshold(player)) return '🌙 今日の英雄は休め';
    if (completed >= warnThreshold(player)) return '🍺 十分戦った';
    return '😄 元気';
  }

  /// 疲労進捗 (0.0〜1.0)
  static double progress(Player player) {
    return (player.dailyTasksCompleted / severeThreshold(player)).clamp(0.0, 1.0);
  }

  /// 疲労補正倍率を計算
  static double fatigueMultiplier(Player player) {
    final completed = player.dailyTasksCompleted;
    if (completed >= severeThreshold(player)) return 0.1;
    if (completed >= warnThreshold(player)) return 0.5;
    return 1.0;
  }

  /// 宿屋に泊まる
  /// 戻り値: null=成功, String=エラーメッセージ
  static String? restAtInn(Player player, int innType, DateTime now) {
    if (player.lastRestDate != null &&
        _isSameDay(player.lastRestDate!, now)) {
      return '今日はもう十分休んだ。また明日来な！';
    }

    int cost = 0;
    int limitBonus = 0;

    switch (innType) {
      case 0:
        cost = 50;
        limitBonus = 2;
        break;
      case 1:
        cost = 200;
        limitBonus = 5;
        break;
      case 2:
        cost = 1000;
        limitBonus = 12;
        break;
      default:
        return 'そんなメニューはないぜ';
    }

    if (player.coins < cost) return '金貨が足りないぜ';

    player.coins -= cost;
    player.nextDayTaskLimitOffset = limitBonus;
    player.lastRestDate = now;
    return null;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
