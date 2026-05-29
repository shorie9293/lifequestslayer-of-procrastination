import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/overview/domain/overview_service.dart';

void main() {
  group('OverviewService - groupTasksByDeadline', () {
    late OverviewService service;

    setUp(() {
      service = OverviewService();
    });

    Task makeTask({
      required String id,
      TaskStatus status = TaskStatus.active,
      QuestRank rank = QuestRank.B,
      DateTime? deadline,
    }) {
      return Task(
        id: id,
        title: 'Task $id',
        status: status,
        rank: rank,
        deadline: deadline,
      );
    }

    test('groups tasks by deadline date', () {
      final today = DateTime(2026, 5, 29);
      final tomorrow = DateTime(2026, 5, 30);
      final tasks = [
        makeTask(id: 't1', deadline: today),
        makeTask(id: 't2', deadline: today),
        makeTask(id: 't3', deadline: tomorrow),
      ];

      final grouped = service.groupTasksByDeadline(tasks);

      expect(grouped.length, 2);
      expect(grouped['2026-05-29'], hasLength(2));
      expect(grouped['2026-05-30'], hasLength(1));
    });

    test('tasks without deadline are grouped under "No deadline"', () {
      final tasks = [
        makeTask(id: 't1', deadline: DateTime(2026, 5, 29)),
        makeTask(id: 't2'), // no deadline
      ];

      final grouped = service.groupTasksByDeadline(tasks);

      expect(grouped.containsKey('No deadline'), isTrue);
      expect(grouped['No deadline'], hasLength(1));
    });

    test('returns empty map for empty task list', () {
      final grouped = service.groupTasksByDeadline([]);
      expect(grouped, isEmpty);
    });
  });

  group('OverviewService - groupTasksByStatus', () {
    late OverviewService service;

    setUp(() {
      service = OverviewService();
    });

    Task makeTask({
      required String id,
      TaskStatus status = TaskStatus.active,
    }) {
      return Task(
        id: id,
        title: 'Task $id',
        status: status,
        rank: QuestRank.B,
      );
    }

    test('groups tasks by TaskStatus', () {
      final tasks = [
        makeTask(id: 't1', status: TaskStatus.active),
        makeTask(id: 't2', status: TaskStatus.active),
        makeTask(id: 't3', status: TaskStatus.inGuild),
      ];

      final grouped = service.groupTasksByStatus(tasks);

      expect(grouped[TaskStatus.active], hasLength(2));
      expect(grouped[TaskStatus.inGuild], hasLength(1));
    });

    test('returns empty map for empty task list', () {
      final grouped = service.groupTasksByStatus([]);
      expect(grouped, isEmpty);
    });

    test('does not include status with zero tasks', () {
      final tasks = [
        makeTask(id: 't1', status: TaskStatus.active),
      ];

      final grouped = service.groupTasksByStatus(tasks);

      expect(grouped.containsKey(TaskStatus.inGuild), isFalse);
    });
  });
}
