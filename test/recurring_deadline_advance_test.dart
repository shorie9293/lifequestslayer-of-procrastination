import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';

/// Helper: create a Player that can use recurring task skills.
/// Uses Monk job which grants canUseSkill(Job.monk) -> enters recurring completion path.
Player _recurringCapablePlayer() {
  return Player()
    ..currentJob = Job.monk
    ..jobLevels[Job.monk] = 1;
}

void main() {
  group('Recurring task deadline advance (regression test)', () {
    setUp(() {
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'q1',
          question: 'Q1?',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          expBonusPercent: 30,
        ),
      ]);
      QuizService.probability = 0.0;
    });

    test('GREEN: daily recurring task deadline advances by 1 day after complete', () {
      final now = DateTime.now();
      final originalDeadline = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final task = Task(
        id: 'test-daily-advance',
        title: 'Daily task',
        status: TaskStatus.active,
        repeatInterval: RepeatInterval.daily,
        deadline: originalDeadline,
      );
      final player = _recurringCapablePlayer();

      final service = TaskCompletionService();
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // Deadline should be advanced by 1 day
      final expectedDeadline = originalDeadline.add(const Duration(days: 1));
      expect(task.deadline, equals(expectedDeadline),
          reason: 'Daily recurring task deadline should advance by 1 day after completion');
    });

    test('GREEN: weekly recurring task deadline advances by 7 days after complete', () {
      final now = DateTime.now();
      final originalDeadline = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final task = Task(
        id: 'test-weekly-advance',
        title: 'Weekly task',
        status: TaskStatus.active,
        repeatInterval: RepeatInterval.weekly,
        deadline: originalDeadline,
      );
      final player = _recurringCapablePlayer();

      final service = TaskCompletionService();
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // For weekly without specific weekdays, advance by 7 days
      final expectedDeadline = originalDeadline.add(const Duration(days: 7));
      expect(task.deadline, equals(expectedDeadline),
          reason: 'Weekly recurring task deadline should advance by 7 days after completion');
    });

    test('GREEN: recurring task WITHOUT deadline stays null after complete', () {
      final task = Task(
        id: 'test-no-deadline',
        title: 'No deadline task',
        status: TaskStatus.active,
        repeatInterval: RepeatInterval.daily,
        deadline: null,
      );
      final player = _recurringCapablePlayer();

      final service = TaskCompletionService();
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(task.deadline, isNull,
          reason: 'Recurring task without deadline should stay null after complete');
    });

    test('GREEN: non-recurring task deadline is NOT advanced after complete', () {
      final now = DateTime.now();
      final originalDeadline = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final task = Task(
        id: 'test-non-recurring',
        title: 'Non-recurring task',
        status: TaskStatus.active,
        repeatInterval: RepeatInterval.none,
        deadline: originalDeadline,
      );
      final player = Player();

      final service = TaskCompletionService();
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(task.isCompleted, isTrue,
          reason: 'Non-recurring task should be marked completed');
      expect(task.deadline, equals(originalDeadline),
          reason: 'Non-recurring task deadline should NOT be advanced');
    });

    test('GREEN: weekly with weekdays advances to next selected weekday', () {
      final now = DateTime.now();
      final originalDeadline = DateTime(now.year, now.month, now.day, 23, 59, 59);
      final todayWeekday = now.weekday;

      // Select weekdays for the next 2 days after today
      final nextDay = todayWeekday == 7 ? 1 : todayWeekday + 1;
      final dayAfterNext = nextDay == 7 ? 1 : nextDay + 1;

      final task = Task(
        id: 'test-weekly-weekdays',
        title: 'Weekly with weekdays',
        status: TaskStatus.active,
        repeatInterval: RepeatInterval.weekly,
        repeatWeekdays: [nextDay, dayAfterNext],
        deadline: originalDeadline,
      );
      final player = _recurringCapablePlayer();

      final service = TaskCompletionService();
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);

      // Deadline should advance to the next selected weekday (nextDay)
      expect(task.deadline!.isAfter(originalDeadline), isTrue,
          reason: 'Deadline should advance to next weekday');
      expect(task.repeatWeekdays.contains(task.deadline!.weekday), isTrue,
          reason: 'Deadline weekday must be one of the selected weekdays');

      // The deadline should be exactly the nextDay (since it's the next day)
      final expectedWeekday = nextDay;
      expect(task.deadline!.weekday, equals(expectedWeekday),
          reason: 'Deadline should advance to the very next selected weekday');
    });

    test('GREEN: weekly with "today" in weekdays advances to next week same day', () {
      final now = DateTime.now();
      final originalDeadline = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Select today's weekday (the deadline is already set for today)
      // Should advance to next week same day (7 days)
      final task = Task(
        id: 'test-weekly-today',
        title: 'Weekly with today in weekdays',
        status: TaskStatus.active,
        repeatInterval: RepeatInterval.weekly,
        repeatWeekdays: [now.weekday],
        deadline: originalDeadline,
      );
      final player = _recurringCapablePlayer();

      final service = TaskCompletionService();
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);

      // If today's weekday is the only selected day, the next occurrence is next week
      final expectedDeadline = originalDeadline.add(const Duration(days: 7));
      expect(task.deadline, equals(expectedDeadline),
          reason: 'When only today is selected as weekday, deadline advances 7 days to next occurrence');
    });

    test('GREEN: daily recurring with repeatAfterDays does NOT advance deadline (separate mechanism)', () {
      final now = DateTime.now();
      final originalDeadline = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final task = Task(
        id: 'test-repeat-after',
        title: 'Daily with repeatAfterDays',
        status: TaskStatus.active,
        repeatInterval: RepeatInterval.daily,
        repeatAfterDays: 3,
        deadline: originalDeadline,
      );
      final player = _recurringCapablePlayer();

      final service = TaskCompletionService();
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      // The repeatAfterDays branch (Monk Lv1) does NOT advance deadline
      // This is a separate mechanism from the recurring task path
      expect(result, isNotNull);
      expect(task.lastCompletedAt, isNotNull);
      // This task enters the repeatAfterDays branch, not the recurring branch
      // Deadline is not advanced in the repeatAfterDays path
      expect(task.deadline, equals(originalDeadline),
          reason: 'repeatAfterDays is a separate mechanism that does not advance deadline');
    });
  });
}
