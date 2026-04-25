import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/player.dart';
import '../models/title_definition.dart';
import '../data/quiz_data.dart';
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
  int? pendingLoginBonusAmount;
  int? pendingStreakReward;   // ストリーク報酬（ログイン後にUIが表示）
  double _fontSizeScale = 1.2;

  // v1.2: 疲労MAXダイアログは1日1回のみ（settingsBoxに日付を永続化）
  bool _hasShownFatiguePopupToday = false;

  // v1.2: 出題確率 (テスト時に override しやすいよう定数化)
  static const double kKnowledgeQuestProbability = 0.30;

  // v1.2: 知識クエスト機能のON/OFF（設定から切替可能）
  bool _knowledgeQuestEnabled = true;
  bool get isKnowledgeQuestEnabled => _knowledgeQuestEnabled;

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
  double get fontSizeScale => _fontSizeScale;

  int get fatigueWarnThreshold => 5 + _player.todayTaskLimitOffset;
  int get fatigueSevereThreshold => 10 + _player.todayTaskLimitOffset;

  String get fatigueStatus {
    if (_player.dailyTasksCompleted >= fatigueSevereThreshold) return "🌙 今日の英雄は休め";
    if (_player.dailyTasksCompleted >= fatigueWarnThreshold) return "🍺 十分戦った";
    return "😄 元気";
  }

  double get fatigueProgress {
    return (_player.dailyTasksCompleted / fatigueSevereThreshold).clamp(0.0, 1.0);
  }

  // --- デイリー/ウィークリーミッション ---
  static const int dailyMissionGoal = 3;
  static const int weeklyMissionGoal = 1;

  int get dailyMissionProgress => _player.dailyTasksCompleted.clamp(0, dailyMissionGoal);
  bool get isDailyMissionComplete => _player.dailyTasksCompleted >= dailyMissionGoal;
  int get weeklyMissionProgress => _player.weeklySRankCompleted.clamp(0, weeklyMissionGoal);
  bool get isWeeklyMissionComplete => _player.weeklySRankCompleted >= weeklyMissionGoal;

  // --- ストリーク ---
  int get streakDays => _player.streakDays;

  // --- 称号進捗 ---
  /// 各称号の現在進捗を返す（GameViewModel._checkTitles と同じ定義源を参照）
  List<({TitleDefinition def, int progress, bool isUnlocked})> get titleProgressList {
    return kAllTitles.map((def) {
      final progress = def.getProgress(_player);
      final isUnlocked = _player.titles.contains(def.id);
      return (def: def, progress: progress, isUnlocked: isUnlocked);
    }).toList();
  }

  List<Task> get recurringTasks => _tasks.where((t) => t.repeatInterval != RepeatInterval.none).toList();

  List<Task> get guildTasks => _tasks.where((t) => t.status == TaskStatus.inGuild && !t.isCompleted).toList();

  List<Task> get activeTasks {
    return _tasks.where((t) {
      if (t.status != TaskStatus.active || t.isCompleted) return false;
      return _isVisibleForPlayer(t);
    }).toList();
  }

  bool _isVisibleForPlayer(Task t) {
    if (_player.canUseSkill(Job.cleric) && t.repeatInterval != RepeatInterval.none) {
      final now = DateTime.now();
      if (t.repeatInterval == RepeatInterval.weekly && t.repeatWeekdays.isNotEmpty) {
        if (!t.repeatWeekdays.contains(now.weekday)) return false;
      }
      if (t.lastCompletedAt != null) {
        final last = t.lastCompletedAt!;
        if (now.year == last.year && now.month == last.month && now.day == last.day) return false;
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
    _tasks[index].activeAt = DateTime.now();
    if (_tutorialStep == 1) completeTutorialStep(1);
    _notifyAndSave();
    return null;
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

  /// タスクを完了する。
  /// 戻り値:
  ///   null = 完了失敗（サブタスク未完了など）
  ///   Map = 完了成功。以下のキーを含む:
  ///     'leveledUp': bool
  ///     'coinsGained': int
  ///     'bonusMessages': List<String>
  ///     'showFatiguePopup': bool  (疲労MAXに到達した瞬間のみ true)
  ///     'quizQuestion': QuizQuestion? (抽選で出題される場合)
  Map<String, dynamic>? completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return null;

    final task = _tasks[index];

    // Wizard: サブタスク完了チェック
    if (_player.canUseSkill(Job.wizard) && task.subTasks.isNotEmpty) {
      if (task.subTasks.any((s) => !s.isCompleted)) return null;
    }

    // Cleric: 繰り返しタスクは isCompleted にしない
    if (_player.canUseSkill(Job.cleric) && task.repeatInterval != RepeatInterval.none) {
      _tasks[index].lastCompletedAt = DateTime.now();
    } else {
      _tasks[index].isCompleted = true;
      _tasks[index].status = TaskStatus.inGuild;
    }

    _checkAndResetMissions();

    List<String> bonusMessages = [];

    // 疲労補正
    double fatigueMultiplier = 1.0;
    int fatigueWarn = 5 + _player.todayTaskLimitOffset;
    int fatigueSevere = 10 + _player.todayTaskLimitOffset;

    if (_player.dailyTasksCompleted >= fatigueSevere) {
      fatigueMultiplier = 0.1;
      bonusMessages.add("🌙 今日の英雄は十分戦った。宿屋で休んで明日に備えよ！");
    } else if (_player.dailyTasksCompleted >= fatigueWarn) {
      fatigueMultiplier = 0.5;
      bonusMessages.add("🍺 疲れが溜まってきたぞ。宿屋で一息つくか？");
    }

    // XP 計算
    int expGain = switch (task.rank) {
      QuestRank.S => 1000,
      QuestRank.A => 300,
      QuestRank.B => 100,
    };

    // Warrior: コンボボーナス
    if (_player.canUseSkill(Job.warrior)) {
      _player.comboCount++;
      int comboBonus = _player.comboCount * 10;
      expGain += comboBonus;
      if (_player.comboCount > 1) {
        bonusMessages.add("⚔️ ${_player.comboCount}コンボ！ +${comboBonus} EXP");
      }
    } else {
      _player.comboCount = 0;
    }

    expGain = (expGain * fatigueMultiplier).round();

    // 称号ボーナス (+5%)
    if (_player.equippedTitle != null) {
      expGain = (expGain * 1.05).round();
    }

    // コイン計算
    int coinsGained = task.rank == QuestRank.S ? 100 : task.rank == QuestRank.A ? 30 : 10;
    coinsGained = (coinsGained * fatigueMultiplier).round();

    // タイムアタックボーナス
    if (task.targetTimeMinutes != null && task.activeAt != null) {
      final usedMinutes = DateTime.now().difference(task.activeAt!).inMinutes;
      if (usedMinutes <= task.targetTimeMinutes!) {
        int speedBonus = 50;
        coinsGained += speedBonus;
        bonusMessages.add("🕒 スピードクリアボーナス！ +$speedBonus金貨");
      }
    }

    // レアドロップ
    double dropChance = (_player.level * 0.02).clamp(0.01, 0.5);
    bool isRare = Random().nextDouble() < dropChance;
    if (isRare) {
      int rareBonus = (coinsGained * 5 * fatigueMultiplier).round();
      if (rareBonus > 0) {
        coinsGained += rareBonus;
        bonusMessages.add("✨ レアドロップ発見！！ +$rareBonus金貨");
      }
    }

    // ミッション・称号カウント更新
    _player.dailyTasksCompleted++;
    if (task.rank == QuestRank.S) _player.weeklySRankCompleted++;
    _player.totalTasksCompleted++;
    if (task.rank == QuestRank.S) _player.totalSRankCompleted++;
    if (task.rank == QuestRank.A) _player.totalARankCompleted++;
    if (task.rank == QuestRank.B) _player.totalBRankCompleted++;

    _checkTitles(bonusMessages);

    // デイリーミッション達成（3クエスト）
    if (_player.dailyTasksCompleted == dailyMissionGoal) {
      int dailyBonus = 200;
      coinsGained += dailyBonus;
      bonusMessages.add("📅 デイリーミッション達成！ +$dailyBonus金貨");
    }
    // ウィークリーミッション達成（初回Sランク）
    if (task.rank == QuestRank.S && _player.weeklySRankCompleted == 1) {
      int weeklyBonus = 500;
      coinsGained += weeklyBonus;
      bonusMessages.add("🏆 ウィークリーSランク達成！ +$weeklyBonus金貨");
    }

    _player.coins += coinsGained;

    bool leveledUp = _player.addExp(expGain);
    if (_tutorialStep == 2) completeTutorialStep(2);

    // 疲労MAXポップアップトリガー（到達した瞬間のみ・1日1回・アプリ再起動後も維持）
    bool showFatiguePopup = false;
    if (_player.dailyTasksCompleted >= fatigueSevere && !_hasShownFatiguePopupToday) {
      _hasShownFatiguePopupToday = true;
      showFatiguePopup = true;
      // settingsBoxに日付を永続化してアプリ再起動後もフラグを保持
      try {
        Hive.box('settingsBox').put('fatiguePopupDate', DateTime.now().toIso8601String());
      } catch (_) {}
    }

    // v1.2: 知識クエスト抽選（クイズ出題確率 30%・ON/OFFあり）
    QuizQuestion? quizQuestion;
    if (_knowledgeQuestEnabled &&
        kQuizQuestions.isNotEmpty &&
        Random().nextDouble() < kKnowledgeQuestProbability) {
      quizQuestion = kQuizQuestions[Random().nextInt(kQuizQuestions.length)];
    }

    _notifyAndSave();

    return {
      'leveledUp': leveledUp,
      'coinsGained': coinsGained,
      'bonusMessages': bonusMessages,
      'showFatiguePopup': showFatiguePopup,
      'quizQuestion': quizQuestion,
      'baseExp': expGain, // クイズボーナス計算用
    };
  }

  /// 知識クエスト正解時のボーナスEXP付与（UI側から呼ぶ）
  void awardKnowledgeBonus(int bonusPercent, int baseExp) {
    final bonus = (baseExp * bonusPercent / 100).round();
    if (bonus > 0) {
      _player.addExp(bonus);
      _notifyAndSave();
    }
  }

  // --- 宝石システム ---

  void addGems(int amount) {
    _player.gems += amount;
    _notifyAndSave();
  }

  bool spendGems(int amount) {
    if (_player.gems < amount) return false;
    _player.gems -= amount;
    _notifyAndSave();
    return true;
  }

  bool exchangeGemsForCoins(int gemAmount) {
    if (!spendGems(gemAmount)) return false;
    _player.coins += gemAmount * 100;
    _notifyAndSave();
    return true;
  }

  bool resetFatigueWithGems() {
    if (!spendGems(50)) return false;
    _player.dailyTasksCompleted = 0;
    _notifyAndSave();
    return true;
  }

  void buyShopItem(String itemId, int price) {
    if (_player.coins >= price && !_player.homeItems.contains(itemId)) {
      _player.coins -= price;
      _player.homeItems.add(itemId);
      _notifyAndSave();
    }
  }

  void _checkAndResetMissions({bool isLogin = false}) {
    final now = DateTime.now();
    bool changedDate = false;

    // デイリーリセット
    if (_player.lastMissionResetDate == null ||
        !_isSameDay(_player.lastMissionResetDate!, now)) {
      _player.dailyTasksCompleted = 0;
      _player.todayTaskLimitOffset = _player.nextDayTaskLimitOffset;
      _player.nextDayTaskLimitOffset = 0;
      _player.lastMissionResetDate = now;
      _hasShownFatiguePopupToday = false;
      // 永続化した疲労フラグも消去（try: settingsBoxが未開放のケース対応）
      try { Hive.box('settingsBox').delete('fatiguePopupDate'); } catch (_) {}
      changedDate = true;
    }

    // ウィークリーリセット（月またぎに対応した正確な判定）
    if (_player.lastMissionResetDate != null &&
        _isDifferentWeek(_player.lastMissionResetDate!, now)) {
      _player.weeklySRankCompleted = 0;
    }

    if (isLogin) {
      _checkAndUpdateStreak(now);
      if (changedDate) {
        _player.coins += 50; // ログインボーナス
        pendingLoginBonusAmount = 50;
        _notifyAndSave();
      }
    }
  }

  // --- ストリーク更新 ---
  void _checkAndUpdateStreak(DateTime now) {
    final last = _player.lastLoginDate;

    if (last == null) {
      // 初回ログイン
      _player.streakDays = 1;
    } else if (_isSameDay(last, now)) {
      // 同日の再起動は何もしない
      return;
    } else if (_isYesterday(last, now)) {
      // 昨日ログイン済み → ストリーク継続
      _player.streakDays++;
    } else {
      // 2日以上空白 → リセット
      _player.streakDays = 1;
    }

    _player.longestStreak = max(_player.longestStreak, _player.streakDays);
    _player.lastLoginDate = now;

    // ストリーク報酬
    final reward = _calcStreakReward(_player.streakDays);
    if (reward > 0) {
      _player.coins += reward;
      pendingStreakReward = reward;
    }
  }

  int _calcStreakReward(int days) {
    if (days == 30) return 5000;
    if (days == 14) return 2000;
    if (days == 7)  return 1000;
    if (days == 5)  return 500;
    if (days == 3)  return 200;
    if (days == 2)  return 100;
    return 0;
  }

  // --- 日付ユーティリティ ---

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isYesterday(DateTime past, DateTime now) {
    final yesterday = now.subtract(const Duration(days: 1));
    return _isSameDay(past, yesterday);
  }

  /// ISO 週が異なるかどうかを判定（月またぎに対応）
  bool _isDifferentWeek(DateTime a, DateTime b) {
    // 各日の月曜日を計算して比較
    final mondayA = a.subtract(Duration(days: a.weekday - 1));
    final mondayB = b.subtract(Duration(days: b.weekday - 1));
    return !_isSameDay(
      DateTime(mondayA.year, mondayA.month, mondayA.day),
      DateTime(mondayB.year, mondayB.month, mondayB.day),
    );
  }

  // --- 称号システム ---
  void _checkTitles(List<String> bonusMessages) {
    for (final def in kAllTitles) {
      _unlockTitle(def.id, () => def.getProgress(_player) >= def.requiredCount, bonusMessages);
    }
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

  // --- 宿屋システム ---
  String? restAtInn(int innType) {
    final now = DateTime.now();
    if (_player.lastRestDate != null &&
        _isSameDay(_player.lastRestDate!, now)) {
      return "今日はもう十分休んだ。また明日来な！";
    }

    int cost = 0;
    int limitBonus = 0;

    switch (innType) {
      case 0:
        cost = 50;
        limitBonus = 2;
        break;
      case 1:
        cost = 200;
        limitBonus = 5;
        break;
      case 2:
        cost = 1000;
        limitBonus = 12;
        break;
      default:
        return "そんなメニューはないぜ";
    }

    if (_player.coins < cost) return "金貨が足りないぜ";

    _player.coins -= cost;
    _player.nextDayTaskLimitOffset = limitBonus;
    _player.lastRestDate = now;
    _notifyAndSave();
    return null;
  }

  Future<void> setKnowledgeQuestEnabled(bool enabled) async {
    _knowledgeQuestEnabled = enabled;
    var box = await Hive.openBox('settingsBox');
    await box.put('knowledgeQuestEnabled', enabled);
    notifyListeners();
  }

  Future<void> setFontSizeScale(double scale) async {
    _fontSizeScale = scale;
    var box = await Hive.openBox('settingsBox');
    await box.put('fontSizeScale', scale);
    notifyListeners();
  }

  Future<void> loadData() async {
    _player = await _playerRepository.loadPlayer();
    _tasks = await _taskRepository.loadTasks();
    var box = await Hive.openBox('tutorialBox');
    _tutorialStep = box.get('step', defaultValue: 0);
    _hasSeenConcept = box.get('hasSeenConcept', defaultValue: false);
    var settingsBox = await Hive.openBox('settingsBox');
    final saved = settingsBox.get('fontSizeScale', defaultValue: 1.2) as double;
    _fontSizeScale = saved > 1.2 ? 1.2 : saved;

    // クイズ機能 ON/OFF
    _knowledgeQuestEnabled = settingsBox.get('knowledgeQuestEnabled', defaultValue: true) as bool;

    // RISK-I-01: 疲労MAXフラグをアプリ再起動後も維持（日付ベース）
    final fatiguePopupDate = settingsBox.get('fatiguePopupDate') as String?;
    if (fatiguePopupDate != null) {
      final d = DateTime.tryParse(fatiguePopupDate);
      if (d != null && _isSameDay(d, DateTime.now())) {
        _hasShownFatiguePopupToday = true;
      }
    }

    _isLoaded = true;
    _checkAndResetMissions(isLogin: true);
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

  void clearPendingLoginBonus() {
    pendingLoginBonusAmount = null;
    notifyListeners();
  }

  void clearPendingStreakReward() {
    pendingStreakReward = null;
    notifyListeners();
  }

  Future<void> saveData() async {
    await _playerRepository.savePlayer(_player);
    await _taskRepository.saveTasks(_tasks);
  }

  void _notifyAndSave() {
    notifyListeners();
    saveData().catchError((Object e) {
      debugPrint('GameViewModel: saveData failed: $e');
    });
  }
}
