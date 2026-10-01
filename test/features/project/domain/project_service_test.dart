// 計画の陣（プロジェクト機能）純粋ロジックの試練
//
// 対象: lib/features/project/domain/project_service.dart
// TDD RED: 先に試練を書き、失敗を確認してから実装する。

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/project/domain/project_service.dart';

Task _task(String id, {bool isCompleted = false}) {
  return Task(id: id, title: 'クエスト$id', isCompleted: isCompleted);
}

Player _player({
  List<ProjectGroup>? projects,
  Map<String, String>? taskProjects,
}) {
  return Player(
    currentJob: Job.mystic,
    jobLevels: {Job.mystic: 12},
    projects: projects,
    taskProjects: taskProjects,
  );
}

void main() {
  group('normalize', () {
    test('全角スペースを半角に変換する', () {
      expect(ProjectService.normalize('　計画Ａ　'), '計画Ａ');
      expect(ProjectService.normalize('ある　ある'), 'ある ある');
    });

    test('連続空白を圧縮し前後を trim する', () {
      expect(ProjectService.normalize('  a   b  '), 'a b');
      expect(ProjectService.normalize('\ta\tb\t'), 'a b');
    });
  });

  group('maxNameLength', () {
    test('20である', () {
      expect(ProjectService.maxNameLength, 20);
    });
  });

  group('validateNew', () {
    test('空文字は empty', () {
      expect(ProjectService.validateNew([], ''), ProjectValidationError.empty);
      expect(
        ProjectService.validateNew([], '　 '),
        ProjectValidationError.empty,
      );
    });

    test('21文字以上は tooLong', () {
      expect(
        ProjectService.validateNew([], 'a' * 20),
        isNull,
      );
      expect(
        ProjectService.validateNew([], 'a' * 21),
        ProjectValidationError.tooLong,
      );
    });

    test('既存名との重複は duplicate（normalize後比較）', () {
      final existing = [ProjectGroup(name: 'ある ある')];
      expect(
        ProjectService.validateNew(existing, '　ある　ある　'),
        ProjectValidationError.duplicate,
      );
      expect(ProjectService.validateNew(existing, '新しい'), isNull);
    });
  });

  group('listProjects', () {
    test('宣言順に返し非破壊である', () {
      final a = ProjectGroup(name: 'A');
      final b = ProjectGroup(name: 'B');
      final p = _player(projects: [a, b]);

      final result = ProjectService.listProjects(p);

      expect(result.map((g) => g.name).toList(), ['A', 'B']);
      expect(identical(result.first, a), isTrue);
      // 非破壊: 元リストに手を加えても result に影響しない（同一インスタンスでも
      // 返却リスト自体は新規で、並べ替え操作の免疫がある）
      result.add(ProjectGroup(name: 'X'));
      expect(p.projects.length, 2);
    });
  });

  group('tasksOf', () {
    test('taskProjects の逆引きで所属クエストを返す', () {
      final p = _player(taskProjects: {'t1': 'P', 't3': '他'});
      final tasks = [_task('t1'), _task('t2'), _task('t3')];

      final result = ProjectService.tasksOf(p, 'P', tasks);

      expect(result.map((t) => t.id).toList(), ['t1']);
    });
  });

  group('progressFor', () {
    test('完了/未完了を集計する', () {
      final p = _player();
      final g = ProjectGroup(name: 'P', taskIds: ['t1', 't2', 't3']);
      final tasks = [
        _task('t1', isCompleted: true),
        _task('t2'),
      ]; // t3 は存在しない

      final progress = ProjectService.progressFor(p, g, tasks);

      expect(progress.name, 'P');
      expect(progress.bonusExp, 0);
      expect(progress.totalTasks, 2); // 存在しない t3 は分母に入れない
      expect(progress.completedTasks, 1);
      expect(progress.ratio, closeTo(0.5, 0.0001));
      expect(progress.isComplete, isFalse);
      expect(progress.progressLabel, '1 / 2');
    });

    test('0件のとき 0除算せず ratio 0.0', () {
      final p = _player();
      final g = ProjectGroup(name: 'P');

      final progress = ProjectService.progressFor(p, g, []);

      expect(progress.totalTasks, 0);
      expect(progress.ratio, 0.0);
      expect(progress.isComplete, isTrue);
      expect(progress.progressLabel, '0 / 0');
    });

    test('全完了で isComplete true', () {
      final p = _player();
      final g = ProjectGroup(name: 'P', taskIds: ['t1'], bonusExp: 50);
      final tasks = [_task('t1', isCompleted: true)];

      final progress = ProjectService.progressFor(p, g, tasks);

      expect(progress.isComplete, isTrue);
      expect(progress.ratio, 1.0);
      expect(progress.bonusExp, 50);
    });
  });

  group('unassignedTasks', () {
    test('taskProjects に登録がないタスクのみ返す', () {
      final p = _player(taskProjects: {'t1': 'P'});
      final tasks = [_task('t1'), _task('t2'), _task('t3')];

      final result = ProjectService.unassignedTasks(p, tasks);

      expect(result.map((t) => t.id).toSet(), {'t2', 't3'});
    });
  });

  group('sortByProgress', () {
    test('未完了が先（ratio降順）、完了は後ろ、同率は名前昇順、非破壊', () {
      final items = [
        ProjectProgress(
            name: '完A', bonusExp: 0, totalTasks: 1, completedTasks: 1),
        ProjectProgress(
            name: '半B', bonusExp: 0, totalTasks: 2, completedTasks: 1),
        ProjectProgress(
            name: '全C', bonusExp: 0, totalTasks: 3, completedTasks: 3),
        ProjectProgress(
            name: '半A', bonusExp: 0, totalTasks: 2, completedTasks: 1),
        ProjectProgress(
            name: '零D', bonusExp: 0, totalTasks: 1, completedTasks: 0),
      ];
      final copy = List.of(items);

      final sorted = ProjectService.sortByProgress(items);

      expect(sorted.map((p) => p.name).toList(),
          ['半A', '半B', '零D', '全C', '完A']);
      // 非破壊
      expect(items.map((p) => p.name).toList(), copy.map((p) => p.name).toList());
    });
  });

  group('skillsFor', () {
    test('現在職業のスキル一覧を返す', () {
      final p = _player(); // mystic Lv12

      final skills = ProjectService.skillsFor(p);

      expect(skills, hasLength(4));
      expect(skills.map((s) => s.skill), contains(JobSkill.mysticProject));
      // mystic Lv12: Lv1/Lv5/Lv10 のスキルは解放、Lv15 は未解放
      for (final s in skills) {
        if (s.requiredLevel <= 10) {
          expect(s.isUnlocked, isTrue, reason: s.skill.name);
        } else {
          expect(s.isUnlocked, isFalse, reason: s.skill.name);
        }
      }
    });

    test('レベル不足の職業では全スキル未解放', () {
      final p = Player(currentJob: Job.mystic, jobLevels: {Job.mystic: 3});

      final skills = ProjectService.skillsFor(p);

      expect(skills, hasLength(4));
      expect(skills.where((s) => s.isUnlocked), hasLength(1)); // Lv1 のみ
    });
  });
}