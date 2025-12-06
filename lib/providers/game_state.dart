
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/player.dart';

class GameState extends ChangeNotifier {
  final Player _player = Player();
  final List<Task> _tasks = [];

  Player get player => _player;
  List<Task> get tasks => _tasks;

  List<Task> get guildTasks => _tasks.where((t) => t.status == TaskStatus.inGuild && !t.isCompleted).toList();
  List<Task> get activeTasks => _tasks.where((t) => t.status == TaskStatus.active && !t.isCompleted).toList();

  void addTask(String title, {QuestRank rank = QuestRank.B}) {
    final newTask = Task(
      id: const Uuid().v4(),
      title: title,
      rank: rank,
    );
    _tasks.add(newTask);
    notifyListeners();
  }

  String? acceptTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return "タスクが見つかりません";

    final task = _tasks[index];
    final currentRankActiveCount = activeTasks.where((t) => t.rank == task.rank).length;

    if (!_player.canAcceptQuest(task.rank, currentRankActiveCount)) {
      return "${task.rank.name}ランクのキャパシティオーバー！";
    }

    _tasks[index].status = TaskStatus.active;
    notifyListeners();
    return null; // Success
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  void cancelTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].status = TaskStatus.inGuild;
      notifyListeners();
    }
  }

  bool completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].isCompleted = true;
      _tasks[index].status = TaskStatus.inGuild; 
      
      // Award EXP
      bool leveledUp = _player.addExp(50); // Fixed 50 EXP per task for MVP
      notifyListeners();
      return leveledUp;
    }
    return false;
  }
}
