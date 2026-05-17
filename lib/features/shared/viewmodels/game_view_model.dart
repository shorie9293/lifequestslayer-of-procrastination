import 'package:flutter/material.dart' hide DateUtils;
import 'package:uuid/uuid.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';
import 'package:rpg_todo/features/shared/data/player_repository.dart';
import 'package:rpg_todo/features/guild/data/task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/domain/services/streak_service.dart';
import 'package:rpg_todo/domain/services/title_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/domain/services/fatigue_service.dart';
import 'package:rpg_todo/core/utils/date_utils.dart';
import 'package:rpg_todo/features/shared/domain/game_themes.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';
import 'package:rpg_todo/features/shared/domain/tutorial_service.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:rpg_todo/features/kozuchi/data/kozuchi_quest_service.dart';

class GameViewModel extends ChangeNotifier with WidgetsBindingObserver {
  final IPlayerRepository _playerRepository;
  final ITaskRepository _taskRepository;
  final SettingsRepository _settingsRepository;
  final TutorialService _tutorial;
  final _completion = TaskCompletionService();
  final _completing = <String>{};
  Player _player = Player();
  List<Task> _tasks = [];
  int _tutorialStep = 0;
  bool _isLoaded = false, _sawConcept = false, _tutSkipped = false, _tutChosen = false;
  bool _fatiguePopupToday = false, _kqEnabled = true, _saving = false, _pending = false, _loadFailed = false;
  bool _showJobTutorial = false, _jobTutorialCompleted = false;
  int? pendingLoginBonusAmount, pendingStreakReward;
  IKozuchiQuestService? _kozuchiQuestService;
  KozuchiQuest? _kozuchiQuest;
  double _fontSize = 0.85;
  bool _debugMode = false;

  GameViewModel({IPlayerRepository? pr, ITaskRepository? tr, SettingsRepository? sr})
    : _playerRepository = pr ?? PlayerRepository(),
      _taskRepository = tr ?? TaskRepository(),
      _settingsRepository = sr ?? SettingsRepository(),
      _tutorial = TutorialService(sr ?? SettingsRepository()) { loadData(); }

  Player get player => _player;
  List<Task> get tasks => _tasks;
  int get tutorialStep => _tutorialStep;
  bool get isLoaded => _isLoaded;
  bool get hasSeenConcept => _sawConcept;
  bool get tutorialSkipped => _tutSkipped;
  bool get tutorialChoiceMade => _tutChosen;
  bool get isKnowledgeQuestEnabled => _kqEnabled;
  double get fontSizeScale => _fontSize;
  int get fatigueWarnThreshold => FatigueService.warnThreshold(_player);
  int get fatigueSevereThreshold => FatigueService.severeThreshold(_player);
  String get fatigueStatus => FatigueService.status(_player);
  double get fatigueProgress => FatigueService.progress(_player);
  int get fatigueLevel => FatigueService.fatigueLevel(_player);
  bool get showJobTutorial => _showJobTutorial;
  bool get jobTutorialCompleted => _jobTutorialCompleted;
  bool get isDebugMode => _debugMode;
  IKozuchiQuestService? get kozuchiQuestService => _kozuchiQuestService;
  set kozuchiQuestService(IKozuchiQuestService? service) {
    _kozuchiQuestService = service;
  }
  KozuchiQuest? get kozuchiQuest => _kozuchiQuest;
  static const int dailyMissionGoal = 3;
  static const int weeklyMissionGoal = 1;
  int get dailyMissionProgress => _player.dailyTasksCompleted.clamp(0, dailyMissionGoal);
  bool get isDailyMissionComplete => _player.dailyTasksCompleted >= dailyMissionGoal;
  int get weeklyMissionProgress => _player.weeklySRankCompleted.clamp(0, weeklyMissionGoal);
  bool get isWeeklyMissionComplete => _player.weeklySRankCompleted >= weeklyMissionGoal;
  int get streakDays => _player.streakDays;
  int get dailyEstimatedMinutes => activeTasks.fold(0, (s, t) => s + (t.targetTimeMinutes ?? 0));
  int get guildEstimatedMinutes => guildTasks.fold(0, (s, t) => s + (t.targetTimeMinutes ?? 0));
  List<({TitleDefinition def, int progress, bool isUnlocked})> get titleProgressList => TitleService.getTitleProgressList(_player);
  /// 過去の完了タスクから推定時間を計算（神託5: 魔導書解析）
  /// 同ランクの完了タスク + 類似タイトルの完了タスク の targetTimeMinutes 平均を返す
  int? estimateMinutes(String title, QuestRank rank) {
    final completed = _tasks.where((t) => t.isCompleted && t.targetTimeMinutes != null).toList();
    if (completed.isEmpty) return null;

    // 同ランクの完了タスク
    final sameRank = completed.where((t) => t.rank == rank).toList();
    // 類似タイトル（タイトルに含まれる単語が一致）の完了タスク（異ランクも含む）
    final titleWords = title.split(RegExp(r'[\s　,、。．.]+')).where((w) => w.isNotEmpty).toList();
    final similarTitle = completed.where((t) =>
        t.id != '' && titleWords.any((w) => w.length >= 2 && t.title.contains(w))).toList();

    // 合併（重複除去）
    final relevant = <Task>{...sameRank, ...similarTitle}.toList();
    if (relevant.isEmpty) return null;

    final total = relevant.fold<int>(0, (sum, t) => sum + t.targetTimeMinutes!);
    return total ~/ relevant.length;
  }

  List<Task> get recurringTasks => _tasks.where((t) => t.repeatInterval != RepeatInterval.none).toList();
  List<Task> get guildTasks => _tasks.where((t) => t.status == TaskStatus.inGuild && !t.isCompleted).toList();
  ThemeData get currentTheme => GameThemes.forJob(_player.currentJob);
  List<Task> get activeTasks => _tasks.where((t) => t.status == TaskStatus.active && !t.isCompleted && _visible(t)).toList();

  bool _visible(Task t) {
    if (!_player.canUseSkill(Job.cleric) || t.repeatInterval == RepeatInterval.none) return true;
    final now = DateTime.now();
    if (t.repeatInterval == RepeatInterval.weekly && t.repeatWeekdays.isNotEmpty && !t.repeatWeekdays.contains(now.weekday)) return false;
    if (t.lastCompletedAt != null) { final l = t.lastCompletedAt!; if (now.year == l.year && now.month == l.month && now.day == l.day) return false; }
    return true;
  }

  void addTask(String title, {QuestRank rank = QuestRank.B, RepeatInterval repeatInterval = RepeatInterval.none, List<int>? repeatWeekdays, List<SubTask>? subTasks, int? targetTimeMinutes, DateTime? deadline}) {
    _tasks.add(Task(id: const Uuid().v4(), title: title, rank: rank, repeatInterval: repeatInterval, repeatWeekdays: repeatWeekdays, subTasks: subTasks, targetTimeMinutes: targetTimeMinutes, deadline: deadline));
    if (_tutorialStep == 0) completeTutorialStep(0);
    _save();
  }

  void addTasks(List<String> titles, QuestRank rank) {
    for (final title in titles) {
      _tasks.add(Task(id: const Uuid().v4(), title: title, rank: rank));
    }
    if (_tutorialStep == 0) completeTutorialStep(0);
    _save();
  }

  void editTask(String id, String title, {QuestRank rank = QuestRank.B, RepeatInterval repeatInterval = RepeatInterval.none, List<int>? repeatWeekdays, List<SubTask>? subTasks, int? targetTimeMinutes, DateTime? deadline}) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _tasks[i]..title = title..rank = rank..repeatInterval = repeatInterval..repeatWeekdays = repeatWeekdays ?? []..subTasks = subTasks ?? []..targetTimeMinutes = targetTimeMinutes..deadline = deadline;
    _save();
  }

  String? acceptTask(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return "クエストが見つかりません";
    final t = _tasks[i];
    if (!_debugMode && !_player.canAcceptQuest(t.rank, activeTasks.where((x) => x.rank == t.rank).length)) return "${t.rank.name}ランクのキャパシティオーバー！";
    _tasks[i].status = TaskStatus.active;
    _tasks[i].activeAt = DateTime.now();
    if (_tutorialStep == 1) completeTutorialStep(1);
    _save();
    return null;
  }

  void deleteTask(String id) { _tasks.removeWhere((t) => t.id == id); _save(); }
  void cancelTask(String id) { final i = _tasks.indexWhere((t) => t.id == id); if (i != -1) { _tasks[i].status = TaskStatus.inGuild; _save(); } }

  /// デバッグモード：パスワード「11111111」で解除
  bool tryEnableDebugMode(String password) {
    if (password == '11111111') {
      _debugMode = true;
      _settingsRepository.setDebugModeEnabled(true);
      notifyListeners();
      return true;
    }
    return false;
  }
  void toggleSubTask(String id, int idx) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i != -1 && idx >= 0 && idx < _tasks[i].subTasks.length) { _tasks[i].subTasks[idx].isCompleted = !_tasks[i].subTasks[idx].isCompleted; _save(); }
  }

  void changeJob(Job j) { _player.currentJob = j; _save(); }
  void toggleSkill(Job j) { if (!_debugMode && !_player.isMastered(j)) return; if (_player.activeSkills.contains(j)) { _player.activeSkills.remove(j); } else { _player.activeSkills.add(j); } _save(); }

  Map<String, dynamic>? completeTask(String id) {
    if (_completing.contains(id)) return null;
    _completing.add(id);
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) { _completing.remove(id); return null; }
    final r = _completion.complete(task: _tasks[i], player: _player, hasShownFatiguePopupToday: _fatiguePopupToday, knowledgeQuestEnabled: _kqEnabled);
    if (r == null) { _completing.remove(id); return null; }
    if (_tutorialStep == 2) completeTutorialStep(2);
    _checkMissions();
    if (r.shouldResetFatiguePopup) { _fatiguePopupToday = true; _settingsRepository.saveFatiguePopupDate(DateTime.now()); }
    // 職業チュートリアル発動条件: 冒険者Lv10到達かつ未完了
    if (r.leveledUp &&
        _player.currentJob == Job.adventurer &&
        (_player.jobLevels[Job.adventurer] ?? 1) >= 10 &&
        !_jobTutorialCompleted) {
      _showJobTutorial = true;
    }
    _save();
    _completing.remove(id);
    return {'leveledUp': r.leveledUp, 'coinsGained': r.coinsGained, 'bonusMessages': r.bonusMessages, 'showFatiguePopup': r.showFatiguePopup, 'quizQuestion': r.quizQuestion, 'baseExp': r.expGain};
  }

  void awardKnowledgeBonus(int pct, int base) { final b = QuizService.calcBonusExp(pct, base); if (b > 0) { _player.addExp(b); _save(); } }
  void addGems(int a) { _player.gems += a; _save(); }
  bool spendGems(int a) { if (_debugMode) return true; if (_player.gems < a) return false; _player.gems -= a; _save(); return true; }
  bool exchangeGemsForCoins(int a) { if (_debugMode) { _player.coins += a * 100; _save(); return true; } if (!spendGems(a)) return false; _player.coins += a * 100; _save(); return true; }
  bool resetFatigueWithGems() { if (_debugMode) { _player.dailyTasksCompleted = 0; _save(); return true; } if (!spendGems(50)) return false; _player.dailyTasksCompleted = 0; _save(); return true; }
  void buyShopItem(String id, int price) { if (_debugMode || (_player.coins >= price && !_player.homeItems.contains(id))) { if (!_debugMode) _player.coins -= price; _player.homeItems.add(id); _save(); } }
  void _checkMissions({bool login = false}) {
    final now = DateTime.now(); bool changed = false;
    if (_player.lastMissionResetDate == null || !DateUtils.isSameDay(_player.lastMissionResetDate!, now)) {
      _player.dailyTasksCompleted = 0; _player.todayTaskLimitOffset = _player.nextDayTaskLimitOffset; _player.nextDayTaskLimitOffset = 0;
      _player.lastMissionResetDate = now; _fatiguePopupToday = false; _settingsRepository.deleteFatiguePopupDate(); changed = true;
    }
    if (_player.lastMissionResetDate != null && DateUtils.isDifferentWeek(_player.lastMissionResetDate!, now)) { _player.weeklySRankCompleted = 0; }
    if (!login) return;
    final reward = StreakService.checkAndUpdateStreak(_player, now);
    if (changed) { _player.coins += 50; pendingLoginBonusAmount = 50; _save(); }
    if (reward > 0) { pendingStreakReward = reward; _save(); }
  }

  void equipTitle(String t) { if (_player.titles.contains(t) || t.isEmpty) { _player.equippedTitle = t.isEmpty ? null : t; _save(); } }
  void equipSkin(String s) { if (_player.homeItems.contains(s) || s.isEmpty) { _player.equippedSkin = s.isEmpty ? null : s; _save(); } }
  String? restAtInn(int t) {
    if (_debugMode) {
      _player.nextDayTaskLimitOffset = t == 2 ? 12 : t == 1 ? 5 : 2;
      _player.lastRestDate = DateTime.now();
      _save();
      return null;
    }
    final r = FatigueService.restAtInn(_player, t, DateTime.now());
    if (r == null) _save();
    return r;
  }
  Future<void> setKnowledgeQuestEnabled(bool v) async { _kqEnabled = v; await _settingsRepository.setKnowledgeQuestEnabled(v); notifyListeners(); }
  Future<void> setFontSizeScale(double v) async { _fontSize = v; await _settingsRepository.setFontSizeScale(v); notifyListeners(); }

  Future<void> completeTutorialStep(int step) async { final n = await _tutorial.advanceStep(_tutorialStep, step); if (n != null) { _tutorialStep = n; notifyListeners(); } }
  Future<void> markConceptAsSeen() async { if (await _tutorial.markSeen(_sawConcept)) { _sawConcept = true; notifyListeners(); } }
  Future<void> markJobTutorialSeen() async {
    if (await _tutorial.markJobTutorialSeen(_jobTutorialCompleted)) {
      _jobTutorialCompleted = true;
      _showJobTutorial = false;
      notifyListeners();
    }
  }
  void dismissJobTutorial() { _showJobTutorial = false; notifyListeners(); }
  Future<void> skipTutorial() async { await _tutorial.persistSkip(); _tutorialStep = 3; _tutSkipped = true; _sawConcept = true; _tutChosen = true; notifyListeners(); }
  Future<void> markTutorialChoiceMade() async { await _tutorial.persistChoiceMade(); _tutChosen = true; notifyListeners(); }
  Future<void> resetTutorial() async { await _tutorial.resetAll(); _tutorialStep = 0; _sawConcept = false; _tutSkipped = false; _tutChosen = false; notifyListeners(); }
  void clearPendingLoginBonus() { pendingLoginBonusAmount = null; notifyListeners(); }
  void clearPendingStreakReward() { pendingStreakReward = null; notifyListeners(); }

  Future<void> refreshKozuchiQuest() async {
    if (_kozuchiQuestService == null) {
      _kozuchiQuest = null;
      notifyListeners();
      return;
    }
    try {
      _kozuchiQuest = await _kozuchiQuestService!.fetchActiveQuest();
    } catch (e) {
      debugPrint('[Kozuchi] refresh error: $e');
      _kozuchiQuest = null;
    }
    notifyListeners();
  }

  Future<void> saveData() async { await _playerRepository.savePlayer(_player); await _taskRepository.saveTasks(_tasks); }

  // ── デバッグモード操作 ─────────────────────────────────────

  /// コインを直接設定（デバッグモードのみ）
  void debugSetCoins(int amount) {
    if (!_debugMode) return;
    _player.coins = amount.clamp(0, 99999999);
    _save();
  }

  /// Gemを直接設定（デバッグモードのみ）
  void debugSetGems(int amount) {
    if (!_debugMode) return;
    _player.gems = amount.clamp(0, 99999);
    _save();
  }

  /// EXPを追加（デバッグモードのみ）
  void debugAddExp(int amount) {
    if (!_debugMode) return;
    _player.addExp(amount);
    _save();
  }

  /// 全アクティブタスクを即時完了（デバッグモードのみ）
  void debugCompleteAllActive() {
    if (!_debugMode) return;
    for (final task in activeTasks.toList()) {
      completeTask(task.id);
    }
  }

  /// テスト用タスクを3件追加（デバッグモードのみ）
  void debugAddTestTasks() {
    if (!_debugMode) return;
    addTask('デバッグ：魔物討伐（Slimeを3匹倒せ）', rank: QuestRank.B, targetTimeMinutes: 15);
    addTask('デバッグ：素材収集（薬草を10個集めよ）', rank: QuestRank.B, targetTimeMinutes: 30);
    addTask('デバッグ：古代遺跡の調査', rank: QuestRank.A, targetTimeMinutes: 60);
  }

  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) saveData().catchError((e) => debugPrint('GameViewModel: lifecycle save failed: $e'));
  }

  @override void dispose() { WidgetsBinding.instance.removeObserver(this); _playerRepository.close(); _taskRepository.close(); super.dispose(); }

  void _save() {
    notifyListeners();
    if (_saving) { _pending = true; return; }
    _saving = true; _pending = false;
    saveData().then((_) {
      _saving = false;
      if (_pending) { _pending = false; _saving = true; saveData().then((_) { _saving = false; }).catchError((e) { _saving = false; debugPrint('GameViewModel: saveData retry failed: $e'); }); }
    }).catchError((e) { _saving = false; _pending = false; debugPrint('GameViewModel: saveData failed: $e'); });
  }

  Future<void> _load<T>(Future<T> Function() l, void Function(T) s, {String label = ''}) async {
    try { s(await l()); } catch (e, st) { if (label.isNotEmpty) debugPrint('[VM] $label load error: $e\n$st'); }
  }

  /// 神託1: 今日が期限のギルドタスクを自動配備する
  /// loadData() の末尾で呼ばれ、期限当日のタスクをランク優先順（S > A > B）で戦場に送り出す
  void _autoDeployTodaysTasks() {
    // 1) ギルドタスクのうち、期限が今日のものを抽出
    final today = DateTime.now();
    final todaysTasks = guildTasks.where((t) =>
      t.deadline != null && DateUtils.isSameDay(t.deadline!, today)
    ).toList();

    if (todaysTasks.isEmpty) {
      debugPrint('[神託] 今日が期限のギルドタスクはありません');
      return;
    }

    // 2) ランク優先順でソート（S > A > B）
    const rankOrder = {QuestRank.S: 0, QuestRank.A: 1, QuestRank.B: 2};
    todaysTasks.sort((a, b) => rankOrder[a.rank]!.compareTo(rankOrder[b.rank]!));

    // 3) acceptTask() で自動配備（acceptTask内でキャパシティチェック済み）
    int deployedCount = 0;
    for (final task in todaysTasks) {
      final result = acceptTask(task.id);
      if (result == null) {
        deployedCount++;
      }
    }

    // 4) 結果をログ出力
    debugPrint('[神託] 自動配備完了: $deployedCount 件のタスクを戦場に送り出しました');
  }

  Future<void> loadData() async {
    _loadFailed = false;
    try { _player = await _playerRepository.loadPlayer(); } catch (e, s) { debugPrint('[VM] player load error: $e\n$s'); _loadFailed = true; }
    try { _tasks = await _taskRepository.loadTasks(); } catch (e, s) { debugPrint('[VM] tasks load error: $e\n$s'); _tasks = []; _loadFailed = true; }
    await _load(_settingsRepository.getTutorialStep, (v) => _tutorialStep = v);
    await _load(_settingsRepository.getHasSeenConcept, (v) => _sawConcept = v);
    await _load(_settingsRepository.getFontSizeScale, (v) => _fontSize = v, label: 'fontSizeScale');
    await _load(_settingsRepository.getKnowledgeQuestEnabled, (v) => _kqEnabled = v, label: 'knowledgeQuest');
    await _load(_settingsRepository.getTutorialSkipped, (v) => _tutSkipped = v, label: 'tutorialSkipped');
    await _load(_settingsRepository.getTutorialChoiceMade, (v) => _tutChosen = v, label: 'tutorialChoiceMade');
    await _load(_settingsRepository.getJobTutorialCompleted, (v) => _jobTutorialCompleted = v, label: 'jobTutorialCompleted');
    await _load(_settingsRepository.getDebugModeEnabled, (v) => _debugMode = v, label: 'debugMode');
    if (_fontSize != 0.85) { _fontSize = 0.85; try { await _settingsRepository.setFontSizeScale(0.85); } catch (_) {} }
    try { final d = await _settingsRepository.getFatiguePopupDate(); if (d != null && DateUtils.isSameDay(d, DateTime.now())) { _fatiguePopupToday = true; } } catch (e, s) { debugPrint('[VM] fatiguePopup load error: $e\n$s'); }
    if (await _tutorial.repairSeenConcept(_tutorialStep, _sawConcept)) { _sawConcept = true; }
    try { if (!_loadFailed) _checkMissions(login: true); } catch (e, s) { debugPrint('[VM] checkAndResetMissions error: $e\n$s'); }
    _isLoaded = true;
    notifyListeners();
    try { WidgetsBinding.instance.addObserver(this); } catch (_) {}
    // 神託1: 今日期限のタスクを自動配備
    try { _autoDeployTodaysTasks(); } catch (e, s) { debugPrint('[VM] autoDeployTodaysTasks error: $e\n$s'); }
  }
}
