import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';

void main() {
  group('Player - Pomodoro session', () {
    test('startPomodoro sets pomodoroStartTime', () {
      final player = Player();
      expect(player.pomodoroStartTime, isNull);
      player.startPomodoro();
      expect(player.pomodoroStartTime, isNotNull);
    });

    test('isPomodoroActive returns true when session just started', () {
      final player = Player();
      player.pomodoroStartTime = DateTime.now();
      expect(player.isPomodoroActive, isTrue);
    });

    test('isPomodoroActive returns false when no session', () {
      final player = Player();
      expect(player.isPomodoroActive, isFalse);
    });

    test('isPomodoroActive returns false after duration expires', () {
      final player = Player();
      player.pomodoroMinutes = 25;
      // Simulate starting 26 minutes ago
      player.pomodoroStartTime =
          DateTime.now().subtract(const Duration(minutes: 26));
      expect(player.isPomodoroActive, isFalse);
    });

    test('isPomodoroActive returns true within duration', () {
      final player = Player();
      player.pomodoroMinutes = 25;
      // Simulate starting 5 minutes ago
      player.pomodoroStartTime =
          DateTime.now().subtract(const Duration(minutes: 5));
      expect(player.isPomodoroActive, isTrue);
    });

    test('endPomodoro clears pomodoroStartTime', () {
      final player = Player();
      player.startPomodoro();
      expect(player.pomodoroStartTime, isNotNull);
      player.endPomodoro();
      expect(player.pomodoroStartTime, isNull);
    });
  });

  group('TaskCompletionService - Pomodoro bonus', () {
    late TaskCompletionService service;

    setUp(() {
      service = TaskCompletionService();
    });

    Task makeTask({
      required String id,
      QuestRank rank = QuestRank.B,
    }) {
      return Task(
        id: id,
        title: 'テストクエスト',
        status: TaskStatus.active,
        rank: rank,
      );
    }

    test('+50% EXP bonus when pomodoro active and warriorPomodoro equipped',
        () {
      final task = makeTask(id: 'pomo-1');
      final player = Player();
      // Give player Warrior Lv10 to have warriorPomodoro
      player.jobLevels[Job.samurai] = 10;
      player.currentJob = Job.samurai;
      // Start pomodoro session
      player.startPomodoro();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      final expGain = result!.expGain;
      // B-rank base is 100, no combo (warrior current job but 0 combo).
      // Samurai combo: comboCount starts at 0, is incremented inside complete().
      // Actually warrior combo: comboCount++ before the check, so comboCount becomes 1
      // 1*10 = 10 bonus => base 100 + 10 = 110
      // Then pomodoro bonus: 110 * 1.5 = 165
      expect(expGain, 165);
      expect(result.bonusMessages,
          anyElement(contains('集中の型')));
    });

    test('no pomodoro bonus when active pomodoro but warriorPomodoro not available',
        () {
      final task = makeTask(id: 'pomo-2');
      final player = Player();
      // No warrior job, no warriorPomodoro skill
      player.currentJob = Job.adventurer;
      player.startPomodoro();

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // B-rank base 100, no combo (adventurer - no warrior combo)
      // No pomodoro bonus
      expect(result!.expGain, 100);
      expect(result.bonusMessages,
          isNot(anyElement(contains('集中の型'))));
    });

    test('no pomodoro bonus when warriorPomodoro but pomodoro inactive',
        () {
      final task = makeTask(id: 'pomo-3');
      final player = Player();
      player.jobLevels[Job.samurai] = 10;
      player.currentJob = Job.samurai;
      // Do NOT start pomodoro

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // Samurai combo: comboCount becomes 1, bonus 10 => 110
      // No pomodoro bonus
      expect(result!.expGain, 110);
      expect(result.bonusMessages,
          isNot(anyElement(contains('集中の型'))));
    });
  });
}
