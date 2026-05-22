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
}
