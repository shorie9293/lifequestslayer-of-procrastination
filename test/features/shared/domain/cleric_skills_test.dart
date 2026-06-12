import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/features/battle/data/quiz_data.dart';

void main() {
  group('Cleric Lv1: 後追いの祈り (repeatAfterDays)', () {
    late TaskCompletionService service;

    setUp(() {
      service = TaskCompletionService();
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'q1',
          question: '問題',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          expBonusPercent: 10,
        ),
      ]);
      QuizService.probability = 0.0;
    });

    tearDown(() {
      QuizService.probability = 0.30;
    });

    Task makeTask({
      required String id,
      int? repeatAfterDays,
      RepeatInterval repeatInterval = RepeatInterval.none,
    }) {
      return Task(
        id: id,
        title: 'テストクエスト',
        status: TaskStatus.active,
        rank: QuestRank.B,
        repeatInterval: repeatInterval,
        repeatAfterDays: repeatAfterDays,
      );
    }

    test('repeatAfterDays設定クエスト完了時はisCompleted=false、lastCompletedAtが設定される', () {
      final task = makeTask(id: 'r1', repeatAfterDays: 3);
      final player = Player();
      player.jobLevels[Job.cleric] = 1;
      player.currentJob = Job.cleric;

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(task.isCompleted, isFalse,
          reason: 'repeatAfterDaysクエストは完了してもisCompleted=falseのまま再活性化待ち');
      expect(task.lastCompletedAt, isNotNull,
          reason: 'repeatAfterDaysクエストはlastCompletedAtが記録される');
      expect(task.status, equals(TaskStatus.active),
          reason: 'repeatAfterDaysクエストはactive状態を維持');
    });

    test('repeatAfterDays=nullの通常クエストは完了時にisCompleted=trueになる', () {
      final task = makeTask(id: 'r2');
      final player = Player();
      player.jobLevels[Job.cleric] = 1;
      player.currentJob = Job.cleric;

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(task.isCompleted, isTrue,
          reason: 'repeatAfterDaysなしのクエストは通常通り完了');
      expect(task.status, equals(TaskStatus.inGuild));
    });

    test('repeatAfterDays設定でもClericスキル未使用時は通常完了', () {
      final task = makeTask(id: 'r3', repeatAfterDays: 3);
      final player = Player(); // adventurer (初期職) — clericスキル不使用

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(task.isCompleted, isTrue,
          reason: 'Clericスキルがない場合はrepeatAfterDaysは無視され通常完了');
    });

    test('repeatAfterDays経過判定: N日経過していれば再活性化すべき', () {
      final task = makeTask(id: 'r4', repeatAfterDays: 3);

      // 3日前に完了
      task.lastCompletedAt = DateTime.now().subtract(const Duration(days: 3));
      task.isCompleted = false;
      task.status = TaskStatus.active;

      // repeatAfter: 3日 → 3日経過 → 再活性化
      final shouldReactivate = task.shouldReactivate();
      expect(shouldReactivate, isTrue,
          reason: 'repeatAfterDays=3で3日経過していれば再活性化可能');
    });

    test('repeatAfterDays経過判定: 未経過なら再活性化しない', () {
      final task = makeTask(id: 'r5', repeatAfterDays: 7);

      // 3日前に完了
      task.lastCompletedAt = DateTime.now().subtract(const Duration(days: 3));
      task.isCompleted = false;
      task.status = TaskStatus.active;

      // repeatAfter: 7日 → 3日しか経過していない → 再活性化しない
      final shouldReactivate = task.shouldReactivate();
      expect(shouldReactivate, isFalse,
          reason: 'repeatAfterDays=7で3日しか経過していなければ再活性化不可');
    });

    test('repeatAfterDaysがnullの時はshouldReactivateはfalse', () {
      final task = makeTask(id: 'r6');
      task.lastCompletedAt = DateTime.now().subtract(const Duration(days: 10));

      final shouldReactivate = task.shouldReactivate();
      expect(shouldReactivate, isFalse,
          reason: 'repeatAfterDays未設定なら再活性化しない');
    });

    test('lastCompletedAtがnullの時はshouldReactivateはfalse', () {
      final task = makeTask(id: 'r7', repeatAfterDays: 3);
      // lastCompletedAt 未設定

      final shouldReactivate = task.shouldReactivate();
      expect(shouldReactivate, isFalse,
          reason: 'lastCompletedAtがなければ再活性化判定不可');
    });
  });

  group('Cleric Lv5: 微睡みの加護 (snooze)', () {
    test('snoozeTask: クエストのdeadlineが翌日に延期される', () {
      final player = Player();
      player.jobLevels[Job.cleric] = 5;
      player.currentJob = Job.cleric;

      final now = DateTime(2026, 5, 28, 15, 0);
      final task = Task(
        id: 's1',
        title: '締切クエスト',
        status: TaskStatus.active,
        deadline: DateTime(2026, 5, 28, 23, 59),
      );

      player.snoozeTask(task.id, task, now);

      // deadline が翌日へ
      expect(task.deadline, isNotNull);
      expect(task.deadline!.day, equals(29),
          reason: 'snoozeするとdeadlineが翌日に延期される');
      expect(task.deadline!.hour, equals(23));
      expect(task.deadline!.minute, equals(59));
    });

    test('snoozeTask: snoozedTasksに記録される', () {
      final player = Player();
      player.jobLevels[Job.cleric] = 5;
      player.currentJob = Job.cleric;

      final now = DateTime(2026, 5, 28, 10, 0);
      final task = Task(
        id: 's2',
        title: 'テスト',
        status: TaskStatus.active,
        deadline: DateTime(2026, 5, 28, 18, 0),
      );

      player.snoozeTask(task.id, task, now);

      expect(player.snoozedTasks, contains(task.id),
          reason: 'snoozeしたクエストIDがsnoozedTasksに記録される');
    });

    test('snoozeTask: deadlineがnullのクエストはsnoozeされない', () {
      final player = Player();
      player.jobLevels[Job.cleric] = 5;
      player.currentJob = Job.cleric;

      final now = DateTime(2026, 5, 28, 10, 0);
      final task = Task(
        id: 's3',
        title: 'deadlineなし',
        status: TaskStatus.active,
        deadline: null,
      );

      player.snoozeTask(task.id, task, now);

      expect(task.deadline, isNull,
          reason: 'deadlineなしクエストはsnoozeされない');
      expect(player.snoozedTasks, isNot(contains(task.id)),
          reason: 'deadlineなしクエストはsnoozedTasksに記録されない');
    });

    test('snoozeTask: 同一クエストを2回snoozeすると2日延期', () {
      final player = Player();
      player.jobLevels[Job.cleric] = 5;
      player.currentJob = Job.cleric;

      final now = DateTime(2026, 5, 28, 10, 0);
      final task = Task(
        id: 's4',
        title: '2回snooze',
        status: TaskStatus.active,
        deadline: DateTime(2026, 5, 28, 18, 0),
      );

      player.snoozeTask(task.id, task, now);
      player.snoozeTask(task.id, task, now);

      expect(task.deadline!.day, equals(30),
          reason: '2回snoozeで2日後になる');
    });

    test('snooze: deadlineがすでに過ぎている場合でも翌日へ延期', () {
      final player = Player();
      player.jobLevels[Job.cleric] = 5;
      player.currentJob = Job.cleric;

      final now = DateTime(2026, 5, 30, 10, 0);
      final task = Task(
        id: 's5',
        title: '期限切れ',
        status: TaskStatus.active,
        deadline: DateTime(2026, 5, 28, 18, 0),
      );

      player.snoozeTask(task.id, task, now);

      // snoozeは既存deadlineから +1日、期限切れdeadlineなら1日進む
      expect(task.deadline!.day, equals(29),
          reason: '期限切れクエストでもsnoozeでdeadlineが1日延期');
    });
  });

  group('Cleric Lv10: 連続の誓い (streak)', () {
    test('recordTaskCompletion: 初回完了でstreak=1が記録される', () {
      final player = Player();
      final now = DateTime(2026, 5, 28);

      player.recordTaskCompletion('st1', now);

      expect(player.taskStreaks, contains('st1'));
      expect(player.taskStreaks['st1']!.currentStreak, equals(1));
      expect(player.taskStreaks['st1']!.lastCompletedDate, equals(now));
    });

    test('recordTaskCompletion: 連続日完了でstreakが増加', () {
      final player = Player();
      final day1 = DateTime(2026, 5, 26);
      final day2 = DateTime(2026, 5, 27);
      final day3 = DateTime(2026, 5, 28);

      player.recordTaskCompletion('st2', day1);
      expect(player.taskStreaks['st2']!.currentStreak, equals(1));

      player.recordTaskCompletion('st2', day2);
      expect(player.taskStreaks['st2']!.currentStreak, equals(2));

      player.recordTaskCompletion('st2', day3);
      expect(player.taskStreaks['st2']!.currentStreak, equals(3));
    });

    test('recordTaskCompletion: 同日2回完了でもstreakは増えない', () {
      final player = Player();
      final now = DateTime(2026, 5, 28);

      player.recordTaskCompletion('st3', now);
      expect(player.taskStreaks['st3']!.currentStreak, equals(1));

      player.recordTaskCompletion('st3', now);
      expect(player.taskStreaks['st3']!.currentStreak, equals(1),
          reason: '同日の複数完了はstreakにカウントされない');
    });

    test('recordTaskCompletion: 1日空くとstreakがリセット', () {
      final player = Player();
      final day1 = DateTime(2026, 5, 26);
      final day3 = DateTime(2026, 5, 28); // 1日空き

      player.recordTaskCompletion('st4', day1);
      expect(player.taskStreaks['st4']!.currentStreak, equals(1));

      player.recordTaskCompletion('st4', day3);
      expect(player.taskStreaks['st4']!.currentStreak, equals(1),
          reason: '1日空くとstreakは1にリセットされる');
    });

    test('getTaskStreakBonus: 7日未満はボーナスなし', () {
      final player = Player();
      final now = DateTime(2026, 5, 28);

      // 1日目
      player.recordTaskCompletion('st5', now.subtract(const Duration(days: 0)));

      final bonus = player.getTaskStreakBonus('st5');
      expect(bonus, equals(1.0),
          reason: '7日未満のstreakではボーナスなし（倍率1.0）');
    });

    test('getTaskStreakBonus: 7日以上のstreakで+20%', () {
      final player = Player();

      // 7日連続完了をシミュレート
      final baseDate = DateTime(2026, 5, 22);
      for (int i = 0; i < 7; i++) {
        player.recordTaskCompletion(
          'st6',
          baseDate.add(Duration(days: i)),
        );
      }

      expect(player.taskStreaks['st6']!.currentStreak, equals(7));

      final bonus = player.getTaskStreakBonus('st6');
      expect(bonus, equals(1.2),
          reason: '7日以上のstreakでEXP+20%ボーナス');
    });

    test('getTaskStreakBonus: streakなしのクエストは倍率1.0', () {
      final player = Player();

      final bonus = player.getTaskStreakBonus('unknown-task');
      expect(bonus, equals(1.0),
          reason: 'streak未記録のクエストは通常倍率');
    });

    test('TaskCompletionService: streak7日でEXP+20%ボーナス', () {
      final service = TaskCompletionService();
      QuizService.setQuestions([
        const QuizQuestion(
          id: 'q1',
          question: '問題',
          choices: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
          expBonusPercent: 10,
        ),
      ]);
      QuizService.probability = 0.0;

      final player = Player();
      player.jobLevels[Job.cleric] = 10;
      player.currentJob = Job.cleric;

      final task = Task(
        id: 'st7',
        title: 'streakクエスト',
        status: TaskStatus.active,
        rank: QuestRank.B,
      );

      // 7日連続完了をシミュレート（DateTime.now()基準で過去7日間）
      final baseDate = DateTime.now().subtract(const Duration(days: 7));
      for (int i = 0; i < 7; i++) {
        player.recordTaskCompletion(
          'st7',
          baseDate.add(Duration(days: i)),
        );
      }

      // 8日目の完了
      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      // Bランク基本100 * 1.2(streak) = 120
      expect(result!.expGain, equals(120),
          reason: '7日streakでEXP+20% → Bランク100×1.2=120');
    });

    tearDown(() {
      QuizService.probability = 0.30;
    });
  });
}
