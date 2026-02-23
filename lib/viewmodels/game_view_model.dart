import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/player.dart';
import '../repositories/player_repository.dart';
import '../repositories/task_repository.dart';

class GameViewModel extends ChangeNotifier {
  final PlayerRepository _playerRepository;
  final TaskRepository _taskRepository;

  Player _player = Player();
  List<Task> _tasks = [];

  GameViewModel({
    PlayerRepository? playerRepository,
    TaskRepository? taskRepository,
  })  : _playerRepository = playerRepository ?? PlayerRepository(),
        _taskRepository = taskRepository ?? TaskRepository() {
    loadData();
  }

  Player get player => _player;
  List<Task> get tasks => _tasks;

  List<Task> get guildTasks => _tasks.where((t) => t.status == TaskStatus.inGuild && !t.isCompleted).toList();
  
  List<Task> get activeTasks {
    return _tasks.where((t) {
      if (t.status != TaskStatus.active || t.isCompleted) return false;
      return _isVisibleForPlayer(t);
    }).toList();
  }

  bool _isVisibleForPlayer(Task t) {
      // Cleric: Hide daily/weekly tasks if already completed this cycle
      // Logic: If Cleric Skill Active (current job or inherited)
      if (_player.canUseSkill(Job.cleric) && t.repeatInterval != RepeatInterval.none) {
         final now = DateTime.now();

         // Weekday Check for Weekly tasks
         if (t.repeatInterval == RepeatInterval.weekly && t.repeatWeekdays.isNotEmpty) {
           if (!t.repeatWeekdays.contains(now.weekday)) {
             return false; // Not today
           }
         }

         // Completion Check (Hidden if done today)
         if (t.lastCompletedAt != null) {
            final last = t.lastCompletedAt!;
            if (now.year == last.year && now.month == last.month && now.day == last.day) {
              return false; // Completed today
            }
         }
      }
      return true;
  }

  ThemeData get currentTheme {
    switch (_player.currentJob) {
      case Job.warrior: return _warriorTheme;
      case Job.cleric: return _clericTheme;
      case Job.wizard: return _wizardTheme;
      case Job.adventurer: return _adventurerTheme;
    }
  }

  final _adventurerTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.brown,
    scaffoldBackgroundColor: const Color(0xFF2e2b1a),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF3e3b16), elevation: 0),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark, primarySwatch: Colors.brown, accentColor: Colors.green),
     useMaterial3: true,
  );

  final _warriorTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.red,
    scaffoldBackgroundColor: const Color(0xFF2e1a1a),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF3e1616), elevation: 0),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark, primarySwatch: Colors.red, accentColor: Colors.orange),
    useMaterial3: true,
  );

  final _clericTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.cyan,
    scaffoldBackgroundColor: const Color(0xFF1a2e2e),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF163e3e), elevation: 0),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark, primarySwatch: Colors.cyan, accentColor: Colors.tealAccent),
     useMaterial3: true,
  );

  final _wizardTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.deepPurple,
    scaffoldBackgroundColor: const Color(0xFF1a1a2e),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF16213e), elevation: 0),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark, primarySwatch: Colors.deepPurple, accentColor: Colors.amber),
     useMaterial3: true,
  );

  void addTask(String title, {QuestRank rank = QuestRank.B, RepeatInterval repeatInterval = RepeatInterval.none, List<int>? repeatWeekdays, List<SubTask>? subTasks}) {
    final newTask = Task(
      id: const Uuid().v4(),
      title: title,
      rank: rank,
      repeatInterval: repeatInterval,
      repeatWeekdays: repeatWeekdays,
      subTasks: subTasks,
    );
    _tasks.add(newTask);
    _notifyAndSave();
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
    _notifyAndSave();
    return null; // Success
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    _notifyAndSave();
  }

  void cancelTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].status = TaskStatus.inGuild;
      _notifyAndSave();
    }
  }

  void toggleSubTask(String taskId, int subTaskIndex) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      if (subTaskIndex >= 0 && subTaskIndex < task.subTasks.length) {
        task.subTasks[subTaskIndex].isCompleted = !task.subTasks[subTaskIndex].isCompleted;
        _notifyAndSave();
      }
    }
  }

  void changeJob(Job newJob) {
    _player.currentJob = newJob;
    _notifyAndSave();
  }

  void toggleSkill(Job job) {
    if (_player.isMastered(job)) {
      if (_player.activeSkills.contains(job)) {
        _player.activeSkills.remove(job);
      } else {
        _player.activeSkills.add(job);
      }
      _notifyAndSave();
    }
  }

  bool completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return false;

    final task = _tasks[index];

    // Wizard: Subtask Check
    if (_player.canUseSkill(Job.wizard) && task.subTasks.isNotEmpty) {
      if (task.subTasks.any((s) => !s.isCompleted)) {
        return false; 
      }
    }

    // Cleric: Repeatable Logic
    if (_player.canUseSkill(Job.cleric) && task.repeatInterval != RepeatInterval.none) {
       _tasks[index].lastCompletedAt = DateTime.now();
       // Keeps status active but hidden by getter
    } else {
      _tasks[index].isCompleted = true;
      _tasks[index].status = TaskStatus.inGuild; 
    }
    
    // XP Logic
    int expGain = 0;
    switch (task.rank) {
      case QuestRank.S: expGain = 1000; break;
      case QuestRank.A: expGain = 300; break;
      case QuestRank.B: expGain = 100; break;
    }
    
    // Warrior: Combo Bonus
    if (_player.canUseSkill(Job.warrior)) {
      _player.comboCount++;
      expGain += (_player.comboCount * 10); 
    } else {
      _player.comboCount = 0;
    }
    
    bool leveledUp = _player.addExp(expGain); 
    _notifyAndSave();
    return leveledUp;
  }

  Future<void> loadData() async {
    _player = await _playerRepository.loadPlayer();
    _tasks = await _taskRepository.loadTasks();
    notifyListeners();
  }

  Future<void> saveData() async {
    await _playerRepository.savePlayer(_player);
    await _taskRepository.saveTasks(_tasks);
  }

  void _notifyAndSave() {
    notifyListeners();
    saveData();
  }
}
