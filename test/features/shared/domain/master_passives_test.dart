import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';

void main() {
  group('Bushido (Warrior Lv15) — 武士道の極意', () {
    group('Player - warriorDailyBuff tracking', () {
      test('warriorDailyBuff starts at 0', () {
        final player = Player();
        expect(player.warriorDailyBuff, 0);
        expect(player.lastDailyComplete, isNull);
      });

      test('lastDailyComplete and warriorDailyBuff update on first daily completion',
          () {
        final player = Player();
        player.jobLevels[Job.samurai] = 15;
        player.currentJob = Job.samurai;
        final task = Task(
          id: 'bushido-1',
          title: 'test',
          status: TaskStatus.active,
          rank: QuestRank.B,
        );

        final result = TaskCompletionService().complete(
          task: task,
          player: player,
          hasShownFatiguePopupToday: false,
          knowledgeQuestEnabled: false,
        );

        expect(result, isNotNull);
        expect(player.lastDailyComplete, isNotNull);
        final today = DateTime.now();
        expect(player.lastDailyComplete!.year, today.year);
        expect(player.lastDailyComplete!.month, today.month);
        expect(player.lastDailyComplete!.day, today.day);
        expect(player.warriorDailyBuff, 1); // +0.1% stored as *1000
      });

      test('warriorDailyBuff does NOT increment on same day', () {
        final player = Player();
        player.jobLevels[Job.samurai] = 15;
        player.currentJob = Job.samurai;
        player.lastDailyComplete = DateTime.now();
        player.warriorDailyBuff = 5; // Pre-set

        final task = Task(
          id: 'bushido-2',
          title: 'test',
          status: TaskStatus.active,
          rank: QuestRank.B,
        );

        TaskCompletionService().complete(
          task: task,
          player: player,
          hasShownFatiguePopupToday: false,
          knowledgeQuestEnabled: false,
        );

        // Still 5, not 6
        expect(player.warriorDailyBuff, 5);
      });
    });

    group('TaskCompletionService - Bushido EXP bonus', () {
      test('Bushido buff applies EXP multiplier when buff > 0', () {
        final player = Player();
        player.jobLevels[Job.samurai] = 15;
        player.currentJob = Job.samurai;
        player.warriorDailyBuff = 10; // 1.0% multiplier
        final task = Task(
          id: 'bushido-exp-1',
          title: 'test',
          status: TaskStatus.active,
          rank: QuestRank.B,
        );

        final result = TaskCompletionService().complete(
          task: task,
          player: player,
          hasShownFatiguePopupToday: false,
          knowledgeQuestEnabled: false,
        );

        expect(result, isNotNull);
        // B-rank base: 100, combo: comboCount=1, +10 => 110
        // fatigueMultiplier: 1.0 (fresh player)
        // Bushido: 110 * (1 + 10/1000) = 110 * 1.01 = 111.1 => 111
        expect(result!.expGain, 111);
        expect(result.bonusMessages, anyElement(contains('武士道の極意')));
      });

      test('Bushido buff is 0 when warriorDailyBuff is 0', () {
        final player = Player();
        player.jobLevels[Job.samurai] = 15;
        player.currentJob = Job.samurai;
        player.warriorDailyBuff = 0;
        final task = Task(
          id: 'bushido-exp-2',
          title: 'test',
          status: TaskStatus.active,
          rank: QuestRank.B,
        );

        final result = TaskCompletionService().complete(
          task: task,
          player: player,
          hasShownFatiguePopupToday: false,
          knowledgeQuestEnabled: false,
        );

        expect(result, isNotNull);
        // B-rank base: 100, combo: +10 => 110. No bushido bonus.
        expect(result!.expGain, 110);
        expect(result.bonusMessages,
            isNot(anyElement(contains('武士道の極意'))));
      });
    });
  });

  group('Enlightenment (Cleric Lv15) — 悟りの境地', () {
    group('Player - streakGrace', () {
      test('streakGraceRemaining starts at 1', () {
        final player = Player();
        expect(player.streakGraceRemaining, 1);
      });

      test('consumeStreakGrace decrements from 1 to 0', () {
        final player = Player();
        player.consumeStreakGrace();
        expect(player.streakGraceRemaining, 0);
      });

      test('consumeStreakGrace does not go below 0', () {
        final player = Player();
        player.consumeStreakGrace();
        player.consumeStreakGrace(); // second call does nothing
        expect(player.streakGraceRemaining, 0);
      });
    });
  });
}
