import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart.dart';
import 'package:rpg_todo/features/adventurer/domain/adventurer_chart_service.dart';

Player _player({
  int totalTasks = 0,
  int s = 0,
  int a = 0,
  int b = 0,
  int warden = 0,
  int streak = 0,
  int longest = 0,
  int reflections = 0,
  int level = 3,
}) {
  return Player(
    jobLevels: {Job.adventurer: level},
    totalTasksCompleted: totalTasks,
    totalSRankCompleted: s,
    totalARankCompleted: a,
    totalBRankCompleted: b,
    timesWardenDefeated: warden,
    streakDays: streak,
    longestStreak: longest,
    totalReflections: reflections,
  );
}

void main() {
  group('AdventurerChartService.build', () {
    test('4グループを固定順で返す', () {
      final chart = AdventurerChartService.build(_player());
      expect(chart.groups.length, 4);
      expect(chart.groups.map((g) => g.id).toList(),
          ['quests', 'battles', 'streaks', 'reflections']);
    });

    test('各entryの値がplayerのフィールドと一致', () {
      final chart = AdventurerChartService.build(_player(
        totalTasks: 42,
        s: 5,
        a: 10,
        b: 15,
        warden: 7,
        streak: 4,
        longest: 12,
        reflections: 20,
      ));
      expect(chart.entryById('total_tasks')!.value, 42);
      expect(chart.entryById('s_rank')!.value, 5);
      expect(chart.entryById('a_rank')!.value, 10);
      expect(chart.entryById('b_rank')!.value, 15);
      expect(chart.entryById('warden')!.value, 7);
      expect(chart.entryById('current_streak')!.value, 4);
      expect(chart.entryById('longest_streak')!.value, 12);
      expect(chart.entryById('reflections')!.value, 20);
      expect(chart.adventurerLevel, 3);
    });

    test('questsグループのラベル・単位', () {
      final chart = AdventurerChartService.build(_player());
      final quests = chart.groupById('quests')!;
      expect(quests.title, 'クエスト完遂');
      expect(quests.emoji, '⚔️');
      expect(quests.entries.map((e) => e.label).toList(),
          ['総クエスト完了', 'Sランク', 'Aランク', 'Bランク']);
      expect(chart.groupById('battles')!.title, '討伐');
      expect(chart.groupById('battles')!.emoji, '🗡️');
      expect(chart.groupById('streaks')!.emoji, '🔥');
      expect(chart.groupById('streaks')!.title, '継続');
      expect(chart.groupById('reflections')!.emoji, '🧘');
      expect(chart.groupById('reflections')!.title, '内省');
      expect(chart.entryById('total_tasks')!.unit, '件');
      expect(chart.entryById('warden')!.unit, '回');
      expect(chart.entryById('current_streak')!.unit, '日');
      expect(chart.entryById('reflections')!.unit, '');
    });
  });

  group('rankLabelFor', () {
    test('境界値', () {
      expect(AdventurerChartService.rankLabelFor(0), '駆け出し');
      expect(AdventurerChartService.rankLabelFor(1), '見習い冒険者');
      expect(AdventurerChartService.rankLabelFor(9), '見習い冒険者');
      expect(AdventurerChartService.rankLabelFor(10), '一人前冒険者');
      expect(AdventurerChartService.rankLabelFor(29), '一人前冒険者');
      expect(AdventurerChartService.rankLabelFor(30), '熟練冒険者');
      expect(AdventurerChartService.rankLabelFor(99), '熟練冒険者');
      expect(AdventurerChartService.rankLabelFor(100), '伝説の冒険者');
    });
  });

  group('nextRankThreshold', () {
    test('閾値とnull', () {
      expect(AdventurerChartService.nextRankThreshold(0), 10);
      expect(AdventurerChartService.nextRankThreshold(29), 30);
      expect(AdventurerChartService.nextRankThreshold(100), isNull);
    });
  });

  group('progressToNextRank', () {
    test('0..1クランプ・最終ランク1.0', () {
      expect(AdventurerChartService.progressToNextRank(0), 0.0);
      final p = AdventurerChartService.progressToNextRank(15);
      expect(p, greaterThan(0.0));
      expect(p, lessThan(1.0));
      expect(AdventurerChartService.progressToNextRank(200), 1.0);
    });
  });

  group('AdventurerChart モデル', () {
    test('entryById・groupById の存在とnull', () {
      final chart = AdventurerChartService.build(_player());
      expect(chart.entryById('no_such'), isNull);
      expect(chart.groupById('no_such'), isNull);
      expect(chart.entryById('total_tasks'), isNotNull);
      expect(chart.groupById('quests'), isNotNull);
    });

    test('displayValue・labelWithValue・totalValue・isEmpty', () {
      final entry = const AdventurerStatEntry(
          id: 'x', label: 'ラベル', value: 5, unit: '件', emoji: '⭐');
      expect(entry.displayValue, '5件');
      expect(entry.labelWithValue, 'ラベル 5件');

      final group = AdventurerStatGroup(
          id: 'g',
          title: '群',
          emoji: '🎯',
          entries: [entry, const AdventurerStatEntry(id: 'y', label: '他', value: 3, unit: '回', emoji: '🌙')]);
      expect(group.totalValue, 8);
      expect(group.isEmpty, isFalse);
      expect(const AdventurerStatGroup(id: 'e', title: '空', emoji: '🌱', entries: []).isEmpty, isTrue);

      final chart = AdventurerChartService.build(_player());
      expect(chart.isEmpty, isFalse);
      expect(chart.allEntries.length, 8);
      final emptyChart = const AdventurerChart(
          groups: [AdventurerStatGroup(id: 'e', title: '空', emoji: '🌱', entries: [])],
          adventurerLevel: 1,
          rankLabel: '駆け出し');
      expect(emptyChart.isEmpty, isTrue);
    });
  });
}
