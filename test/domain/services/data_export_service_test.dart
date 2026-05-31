import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/services/data_export_service.dart';

void main() {
  late DataExportService service;

  setUp(() {
    service = DataExportService();
  });

  group('DataExportService - exportToJson / importFromJson', () {
    test('export creates valid JSON with correct structure', () {
      final player = Player();
      final tasks = <Task>[];
      final jsonStr = service.exportToJson(player, tasks);

      expect(jsonStr, isA<String>());
      expect(jsonStr, startsWith('{'));

      // Parse and verify structure
      final parsed = service.importFromJson(jsonStr);
      expect(parsed, isNotNull);
    });

    test('exported JSON contains version, exportedAt, player, tasks keys', () {
      final player = Player();
      final tasks = <Task>[];
      final jsonStr = service.exportToJson(player, tasks);

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(data, containsPair('version', 1));
      expect(data, contains('exportedAt'));
      expect(data, contains('player'));
      expect(data, contains('tasks'));
      expect(data['tasks'], isA<List>());
    });

    test('round-trip: default Player survives', () {
      final originalPlayer = Player();
      final originalTasks = <Task>[];
      final jsonStr = service.exportToJson(originalPlayer, originalTasks);
      final result = service.importFromJson(jsonStr);

      expect(result, isNotNull);
      expect(result!.player.level, originalPlayer.level);
      expect(result.player.coins, originalPlayer.coins);
      expect(result.player.gems, originalPlayer.gems);
      expect(result.player.currentJob, originalPlayer.currentJob);
      expect(result.player.jobLevels, originalPlayer.jobLevels);
      expect(result.tasks, isEmpty);
    });

    test('round-trip: Player fields like jobLevels, coins, gems, currentJob survive', () {
      final originalPlayer = Player(
        jobLevels: {Job.adventurer: 15, Job.warrior: 8, Job.cleric: 3},
        jobExps: {Job.adventurer: 500, Job.warrior: 200},
        activeSkills: {Job.warrior},
        currentJob: Job.warrior,
        comboCount: 5,
        coins: 9999,
        gems: 50,
        streakDays: 10,
        longestStreak: 30,
        totalTasksCompleted: 100,
        titles: ['見習い冒険者', '英雄'],
        equippedTitle: '英雄',
        equippedSkin: 'skin_warrior_01',
      );
      originalPlayer.nextDayTaskLimitOffset = 2;
      originalPlayer.todayTaskLimitOffset = 1;

      final jsonStr = service.exportToJson(originalPlayer, []);
      final result = service.importFromJson(jsonStr);

      expect(result, isNotNull);
      expect(result!.player.jobLevels, originalPlayer.jobLevels);
      expect(result.player.jobExps, originalPlayer.jobExps);
      expect(result.player.activeSkills, originalPlayer.activeSkills);
      expect(result.player.currentJob, originalPlayer.currentJob);
      expect(result.player.comboCount, originalPlayer.comboCount);
      expect(result.player.coins, originalPlayer.coins);
      expect(result.player.gems, originalPlayer.gems);
      expect(result.player.streakDays, originalPlayer.streakDays);
      expect(result.player.longestStreak, originalPlayer.longestStreak);
      expect(result.player.totalTasksCompleted, originalPlayer.totalTasksCompleted);
      expect(result.player.titles, originalPlayer.titles);
      expect(result.player.equippedTitle, originalPlayer.equippedTitle);
      expect(result.player.equippedSkin, originalPlayer.equippedSkin);
      expect(result.player.nextDayTaskLimitOffset, originalPlayer.nextDayTaskLimitOffset);
      expect(result.player.todayTaskLimitOffset, originalPlayer.todayTaskLimitOffset);
    });

    test('round-trip: Task fields like title, status, rank, repeatInterval survive', () {
      final player = Player(coins: 100);
      final tasks = [
        Task(
          id: 'task-1',
          title: '魔物討伐',
          status: TaskStatus.active,
          rank: QuestRank.S,
          repeatInterval: RepeatInterval.weekly,
          repeatWeekdays: [1, 3, 5],
          targetTimeMinutes: 30,
          repeatAfterDays: 3,
          tags: ['緊急', '戦闘'],
        ),
        Task(
          id: 'task-2',
          title: '薬草収集',
          status: TaskStatus.inGuild,
          rank: QuestRank.B,
          repeatInterval: RepeatInterval.daily,
        ),
      ];

      final jsonStr = service.exportToJson(player, tasks);
      final result = service.importFromJson(jsonStr);

      expect(result, isNotNull);
      expect(result!.tasks.length, 2);

      final t1 = result.tasks[0];
      expect(t1.id, 'task-1');
      expect(t1.title, '魔物討伐');
      expect(t1.status, TaskStatus.active);
      expect(t1.rank, QuestRank.S);
      expect(t1.repeatInterval, RepeatInterval.weekly);
      expect(t1.repeatWeekdays, [1, 3, 5]);
      expect(t1.targetTimeMinutes, 30);
      expect(t1.repeatAfterDays, 3);
      expect(t1.tags, ['緊急', '戦闘']);

      final t2 = result.tasks[1];
      expect(t2.id, 'task-2');
      expect(t2.title, '薬草収集');
      expect(t2.status, TaskStatus.inGuild);
      expect(t2.rank, QuestRank.B);
      expect(t2.repeatInterval, RepeatInterval.daily);
    });

    test('round-trip: SubTask data survives', () {
      final player = Player();
      final subTasks = [
        SubTask(title: 'サブ1'),
        SubTask(title: 'サブ2', isCompleted: true),
        SubTask(title: 'サブ3'),
      ];
      final tasks = [
        Task(
          id: 'sub-task-test',
          title: 'プロジェクト',
          subTasks: subTasks,
        ),
      ];

      final jsonStr = service.exportToJson(player, tasks);
      final result = service.importFromJson(jsonStr);

      expect(result, isNotNull);
      expect(result!.tasks.length, 1);
      final restoredSubtasks = result.tasks[0].subTasks;
      expect(restoredSubtasks.length, 3);
      expect(restoredSubtasks[0].title, 'サブ1');
      expect(restoredSubtasks[0].isCompleted, false);
      expect(restoredSubtasks[1].title, 'サブ2');
      expect(restoredSubtasks[1].isCompleted, true);
      expect(restoredSubtasks[2].title, 'サブ3');
      expect(restoredSubtasks[2].isCompleted, false);
    });

    test('round-trip: DateTime fields (null and non-null) survive', () {
      final player = Player()
        ..lastLoginDate = DateTime(2026, 5, 30, 10, 30)
        ..lastRestDate = DateTime(2026, 5, 29)
        ..lastMissionResetDate = DateTime(2026, 5, 28)
        ..lastDailyComplete = DateTime(2026, 5, 30)
        ..lastStreakGraceReset = DateTime(2026, 5, 23)
        ..pomodoroStartTime = DateTime(2026, 5, 30, 9, 0);
      final tasks = [
        Task(
          id: 'dt-test-1',
          title: '期限あり',
          deadline: DateTime(2026, 6, 15),
          activeAt: DateTime(2026, 5, 30, 8, 0),
          lastCompletedAt: DateTime(2026, 5, 29, 18, 0),
        ),
        Task(
          id: 'dt-test-2',
          title: '期限なし',
        ),
      ];

      final jsonStr = service.exportToJson(player, tasks);
      final result = service.importFromJson(jsonStr);

      expect(result, isNotNull);
      // Player DateTime fields
      expect(result!.player.lastLoginDate, player.lastLoginDate);
      expect(result.player.lastRestDate, player.lastRestDate);
      expect(result.player.lastMissionResetDate, player.lastMissionResetDate);
      expect(result.player.lastDailyComplete, player.lastDailyComplete);
      expect(result.player.lastStreakGraceReset, player.lastStreakGraceReset);
      expect(result.player.pomodoroStartTime, player.pomodoroStartTime);

      // Task DateTime fields
      expect(result.tasks[0].deadline, tasks[0].deadline);
      expect(result.tasks[0].activeAt, tasks[0].activeAt);
      expect(result.tasks[0].lastCompletedAt, tasks[0].lastCompletedAt);
      expect(result.tasks[1].deadline, isNull);
      expect(result.tasks[1].activeAt, isNull);
      expect(result.tasks[1].lastCompletedAt, isNull);
    });

    test('import handles malformed JSON gracefully (returns null)', () {
      expect(service.importFromJson('not even json'), isNull);
      expect(service.importFromJson('{"broken": true}'), isNull);
      expect(service.importFromJson('{"version": 1, "player": null}'), isNull);
      expect(service.importFromJson('{}'), isNull);
      expect(service.importFromJson(''), isNull);
    });

    test('round-trip: empty player and empty tasks', () {
      final player = Player();
      final tasks = <Task>[];

      final jsonStr = service.exportToJson(player, tasks);
      final result = service.importFromJson(jsonStr);

      expect(result, isNotNull);
      expect(result!.player.level, 1);
      expect(result.player.coins, 0);
      expect(result.player.gems, 0);
      expect(result.tasks, isEmpty);
    });

    test('round-trip: full player with all fields populated', () {
      final player = Player(
        jobLevels: {
          Job.adventurer: 20,
          Job.warrior: 15,
          Job.cleric: 10,
          Job.wizard: 5,
        },
        jobExps: {
          Job.adventurer: 1000,
          Job.warrior: 800,
          Job.cleric: 500,
          Job.wizard: 200,
        },
        activeSkills: {Job.warrior, Job.cleric},
        currentJob: Job.wizard,
        comboCount: 10,
        coins: 50000,
        gems: 200,
        homeItems: ['tent', 'sword', 'potion'],
        dailyTasksCompleted: 5,
        weeklySRankCompleted: 2,
        totalTasksCompleted: 250,
        totalSRankCompleted: 15,
        totalARankCompleted: 50,
        totalBRankCompleted: 185,
        timesWardenDefeated: 3,
        titles: ['初心者', '中級者', '上級者'],
        equippedTitle: '上級者',
        equippedSkin: 'skin_wizard_01',
        streakDays: 30,
        longestStreak: 60,
        pomodoroMinutes: 30,
        pomodoroShortBreakMinutes: 7,
        pomodoroLongBreakMinutes: 20,
        pomodorosBeforeLongBreak: 3,
      );
      player.warriorDailyBuff = 15;
      player.streakGraceRemaining = 1;
      player.lastMissionResetDate = DateTime(2026, 5, 30);
      player.lastRestDate = DateTime(2026, 5, 29);
      player.lastLoginDate = DateTime(2026, 5, 30, 8, 0);
      player.pomodoroStartTime = DateTime(2026, 5, 30, 9, 0);
      player.lastDailyComplete = DateTime(2026, 5, 30);
      player.lastStreakGraceReset = DateTime(2026, 5, 23);

      final tasks = <Task>[];
      final jsonStr = service.exportToJson(player, tasks);
      final result = service.importFromJson(jsonStr);

      expect(result, isNotNull);
      final restored = result!.player;

      expect(restored.jobLevels, player.jobLevels);
      expect(restored.jobExps, player.jobExps);
      expect(restored.activeSkills, player.activeSkills);
      expect(restored.currentJob, player.currentJob);
      expect(restored.comboCount, player.comboCount);
      expect(restored.coins, player.coins);
      expect(restored.gems, player.gems);
      expect(restored.homeItems, player.homeItems);
      expect(restored.dailyTasksCompleted, player.dailyTasksCompleted);
      expect(restored.weeklySRankCompleted, player.weeklySRankCompleted);
      expect(restored.totalTasksCompleted, player.totalTasksCompleted);
      expect(restored.totalSRankCompleted, player.totalSRankCompleted);
      expect(restored.totalARankCompleted, player.totalARankCompleted);
      expect(restored.totalBRankCompleted, player.totalBRankCompleted);
      expect(restored.timesWardenDefeated, player.timesWardenDefeated);
      expect(restored.titles, player.titles);
      expect(restored.equippedTitle, player.equippedTitle);
      expect(restored.equippedSkin, player.equippedSkin);
      expect(restored.streakDays, player.streakDays);
      expect(restored.longestStreak, player.longestStreak);
      expect(restored.lastLoginDate, player.lastLoginDate);
      expect(restored.warriorDailyBuff, player.warriorDailyBuff);
      expect(restored.streakGraceRemaining, player.streakGraceRemaining);
      expect(restored.pomodoroMinutes, player.pomodoroMinutes);
      expect(restored.pomodoroShortBreakMinutes, player.pomodoroShortBreakMinutes);
      expect(restored.pomodoroLongBreakMinutes, player.pomodoroLongBreakMinutes);
      expect(restored.pomodorosBeforeLongBreak, player.pomodorosBeforeLongBreak);
      expect(restored.pomodoroStartTime, player.pomodoroStartTime);
      expect(restored.lastDailyComplete, player.lastDailyComplete);
      expect(restored.lastStreakGraceReset, player.lastStreakGraceReset);
      expect(restored.lastMissionResetDate, player.lastMissionResetDate);
      expect(restored.lastRestDate, player.lastRestDate);
    });
  });
}
