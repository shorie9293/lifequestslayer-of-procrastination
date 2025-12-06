
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
  List<Task> get activeTasks {
    return _tasks.where((t) {
      if (t.status != TaskStatus.active || t.isCompleted) return false;
      
      // Cleric: Hide daily/weekly tasks if already completed this cycle
      // Logic Refinement:
      // If repeatInterval != none:
      //   If lastCompletedAt is today -> Hide.
      //   If Weekly and repeatWeekdays is set -> Show only on those days.
      if (_player.currentJob == Job.cleric && t.repeatInterval != RepeatInterval.none) {
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
    }).toList();
  }

  ThemeData get currentTheme {
    switch (_player.currentJob) {
      case Job.warrior:
        return _warriorTheme;
      case Job.cleric:
        return _clericTheme;
      case Job.wizard:
        return _wizardTheme;
      case Job.adventurer:
        return _adventurerTheme;
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

  // Define themes
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

  void toggleSubTask(String taskId, int subTaskIndex) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      if (subTaskIndex >= 0 && subTaskIndex < task.subTasks.length) {
        task.subTasks[subTaskIndex].isCompleted = !task.subTasks[subTaskIndex].isCompleted;
        notifyListeners();
      }
    }
  }

  void changeJob(Job newJob) {
    _player.currentJob = newJob;
    notifyListeners();
  }

  bool completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];

      // Wizard: Check subtasks
      if (_player.currentJob == Job.wizard && task.subTasks.isNotEmpty) {
        if (task.subTasks.any((s) => !s.isCompleted)) {
           // Maybe return a specific result or just false?
           // Ideally we should notify UI *why*. 
           // For now, failure to complete implies requirements not met.
          return false; 
        }
      }

      // Logic for Repeatable Tasks (Cleric)
      if (_player.currentJob == Job.cleric && task.repeatInterval != RepeatInterval.none) {
         _tasks[index].lastCompletedAt = DateTime.now();
         // Do NOT set isCompleted = true for repeatable tasks, just mark timestamp and keep active/inguild?
         // Actually spec says "Completed but resurfaces next day". 
         // So for implementation: keep it active or moved back to guild?
         // "完了しても翌日復活する" -> Stays in list but hidden or visually marked done.
         // Let's keep it 'active' but hidden by the getter.
      } else {
        _tasks[index].isCompleted = true;
        _tasks[index].status = TaskStatus.inGuild; 
      }
      
      // Warrior: Combo Bonus
      int expGain = 50;
      if (_player.currentJob == Job.warrior) {
        _player.comboCount++;
        expGain += (_player.comboCount * 5); // Simple bonus
      } else {
        // Reset combo if not warrior or maybe just keep it but don't use it? 
        // Let's reset combo on job change or meaningful gap? 
        // For now, if switching job, maybe reset? or just ignore. 
        // If not warrior, we probably shouldn't increase it. 
        // Actually, if we want to reset combo when failing/delaying, that's complex.
        // Let's just say only Warrior gains combo.
        // If completing as non-warrior, does it reset? Let's say yes, or just 0.
        _player.comboCount = 0;
      }
      
      // Award EXP
      bool leveledUp = _player.addExp(expGain); 
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
