import 'package:flutter/foundation.dart';

/// 冒険の戦績を1枚のシェアカードとして表現する不変データ。
@immutable
class AdventureShareCard {
  const AdventureShareCard({
    required this.rankLabel,
    required this.level,
    required this.totalTasksCompleted,
    required this.totalSRankCompleted,
    required this.wardenDefeated,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalReflections,
  });

  final String rankLabel;
  final int level;
  final int totalTasksCompleted;
  final int totalSRankCompleted;
  final int wardenDefeated;
  final int currentStreak;
  final int longestStreak;
  final int totalReflections;

  /// いずれかの戦績値が 0 より大きければ true。
  bool get hasProgress =>
      totalTasksCompleted > 0 ||
      totalSRankCompleted > 0 ||
      wardenDefeated > 0 ||
      currentStreak > 0 ||
      longestStreak > 0 ||
      totalReflections > 0;

  /// 例: 'Lv.12'
  String get levelLabel => 'Lv.$level';
}
