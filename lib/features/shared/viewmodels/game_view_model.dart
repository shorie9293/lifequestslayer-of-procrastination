import 'package:flutter/material.dart' hide DateUtils;
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';
import 'package:rpg_todo/domain/services/title_service.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'package:rpg_todo/features/shared/data/player_repository.dart';
import 'package:rpg_todo/features/guild/data/task_repository.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/data/settings_repository.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:rpg_todo/features/kozuchi/data/kozuchi_quest_service.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';

/// 後方互換用のファサードViewModel。
/// 新VM（PlayerVM/TaskVM/ShopVM/SettingsVM/ThemeVM）に委譲する。
class GameViewModel extends ChangeNotifier with WidgetsBindingObserver {
  late final PlayerViewModel _playerVM;
  late final TaskViewModel _taskVM;
  late final ShopViewModel _shopVM;
  late final SettingsViewModel _settingsVM;
  late final ThemeViewModel _themeVM;
  final IPlayerRepository _playerRepo;
  final ITaskRepository _taskRepo;
  final SettingsRepository _settingsRepo;

  GameViewModel({IPlayerRepository? pr, ITaskRepository? tr, SettingsRepository? sr})
    : _playerRepo = pr ?? PlayerRepository(),
      _taskRepo = tr ?? TaskRepository(),
      _settingsRepo = sr ?? SettingsRepository() {
    _playerVM = PlayerViewModel(_playerRepo);
    _taskVM = TaskViewModel(_taskRepo, _playerVM);
    _shopVM = ShopViewModel(_playerVM);
    _settingsVM = SettingsViewModel(_settingsRepo);
    _themeVM = ThemeViewModel(_playerVM);
    loadData();
  }

  // ── 委譲プロパティ ──
  Player get player => _playerVM.player;
  List<Task> get tasks => _taskVM.tasks;
  int get tutorialStep => _settingsVM.tutorialStep;
  bool get isLoaded => _playerVM.isLoaded && _taskVM.isLoaded;
  bool get hasSeenConcept => _settingsVM.hasSeenConcept;
  bool get tutorialSkipped => _settingsVM.tutorialSkipped;
  bool get tutorialChoiceMade => _settingsVM.tutorialChoiceMade;
  bool get isKnowledgeQuestEnabled => _settingsVM.isKnowledgeQuestEnabled;
  double get fontSizeScale => _settingsVM.fontSizeScale;
  int get fatigueWarnThreshold => _playerVM.fatigueWarnThreshold;
  int get fatigueSevereThreshold => _playerVM.fatigueSevereThreshold;
  String get fatigueStatus => _playerVM.fatigueStatus;
  double get fatigueProgress => _playerVM.fatigueProgress;
  int get fatigueLevel => _playerVM.fatigueLevel;
  bool get showJobTutorial => _settingsVM.showJobTutorial;
  bool get jobTutorialCompleted => _settingsVM.jobTutorialCompleted;
  bool get isDebugMode => _settingsVM.isDebugMode;
  IKozuchiQuestService? get kozuchiQuestService => _taskVM.kozuchiQuestService;
  set kozuchiQuestService(IKozuchiQuestService? service) => _taskVM.kozuchiQuestService = service;
  KozuchiQuest? get kozuchiQuest => _taskVM.kozuchiQuest;
  int get dailyMissionProgress => _playerVM.dailyMissionProgress;
  bool get isDailyMissionComplete => _playerVM.isDailyMissionComplete;
  int get weeklyMissionProgress => _playerVM.weeklyMissionProgress;
  bool get isWeeklyMissionComplete => _playerVM.isWeeklyMissionComplete;
  int get streakDays => _playerVM.streakDays;
  int get dailyEstimatedMinutes => _taskVM.dailyEstimatedMinutes;
  TownScale get townScale => _playerVM.townScale;
  int get guildEstimatedMinutes => _taskVM.guildEstimatedMinutes;
  List<({TitleDefinition def, int progress, bool isUnlocked})> get titleProgressList => _playerVM.titleProgressList;
  List<Task> get urgentGuildTasks => _taskVM.urgentGuildTasks;
  List<Task> get recurringTasks => _taskVM.recurringTasks;
  List<Task> get guildTasks => _taskVM.guildTasks;
  ThemeData get currentTheme => _themeVM.currentTheme;
  List<Task> get activeTasks => _taskVM.activeTasks;
  static const int dailyMissionGoal = 3;
  static const int weeklyMissionGoal = 1;
  int? pendingLoginBonusAmount;
  int? pendingStreakReward;

  // ── 委譲メソッド ──
  int? estimateMinutes(String title, QuestRank rank) => _taskVM.estimateMinutes(title, rank);

  void addTask(String title, {QuestRank rank = QuestRank.B, RepeatInterval repeatInterval = RepeatInterval.none, List<int>? repeatWeekdays, List<SubTask>? subTasks, int? targetTimeMinutes, DateTime? deadline}) {
    _taskVM.addTask(title, rank: rank, repeatInterval: repeatInterval, repeatWeekdays: repeatWeekdays, subTasks: subTasks, targetTimeMinutes: targetTimeMinutes, deadline: deadline);
    if (_settingsVM.tutorialStep == 0) completeTutorialStep(0);
    _save();
  }

  void addTasks(List<String> titles, QuestRank rank) {
    _taskVM.addTasks(titles, rank);
    if (_settingsVM.tutorialStep == 0) completeTutorialStep(0);
    _save();
  }

  void editTask(String id, String title, {QuestRank rank = QuestRank.B, RepeatInterval repeatInterval = RepeatInterval.none, List<int>? repeatWeekdays, List<SubTask>? subTasks, int? targetTimeMinutes, DateTime? deadline}) {
    _taskVM.editTask(id, title, rank: rank, repeatInterval: repeatInterval, repeatWeekdays: repeatWeekdays, subTasks: subTasks, targetTimeMinutes: targetTimeMinutes, deadline: deadline);
    _save();
  }

  String? acceptTask(String id) {
    final r = _taskVM.acceptTask(id, debugMode: _settingsVM.isDebugMode);
    if (r == null && _settingsVM.tutorialStep == 1) completeTutorialStep(1);
    if (r == null) _save();
    return r;
  }

  void deleteTask(String id) { _taskVM.deleteTask(id); _save(); }
  void cancelTask(String id) { _taskVM.cancelTask(id); _save(); }

  bool tryEnableDebugMode(String password) => _settingsVM.tryEnableDebugMode(password);

  void toggleSubTask(String id, int idx) { _taskVM.toggleSubTask(id, idx); _save(); }

  void changeJob(Job j) { _playerVM.changeJob(j, debugMode: _settingsVM.isDebugMode); _save(); }
  void toggleSkill(Job j) { _playerVM.toggleSkill(j, debugMode: _settingsVM.isDebugMode); _save(); }

  Map<String, dynamic>? completeTask(String id) {
    final result = _taskVM.completeTask(id,
        knowledgeQuestEnabled: _settingsVM.isKnowledgeQuestEnabled,
        debugMode: _settingsVM.isDebugMode);
    if (result != null) {
      if (_settingsVM.tutorialStep == 2) completeTutorialStep(2);
      _playerVM.checkAndResetMissions(DateTime.now());
      if (result['leveledUp'] == true &&
          _playerVM.player.currentJob == Job.adventurer &&
          (_playerVM.player.jobLevels[Job.adventurer] ?? 1) >= 10 &&
          !_settingsVM.jobTutorialCompleted) {
        _settingsVM.setShowJobTutorial(true);
      }
      _save();
    }
    return result;
  }

  void awardKnowledgeBonus(int pct, int base) => _taskVM.awardKnowledgeBonus(pct, base);

  /// 刻の番人（期限切れボス）討伐成功。討伐回数を増やし称号をチェックする。
  void defeatTimeWarden() {
    _playerVM.player.timesWardenDefeated++;
    final messages = <String>[];
    TitleService.checkTitles(_playerVM.player, messages);
    _save();
  }

  /// 刻の番人クイズ誤答時のペナルティ。EXPとコインを減らす。
  void applyWrongAnswerPenalty(int expPenalty, int coinsPenalty) {
    if (expPenalty > 0) {
      // 現在職のEXPからペナルティ分だけ減らす（0未満にはしない）
      final currentExp = _playerVM.player.currentExp;
      _playerVM.player.jobExps[_playerVM.player.currentJob] =
          (currentExp - expPenalty).clamp(0, 99999999);
    }
    if (coinsPenalty > 0) {
      _playerVM.player.coins =
          (_playerVM.player.coins - coinsPenalty).clamp(0, 99999999);
    }
    _save();
  }
  void addGems(int a) { _playerVM.addGems(a); _save(); }
  bool spendGems(int a) {
    final r = _shopVM.spendGems(a, debugMode: _settingsVM.isDebugMode);
    if (r) _save();
    return r;
  }
  bool exchangeGemsForCoins(int a) {
    final r = _shopVM.exchangeGemsForCoins(a, debugMode: _settingsVM.isDebugMode);
    if (r) _save();
    return r;
  }
  bool resetFatigueWithGems() {
    final r = _shopVM.resetFatigueWithGems(debugMode: _settingsVM.isDebugMode);
    if (r) _save();
    return r;
  }
  void buyShopItem(String id, int price) {
    _shopVM.buyShopItem(id, price, debugMode: _settingsVM.isDebugMode);
    _save();
  }

  void equipTitle(String t) { _playerVM.equipTitle(t); _save(); }
  void equipSkin(String s) { _playerVM.equipSkin(s); _save(); }
  void equipCharacterSkin(SkinSlot slot, String skinId) { _playerVM.equipCharacterSkin(slot, skinId); _save(); }

  String? restAtInn(int t) {
    final r = _shopVM.restAtInn(t, debugMode: _settingsVM.isDebugMode);
    if (r == null) _save();
    return r;
  }

  Future<void> setKnowledgeQuestEnabled(bool v) => _settingsVM.setKnowledgeQuestEnabled(v);
  Future<void> setFontSizeScale(double v) => _settingsVM.setFontSizeScale(v);
  Future<void> completeTutorialStep(int step) => _settingsVM.completeTutorialStep(step);
  Future<void> markConceptAsSeen() => _settingsVM.markConceptAsSeen();
  Future<void> markJobTutorialSeen() => _settingsVM.markJobTutorialSeen();
  void dismissJobTutorial() => _settingsVM.dismissJobTutorial();
  Future<void> skipTutorial() => _settingsVM.skipTutorial();
  Future<void> markTutorialChoiceMade() => _settingsVM.markTutorialChoiceMade();
  Future<void> resetTutorial() => _settingsVM.resetTutorial();
  void clearPendingLoginBonus() { pendingLoginBonusAmount = null; notifyListeners(); }
  void clearPendingStreakReward() { pendingStreakReward = null; notifyListeners(); }
  Future<void> refreshKozuchiQuest() => _taskVM.refreshKozuchiQuest();

  // ── デバッグ ──
  void debugSetCoins(int amount) { if (_settingsVM.isDebugMode) { _playerVM.debugSetCoins(amount); _save(); } }
  void debugSetGems(int amount) { if (_settingsVM.isDebugMode) { _playerVM.debugSetGems(amount); _save(); } }
  void debugAddExp(int amount) { if (_settingsVM.isDebugMode) { _playerVM.addExp(amount); _save(); } }
  void debugCompleteAllActive() { if (_settingsVM.isDebugMode) { for (final t in _taskVM.activeTasks) { completeTask(t.id); } } }
  void debugAddTestTasks() { if (_settingsVM.isDebugMode) { addTask('デバッグ：魔物討伐（Slimeを3匹倒せ）', rank: QuestRank.B, targetTimeMinutes: 15); addTask('デバッグ：素材収集（薬草を10個集めよ）', rank: QuestRank.B, targetTimeMinutes: 30); addTask('デバッグ：古代遺跡の調査', rank: QuestRank.A, targetTimeMinutes: 60); } }

  // ── ライフサイクル ──
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _playerVM.save().catchError((e) {
        debugPrint('GameViewModel: lifecycle player save failed: $e');
        _playerVM.onSaveError?.call();
      });
      _taskVM.save().catchError((e) {
        debugPrint('GameViewModel: lifecycle task save failed: $e');
        _taskVM.onSaveError?.call();
      });
    }
  }

  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerVM.closeRepository();
    _taskVM.closeRepository();
    _playerVM.dispose();
    _taskVM.dispose();
    _settingsVM.dispose();
    _themeVM.dispose();
    _shopVM.dispose();
    super.dispose();
  }

  bool _isSaving = false;
  bool _pending = false;

  Future<void> _save() async {
    notifyListeners();
    if (_isSaving) {
      _pending = true;
      return;
    }
    _isSaving = true;
    _pending = false;
    try {
      await Future.wait([_playerVM.save(), _taskVM.save()]);
    } catch (e) {
      debugPrint('GameViewModel: save failed: $e');
      _playerVM.onSaveError?.call();
      _taskVM.onSaveError?.call();
    } finally {
      _isSaving = false;
      if (_pending) {
        _pending = false;
        // 保留中のデータ（後続のaddTask等による変更）を保存
        try {
          await Future.wait([_playerVM.save(), _taskVM.save()]);
        } catch (e) {
          debugPrint('GameViewModel: retry save failed: $e');
          _playerVM.onSaveError?.call();
          _taskVM.onSaveError?.call();
        }
      }
    }
  }

  Future<void> loadData() async {
    await _playerVM.load();
    await _taskVM.load();
    await _settingsVM.load();
    try { _playerVM.checkAndResetMissions(DateTime.now(), login: true); } catch (e, s) { debugPrint('[VM] missions error: $e\n$s'); }
    try { WidgetsBinding.instance.addObserver(this); } catch (_) {}
    try { _taskVM.autoDeployTodaysTasks(); } catch (e, s) { debugPrint('[VM] autoDeploy error: $e\n$s'); }
    notifyListeners();
  }
}
