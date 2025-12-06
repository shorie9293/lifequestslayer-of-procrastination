
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import '../models/player.dart';

class GameState extends ChangeNotifier {
  Player _player = Player();
  List<Task> _tasks = [];

  GameState() {
    loadData();
  }

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
  Future<void> loadData() async {
    final playerBox = Hive.box<Player>('playerBox');
    if (playerBox.isNotEmpty) {
      _player = playerBox.getAt(0)!;
    }

    final tasksBox = Hive.box<Task>('tasksBox');
    _tasks = tasksBox.values.toList();
    
    // Avoid double-notifying on initial load if possible, 
    // but constructor calls this so it's fine.
    // However, we should be careful about the loop with saveData().
    // Since loadData is called in constructor, creating an instance calls it.
  }

  Future<void> saveData() async {
    final playerBox = Hive.box<Player>('playerBox');
    playerBox.put(0, _player);

    final tasksBox = Hive.box<Task>('tasksBox');
    await tasksBox.clear();
    await tasksBox.addAll(_tasks);
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    saveData(); // Auto-save on any change
  }
}
