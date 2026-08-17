import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/battle/domain/defeat_summary.dart';

void main() {
  Task buildTask({required List<SubTask> subtasks}) => Task(
        id: 'task-1',
        title: '討伐試験',
        subTasks: subtasks,
      );

  group('DefeatSummary', () {
    group('isVictory', () {
      test('サブタスクが全て完了なら true', () {
        final task = buildTask(subtasks: [
          SubTask(title: 'a', isCompleted: true),
          SubTask(title: 'b', isCompleted: true),
        ]);
        expect(DefeatSummary.isVictory(task), isTrue);
      });

      test('未完了サブタスクが1つでもあれば false', () {
        final task = buildTask(subtasks: [
          SubTask(title: 'a', isCompleted: true),
          SubTask(title: 'b', isCompleted: false),
        ]);
        expect(DefeatSummary.isVictory(task), isFalse);
      });

      test('サブタスクなしは true（勝利扱い）', () {
        final task = buildTask(subtasks: const []);
        expect(DefeatSummary.isVictory(task), isTrue);
      });
    });

    group('remainingCount', () {
      test('未完了サブタスクの数を返す', () {
        final task = buildTask(subtasks: [
          SubTask(title: 'a', isCompleted: true),
          SubTask(title: 'b', isCompleted: false),
          SubTask(title: 'c', isCompleted: false),
        ]);
        expect(DefeatSummary.remainingCount(task), 2);
      });

      test('全て完了なら 0', () {
        final task = buildTask(subtasks: [
          SubTask(title: 'a', isCompleted: true),
        ]);
        expect(DefeatSummary.remainingCount(task), 0);
      });

      test('サブタスクなしは 0', () {
        final task = buildTask(subtasks: const []);
        expect(DefeatSummary.remainingCount(task), 0);
      });
    });

    group('incompleteSubTasks', () {
      test('未完了サブタスクのみを元の順序で返す', () {
        final task = buildTask(subtasks: [
          SubTask(title: '完了1', isCompleted: true),
          SubTask(title: '残り1', isCompleted: false),
          SubTask(title: '完了2', isCompleted: true),
          SubTask(title: '残り2', isCompleted: false),
        ]);
        final result = DefeatSummary.incompleteSubTasks(task);
        expect(result.length, 2);
        expect(result[0].title, '残り1');
        expect(result[1].title, '残り2');
      });

      test('サブタスクなしは空リスト', () {
        final task = buildTask(subtasks: const []);
        expect(DefeatSummary.incompleteSubTasks(task), isEmpty);
      });
    });
  });
}
