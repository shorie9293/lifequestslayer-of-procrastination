import 'dart:math';
import 'package:flutter/material.dart' hide DateUtils;
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/player.dart';
import '../models/title_definition.dart';
import '../data/quiz_data.dart';
import '../repositories/player_repository.dart';
import '../repositories/task_repository.dart';
import '../services/settings_repository.dart';
import '../services/streak_service.dart';
import '../services/title_service.dart';
import '../services/quiz_service.dart';
import '../services/fatigue_service.dart';
import '../utils/date_utils.dart';

class GameViewModel extends ChangeNotifier {
  final PlayerRepository _playerRepository;
  final TaskRepository _taskRepository;
  final SettingsRepository _settingsRepository;

  /// 乱数生成器（インスタンスを再利用してパフォーマンス向上）
  final _rng = Random();

  Player _player = Player();
  List<Task> _tasks = [];
  int _tutorialStep = 0;
  bool _isLoaded = false;
  bool _hasSeenConcept = false;
  int? pendingLoginBonusAmount;
  int? pendingStreakReward;
  double _fontSizeScale = 0.85;

  // v1.2: 疲労MAXダイアログは1日1回のみ（settingsBoxに日付を永続化）
  bool _hasShownFatiguePopupToday = false;

  // v1.2: 知識クエスト機能のON/OFF（設定から切替可能）
  bool _knowledgeQuestEnabled = true;
  bool get isKnowledgeQuestEnabled => _knowledgeQuestEnabled;

  // v1.3: 保存中の二重呼出し防止フラグ
  bool _isSaving = false;
  // v1.3: 保存保留フラグ（保存中に変更があった場合、終了後に再保存）
  bool _savePending = false;
  // v1.3: タスク完了処理中の二重実行防止
  final Set<String> _completingTaskIds = {};

  GameViewModel({
    PlayerRepository? playerRepository,
    TaskRepository? taskRepository,
    SettingsRepository? settingsRepository,
  })  : _playerRepository = playerRepository ?? PlayerRepository(),
        _taskRepository = taskRepository ?? TaskRepository(),
        _settingsRepository = settingsRepository ?? SettingsRepository() {
    loadData();
  }

  Player get player => _player;
  List<Task> get tasks => _tasks;
  int get tutorialStep => _tutorialStep;
  bool get isLoaded => _isLoaded;
  bool get hasSeenConcept => _hasSeenConcept;
  double get fontSizeScale => _fontSizeScale;

  // v1.4: チュートリアルスキップフラグ
  bool _tutorialSkipped = false;
  bool get tutorialSkipped => _tutorialSkipped;

  // v1.4: チュートリアル選択済みフラグ（スキップ/学ぶの選択後はtrue）
  bool _tutorialChoiceMade = false;
  bool get tutorialChoiceMade => _tutorialChoiceMade;

  int get fatigueWarnThreshold => FatigueService.warnThreshold(_player);
  int get fatigueSevereThreshold => FatigueService.severeThreshold(_player);

  String get fatigueStatus => FatigueService.status(_player);

  double get fatigueProgress => FatigueService.progress(_player);

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
  List<({TitleDefinition def, int progress, bool isUnlocked})> get titleProgressList {
    return TitleService.getTitleProgressList(_player);
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
    if (index == -1) return "クエストが見つかりません";

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
  ///     `leveledUp` (bool)
  ///     `coinsGained` (int)
  ///     `bonusMessages` (List of String)
  ///     `showFatiguePopup` (bool) 疲労MAXに到達した瞬間のみ true
  ///     `quizQuestion` (QuizQuestion?) 抽選で出題される場合
  Map<String, dynamic>? completeTask(String taskId) {
    // v1.3: 二重実行防止 — 同じタスクの処理中は即 return
    if (_completingTaskIds.contains(taskId)) return null;
    _completingTaskIds.add(taskId);

    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) {
      _completingTaskIds.remove(taskId);
      return null;
    }

    final task = _tasks[index];

    // Wizard: サブタスク完了チェック
    if (_player.canUseSkill(Job.wizard) && task.subTasks.isNotEmpty) {
      if (task.subTasks.any((s) => !s.isCompleted)) {
        _completingTaskIds.remove(taskId);
        return null;
      }
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
    double fatigueMultiplier = FatigueService.fatigueMultiplier(_player);

    if (_player.dailyTasksCompleted >= FatigueService.severeThreshold(_player)) {
      bonusMessages.add("🌙 今日の英雄は十分戦った。宿屋で休んで明日に備えよ！");
    } else if (_player.dailyTasksCompleted >= FatigueService.warnThreshold(_player)) {
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
        bonusMessages.add("⚔️ ${_player.comboCount}コンボ！ +$comboBonus EXP");
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
    bool isRare = _rng.nextDouble() < dropChance;
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

    TitleService.checkTitles(_player, bonusMessages);

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
    if (_player.dailyTasksCompleted >= FatigueService.severeThreshold(_player) && !_hasShownFatiguePopupToday) {
      _hasShownFatiguePopupToday = true;
      showFatiguePopup = true;
      _settingsRepository.saveFatiguePopupDate(DateTime.now());
    }

    // v1.2: 知識クエスト抽選
    QuizQuestion? quizQuestion;
    if (_knowledgeQuestEnabled) {
      quizQuestion = QuizService.drawQuizQuestion();
    }

    _notifyAndSave();

    // v1.3: 完了処理のガードを解除
    _completingTaskIds.remove(taskId);

    return {
      'leveledUp': leveledUp,
      'coinsGained': coinsGained,
      'bonusMessages': bonusMessages,
      'showFatiguePopup': showFatiguePopup,
      'quizQuestion': quizQuestion,
      'baseExp': expGain,
    };
  }

  /// 知識クエスト正解時のボーナスEXP付与（UI側から呼ぶ）
  void awardKnowledgeBonus(int bonusPercent, int baseExp) {
    final bonus = QuizService.calcBonusExp(bonusPercent, baseExp);
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
        !DateUtils.isSameDay(_player.lastMissionResetDate!, now)) {
      _player.dailyTasksCompleted = 0;
      _player.todayTaskLimitOffset = _player.nextDayTaskLimitOffset;
      _player.nextDayTaskLimitOffset = 0;
      _player.lastMissionResetDate = now;
      _hasShownFatiguePopupToday = false;
      _settingsRepository.deleteFatiguePopupDate();
      changedDate = true;
    }

    // ウィークリーリセット（月またぎに対応した正確な判定）
    if (_player.lastMissionResetDate != null &&
        DateUtils.isDifferentWeek(_player.lastMissionResetDate!, now)) {
      _player.weeklySRankCompleted = 0;
    }

    if (isLogin) {
      final reward = StreakService.checkAndUpdateStreak(_player, now);
      if (changedDate) {
        _player.coins += 50; // ログインボーナス
        pendingLoginBonusAmount = 50;
        _notifyAndSave();
      }
      if (reward > 0) {
        pendingStreakReward = reward;
        _notifyAndSave();
      }
    }
  }

  // --- 称号システム ---
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
    final result = FatigueService.restAtInn(_player, innType, DateTime.now());
    if (result == null) {
      _notifyAndSave();
    }
    return result;
  }

  Future<void> setKnowledgeQuestEnabled(bool enabled) async {
    _knowledgeQuestEnabled = enabled;
    await _settingsRepository.setKnowledgeQuestEnabled(enabled);
    notifyListeners();
  }

  Future<void> setFontSizeScale(double scale) async {
    _fontSizeScale = scale;
    await _settingsRepository.setFontSizeScale(scale);
    notifyListeners();
  }

  Future<void> loadData() async {
    // print() は release ビルドでも出力されるため、エラー診断に使用
    try { _player = await _playerRepository.loadPlayer(); } catch (e, s) { print('[VM] player load error: $e\n$s'); }
    try { _tasks = await _taskRepository.loadTasks(); } catch (e, s) { print('[VM] tasks load error: $e\n$s'); _tasks = []; }
    try { _tutorialStep = await _settingsRepository.getTutorialStep(); } catch (e, s) { print('[VM] tutorialStep load error: $e\n$s'); }
    try { _hasSeenConcept = await _settingsRepository.getHasSeenConcept(); } catch (e, s) { print('[VM] hasSeenConcept load error: $e\n$s'); }
    try { _fontSizeScale = await _settingsRepository.getFontSizeScale(); } catch (e, s) { print('[VM] fontSizeScale load error: $e\n$s'); }
    // 文字サイズは「小」のみ（大・中は崩れるため廃止）
    if (_fontSizeScale != 0.85) {
      _fontSizeScale = 0.85;
      try { await _settingsRepository.setFontSizeScale(0.85); } catch (_) {}
    }

    try { _knowledgeQuestEnabled = await _settingsRepository.getKnowledgeQuestEnabled(); } catch (e, s) { print('[VM] knowledgeQuest load error: $e\n$s'); }

    try { _tutorialSkipped = await _settingsRepository.getTutorialSkipped(); } catch (e, s) { print('[VM] tutorialSkipped load error: $e\n$s'); }
    try { _tutorialChoiceMade = await _settingsRepository.getTutorialChoiceMade(); } catch (e, s) { print('[VM] tutorialChoiceMade load error: $e\n$s'); }

    try {
      final fatiguePopupDate = await _settingsRepository.getFatiguePopupDate();
      if (fatiguePopupDate != null && DateUtils.isSameDay(fatiguePopupDate, DateTime.now())) {
        _hasShownFatiguePopupToday = true;
      }
    } catch (e, s) { print('[VM] fatiguePopup load error: $e\n$s'); }

    // チュートリアル完了済みユーザーの hasSeenConcept 修復
    if (_tutorialStep > 2 && !_hasSeenConcept) {
      _hasSeenConcept = true;
      try { await _settingsRepository.setHasSeenConcept(true); } catch (_) {}
    }

    try {
      _checkAndResetMissions(isLogin: true);
    } catch (e, s) {
      print('[VM] checkAndResetMissions error: $e\n$s');
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> completeTutorialStep(int step) async {
    if (_tutorialStep == step) {
      _tutorialStep++;
      await _settingsRepository.setTutorialStep(_tutorialStep);
      notifyListeners();
    }
  }

  Future<void> markConceptAsSeen() async {
    if (!_hasSeenConcept) {
      _hasSeenConcept = true;
      await _settingsRepository.setHasSeenConcept(true);
      notifyListeners();
    }
  }

  Future<void> skipTutorial() async {
    _tutorialStep = 3;
    _tutorialSkipped = true;
    _hasSeenConcept = true;
    _tutorialChoiceMade = true;
    await _settingsRepository.setTutorialStep(3);
    await _settingsRepository.setTutorialSkipped(true);
    await _settingsRepository.setHasSeenConcept(true);
    await _settingsRepository.setTutorialChoiceMade(true);
    notifyListeners();
  }

  Future<void> markTutorialChoiceMade() async {
    _tutorialChoiceMade = true;
    await _settingsRepository.setTutorialChoiceMade(true);
    notifyListeners();
  }

  Future<void> resetTutorial() async {
    _tutorialStep = 0;
    _hasSeenConcept = false;
    _tutorialSkipped = false;
    _tutorialChoiceMade = false;
    await _settingsRepository.resetTutorial();
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
    if (_isSaving) {
      _savePending = true;
      return;
    }
    _isSaving = true;
    _savePending = false;
    saveData().then((_) {
      _isSaving = false;
      if (_savePending) {
        _savePending = false;
        _isSaving = true;
        saveData().then((_) {
          _isSaving = false;
        }).catchError((Object e) {
          _isSaving = false;
          debugPrint('GameViewModel: saveData retry failed: $e');
        });
      }
    }).catchError((Object e) {
      _isSaving = false;
      _savePending = false;
      debugPrint('GameViewModel: saveData failed: $e');
    });
  }
}
