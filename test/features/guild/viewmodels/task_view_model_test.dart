import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';

class _MockPlayerRepo implements IPlayerRepository {
  Player _player = Player();
  @override
  Future<Player> loadPlayer() async => _player;
  @override
  Future<void> savePlayer(Player p) async => _player = p;
  @override
  Future<void> close() async {}
}

class _MockTaskRepo implements ITaskRepository {
  final List<Task> _tasks = [];
  @override
  Future<List<Task>> loadTasks() async => List.from(_tasks);
  @override
  Future<void> saveTasks(List<Task> tasks) async {
    _tasks.clear();
    _tasks.addAll(tasks);
  }
  @override
  Future<void> close() async {}
}

void main() {
  group('TaskViewModel', () {
    test('tasks is empty after construction and load', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      final taskVm = TaskViewModel(_MockTaskRepo(), playerVm);
      await taskVm.load();
      expect(taskVm.tasks, isEmpty);
    });

    test('tasks remains empty after reload', () async {
      final playerVm = PlayerViewModel(_MockPlayerRepo());
      await playerVm.load();
      final taskVm = TaskViewModel(_MockTaskRepo(), playerVm);
      await taskVm.load();
      await taskVm.load();
      expect(taskVm.tasks, isEmpty);
    });
  });
}
