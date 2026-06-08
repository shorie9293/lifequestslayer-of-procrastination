import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/guild/data/task_repository.dart';

/// fprint = forced print (always prints even in test)
void fprint(String msg) => print('[TASK_REPO_TEST] $msg');

/// Helper: get typed box reference (already opened by repo)
Box<Task> _getTypedBox() => Hive.box<Task>('tasksBox');

/// Helper: get backup box reference
Box _getBackupBox() => Hive.box('tasksBox_backup');

void main() {
  late TaskRepository repo;

  setUpAll(() async {
    final testDir = Directory(
        '${Directory.systemTemp.path}/task_repo_test_${DateTime.now().millisecondsSinceEpoch}');
    if (!testDir.existsSync()) {
      testDir.createSync(recursive: true);
    }
    Hive.init(testDir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(TaskStatusAdapter());
    Hive.registerAdapter(QuestionRankAdapter());
    Hive.registerAdapter(SubTaskAdapter());
    Hive.registerAdapter(RepeatIntervalAdapter());
  });

  setUp(() async {
    repo = TaskRepository();
    // Pre-open boxes so test helpers work before first loadTasks/saveTasks call
    try {
      await Hive.openBox<Task>('tasksBox');
    } catch (_) {}
    try {
      await Hive.openBox('tasksBox_backup');
    } catch (_) {}
  });

  tearDown(() async {
    try {
      await repo.close();
    } catch (_) {}
    // Clean up boxes (use deleteBoxFromDisk which works even after close)
    try {
      await Hive.deleteBoxFromDisk('tasksBox');
    } catch (_) {}
    try {
      await Hive.deleteBoxFromDisk('tasksBox_backup');
    } catch (_) {}
  });

  group('TaskRepository basic CRUD', () {
    test('loadTasks returns empty list when box is empty', () async {
      final loaded = await repo.loadTasks();
      expect(loaded, isEmpty);
    });

    test('saveTasks then loadTasks returns identical data', () async {
      final task = Task(
        id: 'task-1',
        title: 'Buy groceries',
        status: TaskStatus.active,
        isCompleted: false,
        rank: QuestRank.A,
        repeatInterval: RepeatInterval.daily,
      );
      await repo.saveTasks([task]);
      final loaded = await repo.loadTasks();
      expect(loaded.length, 1);
      expect(loaded[0].id, 'task-1');
      expect(loaded[0].title, 'Buy groceries');
      expect(loaded[0].status, TaskStatus.active);
      expect(loaded[0].rank, QuestRank.A);
    });

    test('multiple tasks save and load correctly', () async {
      final tasks = [
        Task(id: 't1', title: 'Task 1', rank: QuestRank.S),
        Task(id: 't2', title: 'Task 2', rank: QuestRank.A),
        Task(id: 't3', title: 'Task 3', rank: QuestRank.B),
      ];
      await repo.saveTasks(tasks);
      final loaded = await repo.loadTasks();
      expect(loaded.length, 3);
      final ids = loaded.map((t) => t.id).toSet();
      expect(ids, containsAll(['t1', 't2', 't3']));
    });

    test('saveTasks multiple times is idempotent', () async {
      // First save
      await repo.saveTasks([
        Task(id: 'a', title: 'Alpha'),
        Task(id: 'b', title: 'Beta'),
      ]);
      expect((await repo.loadTasks()).length, 2);

      // Second save with same data
      await repo.saveTasks([
        Task(id: 'a', title: 'Alpha'),
        Task(id: 'b', title: 'Beta'),
      ]);
      expect((await repo.loadTasks()).length, 2);

      // Third save with modified data
      await repo.saveTasks([
        Task(id: 'a', title: 'Alpha Modified'),
        Task(id: 'b', title: 'Beta'),
      ]);
      final loaded = await repo.loadTasks();
      expect(loaded.length, 2);
      final alpha = loaded.firstWhere((t) => t.id == 'a');
      expect(alpha.title, 'Alpha Modified');
    });

    test('saveTasks removes deleted tasks (diff delete)', () async {
      // Save 3 tasks
      await repo.saveTasks([
        Task(id: 'x', title: 'X'),
        Task(id: 'y', title: 'Y'),
        Task(id: 'z', title: 'Z'),
      ]);
      expect((await repo.loadTasks()).length, 3);

      // Save only 2 tasks — 'y' should be deleted
      await repo.saveTasks([
        Task(id: 'x', title: 'X'),
        Task(id: 'z', title: 'Z'),
      ]);
      final loaded = await repo.loadTasks();
      expect(loaded.length, 2);
      expect(loaded.any((t) => t.id == 'y'), isFalse);
      expect(loaded.any((t) => t.id == 'x'), isTrue);
      expect(loaded.any((t) => t.id == 'z'), isTrue);
    });

    test('saveTasks with empty list clears all tasks', () async {
      // Save some tasks first
      await repo.saveTasks([
        Task(id: 'e1', title: 'Existing 1'),
        Task(id: 'e2', title: 'Existing 2'),
      ]);
      expect((await repo.loadTasks()).length, 2);

      // Save empty list — should clear everything
      await repo.saveTasks([]);
      final loaded = await repo.loadTasks();
      expect(loaded, isEmpty);
    });
  });

  group('TaskRepository close/reopen', () {
    test('close then reopen works correctly', () async {
      await repo.saveTasks([
        Task(id: 'r1', title: 'Reopen test'),
      ]);
      await repo.close();
      fprint('Repo closed');

      // Create a new repo instance (simulates re-open)
      repo = TaskRepository();
      final loaded = await repo.loadTasks();
      expect(loaded.length, 1);
      expect(loaded[0].id, 'r1');
      expect(loaded[0].title, 'Reopen test');
    });
  });

  group('TaskRepository integer key migration', () {
    test('integer-keyed tasks are migrated to string ID keys', () async {
      // Close the repo so we can manipulate the raw box
      await repo.close();

      // Reopen raw box and put tasks with integer keys
      final rawBox = await Hive.openBox<Task>('tasksBox');
      await rawBox.put(0, Task(id: 'mig-1', title: 'Legacy Task 1'));
      await rawBox.put(1, Task(id: 'mig-2', title: 'Legacy Task 2'));
      await rawBox.put(2, Task(id: 'mig-3', title: 'Legacy Task 3'));
      await rawBox.flush();
      // Verify integer keys exist
      expect(rawBox.keys.first is int, isTrue);
      await rawBox.close();

      // Create new repo and load — should trigger migration
      repo = TaskRepository();
      final loaded = await repo.loadTasks();
      expect(loaded.length, 3);

      // After migration, keys should be string IDs
      final box = _getTypedBox();
      expect(box.keys.every((k) => k is String), isTrue);
      final ids = loaded.map((t) => t.id).toSet();
      expect(ids, containsAll(['mig-1', 'mig-2', 'mig-3']));
    });
  });
}
