import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';

void main() {
  group('SubTask', () {
    test('デフォルトで未完了', () {
      final sub = SubTask(title: 'サブタスク');
      expect(sub.title, 'サブタスク');
      expect(sub.isCompleted, false);
    });

    test('完了状態を指定できる', () {
      final sub = SubTask(title: '完了済み', isCompleted: true);
      expect(sub.isCompleted, true);
    });

    test('タイトルを変更できる', () {
      final sub = SubTask(title: '元のタイトル');
      sub.title = '新しいタイトル';
      expect(sub.title, '新しいタイトル');
    });
  });

  group('QuestRank', () {
    test('S > A > B の順に定義されている', () {
      expect(QuestRank.S.index, lessThan(QuestRank.A.index));
      expect(QuestRank.A.index, lessThan(QuestRank.B.index));
    });

    test('QuestRank.values に3つの値が含まれる', () {
      expect(QuestRank.values.length, 3);
      expect(QuestRank.values, containsAll([QuestRank.S, QuestRank.A, QuestRank.B]));
    });
  });

  group('TaskStatus', () {
    test('inGuild と active の2種類', () {
      expect(TaskStatus.values.length, 2);
      expect(TaskStatus.values[0], TaskStatus.inGuild);
      expect(TaskStatus.values[1], TaskStatus.active);
    });
  });

  group('RepeatInterval', () {
    test('none, daily, weekly の3種類', () {
      expect(RepeatInterval.values.length, 3);
      expect(RepeatInterval.values, containsAll([
        RepeatInterval.none,
        RepeatInterval.daily,
        RepeatInterval.weekly,
      ]));
    });
  });

  group('Task', () {
    test('デフォルト値が正しく設定される', () {
      final task = Task(id: 'test1', title: 'テストタスク');
      expect(task.status, TaskStatus.inGuild);
      expect(task.isCompleted, false);
      expect(task.rank, QuestRank.B);
      expect(task.repeatInterval, RepeatInterval.none);
      expect(task.subTasks, isEmpty);
      expect(task.repeatWeekdays, isEmpty);
    });

    test('サブタスク付きでタスクを作成できる', () {
      final subTasks = [
        SubTask(title: 'サブ1'),
        SubTask(title: 'サブ2', isCompleted: true),
      ];
      final task = Task(id: 'test2', title: '親タスク', subTasks: subTasks);
      expect(task.subTasks.length, 2);
      expect(task.subTasks[0].title, 'サブ1');
      expect(task.subTasks[1].isCompleted, true);
    });

    test('ステータスとランクを変更できる', () {
      final task = Task(id: 'test3', title: '変更テスト');
      expect(task.status, TaskStatus.inGuild);
      task.status = TaskStatus.active;
      expect(task.status, TaskStatus.active);
      task.rank = QuestRank.S;
      expect(task.rank, QuestRank.S);
    });
  });

  // ━━━ toJson / fromJson round-trip ━━━
  group('Task.toJson / fromJson', () {
    test('toJson produces all expected fields', () {
      final task = Task(id: 'test1', title: 'テスト');
      final json = task.toJson();
      expect(json, contains('id'));
      expect(json, contains('title'));
      expect(json, contains('status'));
      expect(json, contains('isCompleted'));
      expect(json, contains('rank'));
      expect(json, contains('repeatInterval'));
      expect(json, contains('repeatWeekdays'));
      expect(json, contains('subTasks'));
      expect(json, contains('tags'));
    });

    test('round-trip: default Task matches original', () {
      final original = Task(id: 'test-1', title: 'デフォルトタスク');
      final jsonStr = jsonEncode(original.toJson());
      final restored = Task.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.status, original.status);
      expect(restored.isCompleted, original.isCompleted);
      expect(restored.rank, original.rank);
      expect(restored.repeatInterval, original.repeatInterval);
      expect(restored.repeatWeekdays, original.repeatWeekdays);
      expect(restored.subTasks, original.subTasks);
      expect(restored.tags, original.tags);
      expect(restored.lastCompletedAt, original.lastCompletedAt);
      expect(restored.activeAt, original.activeAt);
      expect(restored.deadline, original.deadline);
    });

    test('round-trip: Task with SubTasks matches original', () {
      final original = Task(
        id: 'sub-task-1',
        title: 'プロジェクトX',
        status: TaskStatus.active,
        rank: QuestRank.S,
        repeatInterval: RepeatInterval.daily,
        repeatWeekdays: [1, 3, 5],
        targetTimeMinutes: 60,
        repeatAfterDays: 7,
        tags: ['重要', '緊急'],
        subTasks: [
          SubTask(title: 'フェーズ1', isCompleted: true),
          SubTask(title: 'フェーズ2'),
          SubTask(title: 'フェーズ3', isCompleted: false),
        ],
      );
      original.lastCompletedAt = DateTime(2026, 5, 30, 18, 30);
      original.activeAt = DateTime(2026, 5, 30, 10, 0);
      original.deadline = DateTime(2026, 6, 15);

      final jsonStr = jsonEncode(original.toJson());
      final restored = Task.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.status, original.status);
      expect(restored.rank, original.rank);
      expect(restored.repeatInterval, original.repeatInterval);
      expect(restored.repeatWeekdays, original.repeatWeekdays);
      expect(restored.targetTimeMinutes, original.targetTimeMinutes);
      expect(restored.repeatAfterDays, original.repeatAfterDays);
      expect(restored.tags, original.tags);
      expect(restored.lastCompletedAt, original.lastCompletedAt);
      expect(restored.activeAt, original.activeAt);
      expect(restored.deadline, original.deadline);

      expect(restored.subTasks.length, original.subTasks.length);
      expect(restored.subTasks[0].title, original.subTasks[0].title);
      expect(restored.subTasks[0].isCompleted, original.subTasks[0].isCompleted);
      expect(restored.subTasks[1].title, original.subTasks[1].title);
      expect(restored.subTasks[1].isCompleted, original.subTasks[1].isCompleted);
      expect(restored.subTasks[2].title, original.subTasks[2].title);
      expect(restored.subTasks[2].isCompleted, original.subTasks[2].isCompleted);
    });

    test('round-trip: Task with DateTime fields (null) matches original', () {
      final original = Task(
        id: 'dt-null-test',
        title: '期限なしタスク',
      );

      final jsonStr = jsonEncode(original.toJson());
      final restored = Task.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.lastCompletedAt, isNull);
      expect(restored.activeAt, isNull);
      expect(restored.deadline, isNull);
      expect(restored.targetTimeMinutes, isNull);
      expect(restored.repeatAfterDays, isNull);
    });
  });
}
