import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart.dart';

class AdventurerChartService {
  const AdventurerChartService._();

  static AdventurerChart build(Player player) {
    return AdventurerChart(
      groups: [
        AdventurerStatGroup(
          id: 'quests',
          title: 'クエスト完遂',
          emoji: '⚔️',
          entries: [
            AdventurerStatEntry(
              id: 'total_tasks',
              label: '総クエスト完了',
              unit: '件',
              emoji: '✅',
              value: player.totalTasksCompleted,
            ),
            AdventurerStatEntry(
              id: 's_rank',
              label: 'Sランク',
              unit: '件',
              emoji: '🏆',
              value: player.totalSRankCompleted,
            ),
            AdventurerStatEntry(
              id: 'a_rank',
              label: 'Aランク',
              unit: '件',
              emoji: '🥈',
              value: player.totalARankCompleted,
            ),
            AdventurerStatEntry(
              id: 'b_rank',
              label: 'Bランク',
              unit: '件',
              emoji: '🥉',
              value: player.totalBRankCompleted,
            ),
          ],
        ),
        AdventurerStatGroup(
          id: 'battles',
          title: '討伐',
          emoji: '🗡️',
          entries: [
            AdventurerStatEntry(
              id: 'warden',
              label: '刻の番人討伐',
              unit: '回',
              emoji: '⏳',
              value: player.timesWardenDefeated,
            ),
          ],
        ),
        AdventurerStatGroup(
          id: 'streaks',
          title: '継続',
          emoji: '🔥',
          entries: [
            AdventurerStatEntry(
              id: 'current_streak',
              label: '現在ストリーク',
              unit: '日',
              emoji: '📈',
              value: player.streakDays,
            ),
            AdventurerStatEntry(
              id: 'longest_streak',
              label: '最長ストリーク',
              unit: '日',
              emoji: '👑',
              value: player.longestStreak,
            ),
          ],
        ),
        AdventurerStatGroup(
          id: 'reflections',
          title: '内省',
          emoji: '🧘',
          entries: [
            AdventurerStatEntry(
              id: 'reflections',
              label: '振り返り',
              unit: '',
              emoji: '📝',
              value: player.totalReflections,
            ),
          ],
        ),
      ],
      adventurerLevel: player.level,
      rankLabel: rankLabelFor(player.totalTasksCompleted),
    );
  }

  static String rankLabelFor(int totalTasksCompleted) {
    if (totalTasksCompleted >= 100) return '伝説の冒険者';
    if (totalTasksCompleted >= 30) return '熟練冒険者';
    if (totalTasksCompleted >= 10) return '一人前冒険者';
    if (totalTasksCompleted >= 1) return '見習い冒険者';
    return '駆け出し';
  }

  static int? nextRankThreshold(int totalTasksCompleted) {
    if (totalTasksCompleted < 10) return 10;
    if (totalTasksCompleted < 30) return 30;
    if (totalTasksCompleted < 100) return 100;
    return null;
  }

  static double progressToNextRank(int totalTasksCompleted) {
    final next = nextRankThreshold(totalTasksCompleted);
    if (next == null) return 1.0;
    final int prev;
    if (next == 10) {
      prev = 0;
    } else if (next == 30) {
      prev = 10;
    } else {
      prev = 30;
    }
    final span = next - prev;
    final p = (totalTasksCompleted - prev) / span;
    return p.clamp(0.0, 1.0).toDouble();
  }
}
