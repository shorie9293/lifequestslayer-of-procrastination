import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';

void main() {
  // ═══════════════════════════════════════════
  // wizardSubtask (Lv1): 分割の理 — isSkillEquipped gate
  // ═══════════════════════════════════════════
  group('wizardSubtask - isSkillEquipped gate', () {
    test('isSkillEquipped returns true when skill is equipped and job is active', () {
      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardSubtask)],
      );
      expect(player.isSkillEquipped(JobSkill.wizardSubtask), isTrue);
    });

    test('isSkillEquipped returns false when skill is NOT in equippedSkills', () {
      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardTags)],
      );
      expect(player.isSkillEquipped(JobSkill.wizardSubtask), isFalse);
    });

    test('isSkillEquipped returns true when wizard is mastered and active', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.wizard: 14},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardSubtask)],
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.wizard);
      expect(player.isSkillEquipped(JobSkill.wizardSubtask), isTrue);
    });

    test('isSkillEquipped returns false when wizard is NOT active', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.wizard: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardSubtask)],
      );
      expect(player.isSkillEquipped(JobSkill.wizardSubtask), isFalse);
    });
  });

  group('wizardSubtask - TaskCompletionService gate', () {
    late TaskCompletionService service;

    setUp(() {
      service = TaskCompletionService();
    });

    test('complete returns null when wizardSubtask active and subtasks not all done', () {
      final task = Task(
        id: 'st1',
        title: 'サブクエストあり',
        status: TaskStatus.active,
        subTasks: [
          SubTask(title: 'サブ1', isCompleted: true),
          SubTask(title: 'サブ2', isCompleted: false),
        ],
      );
      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardSubtask)],
      );

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNull,
          reason: 'wizardSubtask装備中に未完了サブクエストがあると完了不可');
    });

    test('complete succeeds when wizardSubtask active and all subtasks done', () {
      final task = Task(
        id: 'st2',
        title: '全サブクエスト完了',
        status: TaskStatus.active,
        subTasks: [
          SubTask(title: 'サブ1', isCompleted: true),
          SubTask(title: 'サブ2', isCompleted: true),
        ],
      );
      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardSubtask)],
      );

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull,
          reason: '全サブクエスト完了ならwizardSubtask装備中でも完了可能');
    });

    test('complete succeeds (no subtask check) when wizardSubtask NOT equipped', () {
      final task = Task(
        id: 'st3',
        title: '未完了サブクエストあり',
        status: TaskStatus.active,
        subTasks: [
          SubTask(title: 'サブ1', isCompleted: false),
        ],
      );
      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 1},
        equippedSkills: [],
      );

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull,
          reason: 'wizardSubtask未装備ならサブクエスト未完了でも完了可能');
    });

    test('complete does not block when subtasks list is empty', () {
      final task = Task(
        id: 'st4',
        title: 'サブクエストなし',
        status: TaskStatus.active,
      );
      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardSubtask)],
      );

      final result = service.complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull,
          reason: 'サブクエストが空ならwizardSubtask装備中でも完了可能');
    });
  });

  // ═══════════════════════════════════════════
  // wizardTags (Lv5): 札の掌握 — taskTags, add tags
  // ═══════════════════════════════════════════
  group('wizardTags - Task tags', () {
    test('Task has tags field, defaults to empty', () {
      final task = Task(id: 't1', title: 'テスト');
      expect(task.tags, isEmpty);
    });

    test('can set tags on Task', () {
      final task = Task(id: 't2', title: '札付きクエスト', tags: ['神事', '緊急']);
      expect(task.tags, ['神事', '緊急']);
    });

    test('addTag adds a tag to task', () {
      final task = Task(id: 't3', title: '追加テスト');
      task.addTag('開発');
      expect(task.tags, contains('開発'));
    });

    test('addTag does not duplicate tags', () {
      final task = Task(id: 't4', title: '重複テスト');
      task.addTag('勉強');
      task.addTag('勉強');
      expect(task.tags.where((t) => t == '勉強').length, 1);
    });

    test('removeTag removes a tag from task', () {
      final task = Task(id: 't5', title: '削除テスト', tags: ['神事', '開発']);
      task.removeTag('神事');
      expect(task.tags, ['開発']);
    });

    test('hasTag returns true when task has the tag', () {
      final task = Task(id: 't6', title: '所持テスト', tags: ['緊急']);
      expect(task.hasTag('緊急'), isTrue);
      expect(task.hasTag('存在しない'), isFalse);
    });
  });

  group('wizardTags - Player taskTags map', () {
    test('Player.taskTags defaults to empty', () {
      final player = Player();
      expect(player.taskTags, isEmpty);
    });

    test('tagTask registers task under a tag', () {
      final player = Player();
      player.tagTask('task-1', '神事');
      expect(player.taskTags['神事'], isNotNull);
      expect(player.taskTags['神事']!, contains('task-1'));
    });

    test('tagTask adds multiple tasks under same tag', () {
      final player = Player();
      player.tagTask('task-1', '開発');
      player.tagTask('task-2', '開発');
      expect(player.taskTags['開発']!.length, 2);
      expect(player.taskTags['開発']!, contains('task-1'));
      expect(player.taskTags['開発']!, contains('task-2'));
    });

    test('untagTask removes task from a tag', () {
      final player = Player();
      player.tagTask('task-1', '神事');
      player.tagTask('task-2', '神事');
      player.untagTask('task-1', '神事');
      expect(player.taskTags['神事']!, isNot(contains('task-1')));
      expect(player.taskTags['神事']!, contains('task-2'));
    });

    test('untagTask removes tag entry when last task is removed', () {
      final player = Player();
      player.tagTask('task-1', '勉強');
      player.untagTask('task-1', '勉強');
      expect(player.taskTags.containsKey('勉強'), isFalse);
    });

    test('getTaskIdsByTag returns task IDs for a given tag', () {
      final player = Player();
      player.tagTask('a', '神事');
      player.tagTask('b', '神事');
      player.tagTask('c', '開発');
      expect(player.getTaskIdsByTag('神事'), ['a', 'b']);
      expect(player.getTaskIdsByTag('開発'), ['c']);
      expect(player.getTaskIdsByTag('不存在'), isEmpty);
    });
  });

  // ═══════════════════════════════════════════
  // wizardProject (Lv10): 計画の陣 — project bonus
  // ═══════════════════════════════════════════
  group('wizardProject - ProjectGroup bonusExp', () {
    test('ProjectGroup has bonusExp field, defaults to 0', () {
      final pg = ProjectGroup(name: 'テストPJ');
      expect(pg.bonusExp, 0);
    });

    test('can set bonusExp on ProjectGroup', () {
      final pg = ProjectGroup(name: '大祓い', bonusExp: 500);
      expect(pg.bonusExp, 500);
    });

    test('fromJson/toJson round trip preserves bonusExp', () {
      final original = ProjectGroup(name: '翻訳', bonusExp: 300, taskIds: ['t1']);
      final json = original.toJson();
      final restored = ProjectGroup.fromJson(json);
      expect(restored.bonusExp, 300);
      expect(restored.name, '翻訳');
    });
  });

  group('wizardProject - Player taskProjects map', () {
    test('Player.taskProjects defaults to empty', () {
      final player = Player();
      expect(player.taskProjects, isEmpty);
    });

    test('addToProject registers task in taskProjects', () {
      final player = Player();
      player.addToProject('task-1', '翻訳PJ');
      expect(player.taskProjects['task-1'], '翻訳PJ');
    });

    test('removeFromProject clears taskProjects entry', () {
      final player = Player();
      player.addToProject('task-1', 'PJ');
      player.removeFromProject('task-1');
      expect(player.taskProjects.containsKey('task-1'), isFalse);
    });
  });

  group('wizardProject - プロジェクト全完了ボーナス', () {
    late TaskCompletionService service;

    setUp(() {
      service = TaskCompletionService();
    });

    test('全クエスト完了でプロジェクトボーナスEXPが付与される', () {
      final project = ProjectGroup(
        name: '試練の陣',
        bonusExp: 300,
        taskIds: ['t1', 't2'],
      );

      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardProject)],
        projects: [project],
      );
      player.taskProjects['t1'] = '試練の陣';
      player.taskProjects['t2'] = '試練の陣';

      // t1: 完了（ボーナスなし）
      final task1 = Task(id: 't1', title: 'T1', status: TaskStatus.active);
      // t2も完了扱いにするため、allTasksに渡す（complete内でisCompletedがtrueになる前）
      final task2 = Task(id: 't2', title: 'T2', status: TaskStatus.active);

      // t1完了
      final result1 = service.complete(
        task: task1,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
        allTasks: [task1, task2],
      );

      expect(result1, isNotNull);
      expect(result1!.bonusMessages,
          isNot(anyElement(contains('計画の陣'))),
          reason: '1件目完了時点ではプロジェクトボーナスは発動しない');

      // t2完了 → プロジェクト全完了 → ボーナス発動
      // t1はisCompleted=trueになっている
      final result2 = service.complete(
        task: task2,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
        allTasks: [task1, task2],
      );

      expect(result2, isNotNull);
      expect(
        result2!.bonusMessages.any((m) => m.contains('計画の陣')),
        isTrue,
        reason: '全クエスト完了でプロジェクトボーナスメッセージが付与される',
      );
      // EXPが通常Bランク100 + ボーナス300 = 400以上
      expect(result2.expGain, greaterThanOrEqualTo(400),
          reason: 'プロジェクトボーナスEXPが加算されている');
    });

    test('プロジェクト全完了ではない場合はボーナスなし', () {
      final project = ProjectGroup(
        name: '未完の陣',
        bonusExp: 500,
        taskIds: ['t1', 't2', 't3'],
      );

      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.wizardProject)],
        projects: [project],
      );
      player.taskProjects['t1'] = '未完の陣';

      final task1 = Task(id: 't1', title: 'T1', status: TaskStatus.active);
      final task2 = Task(id: 't2', title: 'T2(未完了)', status: TaskStatus.active);

      final result = service.complete(
        task: task1,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
        allTasks: [task1, task2],
      );

      expect(result, isNotNull);
      expect(result!.expGain, lessThan(400),
          reason: '全完了ではないのでボーナスEXPは付与されない');
    });

    test('wizardProjectが装備されていないとボーナスは発動しない', () {
      final project = ProjectGroup(
        name: '非発動の陣',
        bonusExp: 999,
        taskIds: ['t1'],
      );

      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 10},
        equippedSkills: [], // wizardProject 未装備
        projects: [project],
      );
      player.taskProjects['t1'] = '非発動の陣';

      final task1 = Task(id: 't1', title: 'T1', status: TaskStatus.active);

      final result = service.complete(
        task: task1,
        player: player,
        hasShownFatiguePopupToday: true,
        knowledgeQuestEnabled: false,
        allTasks: [task1],
      );

      expect(result, isNotNull);
      expect(result!.bonusMessages,
          isNot(anyElement(contains('計画の陣'))),
          reason: 'wizardProject未装備ではボーナスは発動しない');
    });
  });
}
