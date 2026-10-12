import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/domain/adventure_share_card.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart_service.dart';

/// Player からシェアカードを組み立て、SNS共有用テキストを生成する純粋ロジック。
class AdventureShareCardService {
  const AdventureShareCardService._();

  static AdventureShareCard build(Player player) {
    int clampNonNegative(int v) => v < 0 ? 0 : v;
    return AdventureShareCard(
      rankLabel:
          AdventurerChartService.rankLabelFor(clampNonNegative(player.totalTasksCompleted)),
      level: clampNonNegative(player.level),
      totalTasksCompleted: clampNonNegative(player.totalTasksCompleted),
      totalSRankCompleted: clampNonNegative(player.totalSRankCompleted),
      wardenDefeated: clampNonNegative(player.timesWardenDefeated),
      currentStreak: clampNonNegative(player.streakDays),
      longestStreak: clampNonNegative(player.longestStreak),
      totalReflections: clampNonNegative(player.totalReflections),
    );
  }

  /// SNS共有用の日本語テキスト。値が 0 の項目は行に出さない。
  static String shareText(AdventureShareCard card) {
    final lines = <String>[
      '⚔️ 冒険の戦績 ⚔️',
      '${card.rankLabel} ${card.levelLabel}',
    ];
    if (card.totalTasksCompleted > 0) {
      lines.add('総クエスト完了: ${card.totalTasksCompleted}件');
    }
    if (card.totalSRankCompleted > 0) {
      lines.add('Sランク: ${card.totalSRankCompleted}件');
    }
    if (card.wardenDefeated > 0) {
      lines.add('刻の番人討伐: ${card.wardenDefeated}回');
    }
    if (card.longestStreak > 0) {
      lines.add('最長ストリーク: ${card.longestStreak}日');
    }
    if (card.currentStreak > 0) {
      lines.add('現在のストリーク: ${card.currentStreak}日');
    }
    if (card.totalReflections > 0) {
      lines.add('振り返り: ${card.totalReflections}回');
    }
    lines.add('#RPGタスク');
    return lines.join('\n');
  }
}
