import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/player.dart';
import '../repositories/player_repository.dart';
import '../repositories/task_repository.dart';

class GameViewModel extends ChangeNotifier {
  final PlayerRepository _playerRepository;
  final TaskRepository _taskRepository;

  Player _player = Player();
  List<Task> _tasks = [];
  int _tutorialStep = 0;
  bool _isLoaded = false;
  bool _hasSeenConcept = false;

  GameViewModel({
    PlayerRepository? playerRepository,
    TaskRepository? taskRepository,
  })  : _playerRepository = playerRepository ?? PlayerRepository(),
        _taskRepository = taskRepository ?? TaskRepository() {
    loadData();
  }

  Player get player => _player;
  List<Task> get tasks => _tasks;
  int get tutorialStep => _tutorialStep;
  bool get isLoaded => _isLoaded;
  bool get hasSeenConcept => _hasSeenConcept;

  int get fatigueWarnThreshold => 5 + _player.todayTaskLimitOffset;
  int get fatigueSevereThreshold => 10 + _player.todayTaskLimitOffset;

  String get fatigueStatus {
    if (_player.dailyTasksCompleted >= fatigueSevereThreshold) return "💀 疲労困憊";
    if (_player.dailyTasksCompleted >= fatigueWarnThreshold) return "⚠️ 疲労";
    return "😄 元気";
  }

  double get fatigueProgress {
    return (_player.dailyTasksCompleted / fatigueSevereThreshold).clamp(0.0, 1.0);
  }

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

  void addTask(String title, {QuestRank rank = QuestRank.B, RepeatInterval repeatInterval = RepeatInterval.none, List<int>? repeatWeekdays, List<SubTask>? subTasks, int? targetTimeMinutes}) {
    final newTask = Task(
      id: const Uuid().v4(),
      title: title,
      rank: rank,
      repeatInterval: repeatInterval,
      repeatWeekdays: repeatWeekdays,
      subTasks: subTasks,
      targetTimeMinutes: targetTimeMinutes,
    );
    _tasks.add(newTask);
    if (_tutorialStep == 0) completeTutorialStep(0);
    _notifyAndSave();
  }

  void editTask(String taskId, String title, {QuestRank rank = QuestRank.B, RepeatInterval repeatInterval = RepeatInterval.none, List<int>? repeatWeekdays, List<SubTask>? subTasks, int? targetTimeMinutes}) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].title = title;
      _tasks[index].rank = rank;
      _tasks[index].repeatInterval = repeatInterval;
      _tasks[index].repeatWeekdays = repeatWeekdays ?? [];
      _tasks[index].subTasks = subTasks ?? [];
      _tasks[index].targetTimeMinutes = targetTimeMinutes;
      _notifyAndSave();
    }
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
    _tasks[index].activeAt = DateTime.now(); // タスク開始日時を記録
    if (_tutorialStep == 1) completeTutorialStep(1);
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

  Map<String, dynamic>? completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return null;

    final task = _tasks[index];

    // Wizard: Subtask Check
    if (_player.canUseSkill(Job.wizard) && task.subTasks.isNotEmpty) {
      if (task.subTasks.any((s) => !s.isCompleted)) {
        return null; 
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
    
    // 状態のリセット確認（日付変更後初回のタスク完了時用）
    _checkAndResetMissions();

    List<String> bonusMessages = [];

    // 不正対策（疲労度システム）
    // 1日にこなせるクエスト量に制限を設け、乱発を防ぐ
    double fatigueMultiplier = 1.0;
    int fatigueWarnThreshold = 5 + _player.todayTaskLimitOffset;
    int fatigueSevereThreshold = 10 + _player.todayTaskLimitOffset;

    if (_player.dailyTasksCompleted >= fatigueSevereThreshold) {
      fatigueMultiplier = 0.1;
      bonusMessages.add("⚠️ 疲労困憊 (取得報酬10%)");
    } else if (_player.dailyTasksCompleted >= fatigueWarnThreshold) {
      fatigueMultiplier = 0.5;
      bonusMessages.add("⚠️ 疲労 (取得報酬50%)");
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
    
    expGain = (expGain * fatigueMultiplier).round();

    // 称号ボーナス (装備しているとベースのEXPに+5%)
    if (_player.equippedTitle != null) {
      expGain = (expGain * 1.05).round();
    }

    // ========== 新ゲーミング機能 ==========
    int coinsGained = task.rank == QuestRank.S ? 100 : task.rank == QuestRank.A ? 30 : 10;
    coinsGained = (coinsGained * fatigueMultiplier).round();
    
    // 1. タイムアタック・ボーナス
    if (task.targetTimeMinutes != null && task.activeAt != null) {
      final usedMinutes = DateTime.now().difference(task.activeAt!).inMinutes;
      if (usedMinutes <= task.targetTimeMinutes!) {
        int speedBonus = 50;
        coinsGained += speedBonus;
        bonusMessages.add("🕒 スピードクリアボーナス！ +$speedBonus金貨");
      }
    }

    // レベル依存のレアドロップ (確率はレベル*2%、最大50%)
    double dropChance = (_player.level * 0.02).clamp(0.01, 0.5);
    bool isRare = (DateTime.now().millisecond % 100) < (dropChance * 100);
    if (isRare) {
      int rareBonus = (coinsGained * 5 * fatigueMultiplier).round();
      if (rareBonus > 0) {
        coinsGained += rareBonus;
        bonusMessages.add("✨ レアドロップ発見！！ +$rareBonus金貨");
      }
    }

    // 3. ミッション（習慣化）と称号チェック
    _player.dailyTasksCompleted++;
    if (task.rank == QuestRank.S) _player.weeklySRankCompleted++;

    _player.totalTasksCompleted++;
    if (task.rank == QuestRank.S) _player.totalSRankCompleted++;
    if (task.rank == QuestRank.A) _player.totalARankCompleted++;
    if (task.rank == QuestRank.B) _player.totalBRankCompleted++;

    _checkTitles(bonusMessages);

    if (_player.dailyTasksCompleted == 3) {
      int dailyBonus = 200;
      coinsGained += dailyBonus;
      bonusMessages.add("📅 デイリーミッション達成！ +$dailyBonus金貨");
    }
    if (task.rank == QuestRank.S && _player.weeklySRankCompleted == 1) { // 初回のみ
      int weeklyBonus = 500;
      coinsGained += weeklyBonus;
      bonusMessages.add("🏆 ウィークリーSランク達成！ +$weeklyBonus金貨");
    }

    _player.coins += coinsGained;
    // ===================================
    
    bool leveledUp = _player.addExp(expGain); 
    if (_tutorialStep == 2) completeTutorialStep(2);
    _notifyAndSave();
    
    return {
      'leveledUp': leveledUp,
      'coinsGained': coinsGained,
      'bonusMessages': bonusMessages,
    };
  }

  void buyShopItem(String itemId, int price) {
    if (_player.coins >= price && !_player.homeItems.contains(itemId)) {
      _player.coins -= price;
      _player.homeItems.add(itemId);
      _notifyAndSave();
    }
  }

  void _checkAndResetMissions() {
    final now = DateTime.now();
    
    // デイリーリセット
    if (_player.lastMissionResetDate == null || 
        _player.lastMissionResetDate!.day != now.day ||
        _player.lastMissionResetDate!.month != now.month ||
        _player.lastMissionResetDate!.year != now.year) {
      _player.dailyTasksCompleted = 0;
      // 昨日稼いだ休息ボーナスを今日に適用
      _player.todayTaskLimitOffset = _player.nextDayTaskLimitOffset;
      _player.nextDayTaskLimitOffset = 0;
      _player.lastMissionResetDate = now;
    }
    
    // ウィークリーリセットは便宜上ここでは月曜日にリセットとする
    // 厳密なウィークリー管理は少し複雑なので、lastMissionResetDateからの経過日数などで判定も可能だが
    // 今回は簡易に「週が変わっていたらリセット」
    if (_player.lastMissionResetDate != null) {
      // is after next monday or week changed
      int currentWeek = (now.day - now.weekday + 10) ~/ 7;
      int lastWeek = (_player.lastMissionResetDate!.day - _player.lastMissionResetDate!.weekday + 10) ~/ 7;
      if (now.year > _player.lastMissionResetDate!.year || 
          now.month > _player.lastMissionResetDate!.month || 
          currentWeek != lastWeek) {
        _player.weeklySRankCompleted = 0;
      }
    }
  }

  // --- 称号システム（案3） ---
  void _checkTitles(List<String> bonusMessages) {
    _unlockTitle("見習い冒険者", () => _player.totalTasksCompleted >= 10, bonusMessages);
    _unlockTitle("ベテラン", () => _player.totalTasksCompleted >= 100, bonusMessages);
    _unlockTitle("ゴブリンスレイヤー", () => _player.totalBRankCompleted >= 50, bonusMessages);
    _unlockTitle("エリートハンター", () => _player.totalARankCompleted >= 20, bonusMessages);
    _unlockTitle("竜殺し", () => _player.totalSRankCompleted >= 5, bonusMessages);
  }

  void _unlockTitle(String targetTitle, bool Function() condition, List<String> messages) {
    if (!_player.titles.contains(targetTitle) && condition()) {
      _player.titles.add(targetTitle);
      messages.add("🏅 称号獲得：『$targetTitle』");
    }
  }

  void equipTitle(String title) {
    if (_player.titles.contains(title) || title.isEmpty) {
      _player.equippedTitle = title.isEmpty ? null : title;
      _notifyAndSave();
    }
  }

  void equipSkin(String skinId) {
    if (_player.homeItems.contains(skinId) || skinId.isEmpty) {
      _player.equippedSkin = skinId.isEmpty ? null : skinId;
      _notifyAndSave();
    }
  }

  // --- 宿屋システム（案1） ---
  String? restAtInn(int innType) {
    final now = DateTime.now();
    if (_player.lastRestDate != null && 
        _player.lastRestDate!.year == now.year &&
        _player.lastRestDate!.month == now.month &&
        _player.lastRestDate!.day == now.day) {
      return "今日はもう十分休んだ。また明日来な！";
    }

    int cost = 0;
    int limitBonus = 0;

    switch (innType) {
      case 0: // テント
        cost = 50;
        limitBonus = 2; // 翌日の限界数+2
        break;
      case 1: // 普通のベッド
        cost = 200;
        limitBonus = 5; // 翌日の限界数+5
        break;
      case 2: // 王様のベッド
        cost = 1000;
        limitBonus = 12; // 翌日の限界数+12
        break;
      default:
        return "そんなメニューはないぜ";
    }

    if (_player.coins < cost) {
      return "金貨が足りないぜ";
    }

    _player.coins -= cost;
    _player.nextDayTaskLimitOffset = limitBonus;
    _player.lastRestDate = now;
    _notifyAndSave();
    return null; // Success
  }

  Future<void> loadData() async {
    _player = await _playerRepository.loadPlayer();
    _tasks = await _taskRepository.loadTasks();
    var box = await Hive.openBox('tutorialBox');
    _tutorialStep = box.get('step', defaultValue: 0);
    _hasSeenConcept = box.get('hasSeenConcept', defaultValue: false);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> completeTutorialStep(int step) async {
    if (_tutorialStep == step) {
      _tutorialStep++;
      var box = await Hive.openBox('tutorialBox');
      await box.put('step', _tutorialStep);
      notifyListeners();
    }
  }

  Future<void> markConceptAsSeen() async {
    if (!_hasSeenConcept) {
      _hasSeenConcept = true;
      var box = await Hive.openBox('tutorialBox');
      await box.put('hasSeenConcept', true);
      notifyListeners();
    }
  }

  Future<void> resetTutorial() async {
    _tutorialStep = 0;
    _hasSeenConcept = false;
    var box = await Hive.openBox('tutorialBox');
    await box.put('step', 0);
    await box.put('hasSeenConcept', false);
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
