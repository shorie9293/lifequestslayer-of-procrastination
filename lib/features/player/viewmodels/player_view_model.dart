import 'package:flutter/material.dart' hide DateUtils;
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/services/fatigue_service.dart';
import 'package:rpg_todo/domain/services/streak_service.dart';
import 'package:rpg_todo/domain/services/title_service.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'package:rpg_todo/core/utils/date_utils.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';

/// プレイヤーの状態と操作を管理するViewModel
class PlayerViewModel extends ChangeNotifier {
  final IPlayerRepository _playerRepository;

  Player _player = Player();
  bool _loadFailed = false;
  bool _isLoaded = false;
  int? pendingLoginBonusAmount;
  int? pendingStreakReward;

  PlayerViewModel(this._playerRepository);

  Player get player => _player;
  bool get isLoaded => _isLoaded;
  bool get loadFailed => _loadFailed;

  // ── 便利なゲッター ──
  int get level => _player.level;
  int get coins => _player.coins;
  int get gems => _player.gems;
  Job get currentJob => _player.currentJob;
  int get dailyTasksCompleted => _player.dailyTasksCompleted;
  int get streakDays => _player.streakDays;
  int get fatigueLevel => FatigueService.fatigueLevel(_player);
  TownScale get townScale => TownScale.fromLevel(_player.level);

  int get fatigueWarnThreshold => FatigueService.warnThreshold(_player);
  int get fatigueSevereThreshold => FatigueService.severeThreshold(_player);
  String get fatigueStatus => FatigueService.status(_player);
  double get fatigueProgress => FatigueService.progress(_player);

  List<({TitleDefinition def, int progress, bool isUnlocked})> get titleProgressList =>
      TitleService.getTitleProgressList(_player);

  bool canAcceptQuest(QuestRank rank, int currentCount) =>
      _player.canAcceptQuest(rank, currentCount);
  bool canUseSkill(Job j) => _player.canUseSkill(j);
  bool isMastered(Job j) => _player.isMastered(j);

  static const int dailyMissionGoal = 3;
  static const int weeklyMissionGoal = 1;
  int get dailyMissionProgress => _player.dailyTasksCompleted.clamp(0, dailyMissionGoal);
  bool get isDailyMissionComplete => _player.dailyTasksCompleted >= dailyMissionGoal;
  int get weeklyMissionProgress => _player.weeklySRankCompleted.clamp(0, weeklyMissionGoal);
  bool get isWeeklyMissionComplete => _player.weeklySRankCompleted >= weeklyMissionGoal;

  // ── ミッションリセット ──
  void checkAndResetMissions(DateTime now, {bool login = false}) {
    bool changed = false;
    if (_player.lastMissionResetDate == null ||
        !DateUtils.isSameDay(_player.lastMissionResetDate!, now)) {
      _player.dailyTasksCompleted = 0;
      _player.todayTaskLimitOffset = _player.nextDayTaskLimitOffset;
      _player.nextDayTaskLimitOffset = 0;
      _player.lastMissionResetDate = now;
      changed = true;
    }
    if (_player.lastMissionResetDate != null &&
        DateUtils.isDifferentWeek(_player.lastMissionResetDate!, now)) {
      _player.weeklySRankCompleted = 0;
    }
    if (!login) return;
    StreakService.checkAndUpdateStreak(_player, now);
    if (changed) {
      _player.coins += 50;
      pendingLoginBonusAmount = 50;
    }
    // streak reward is set in StreakService.checkAndUpdateStreak
    // We expose it through the player; callers check streakDays
  }

  // ── 操作 ──
  void addExp(int amount) { _player.addExp(amount); notifyListeners(); }
  void addGems(int amount) { _player.gems += amount; notifyListeners(); }
  bool spendGems(int amount, {bool debugMode = false}) {
    if (debugMode) return true;
    if (_player.gems < amount) return false;
    _player.gems -= amount;
    notifyListeners();
    return true;
  }
  void addCoins(int amount) { _player.coins += amount; notifyListeners(); }
  void spendCoins(int amount) { _player.coins -= amount; notifyListeners(); }
  void setDailyTasksCompleted(int v) { _player.dailyTasksCompleted = v; notifyListeners(); }
  void incrementDailyTasksCompleted() { _player.dailyTasksCompleted++; notifyListeners(); }
  void incrementWeeklySRank() { _player.weeklySRankCompleted++; notifyListeners(); }
  void setNextDayTaskLimitOffset(int v) { _player.nextDayTaskLimitOffset = v; notifyListeners(); }

  void changeJob(Job j, {bool debugMode = false}) {
    if (debugMode) {
      _player.currentJob = j;
      notifyListeners();
      return;
    }
    if (j == Job.adventurer) {
      _player.currentJob = j;
      notifyListeners();
      return;
    }
    if (_player.currentJob == Job.adventurer) {
      final adventurerLv = _player.jobLevels[Job.adventurer] ?? 1;
      if (adventurerLv < 10) return;
    } else {
      final currentLv = _player.jobLevels[_player.currentJob] ?? 1;
      if (currentLv < 10) return;
    }
    _player.currentJob = j;
    notifyListeners();
  }

  void toggleSkill(Job j, {bool debugMode = false}) {
    if (!debugMode && !_player.isMastered(j)) return;
    if (_player.activeSkills.contains(j)) {
      _player.activeSkills.remove(j);
    } else {
      _player.activeSkills.add(j);
    }
    notifyListeners();
  }

  void equipTitle(String t) {
    if (_player.titles.contains(t) || t.isEmpty) {
      _player.equippedTitle = t.isEmpty ? null : t;
      notifyListeners();
    }
  }

  void equipSkin(String s) {
    if (_player.homeItems.contains(s) || s.isEmpty) {
      _player.equippedSkin = s.isEmpty ? null : s;
      notifyListeners();
    }
  }

  void equipCharacterSkin(SkinSlot slot, String skinId) {
    _player.characterSkin = _player.characterSkin.withSlot(slot, skinId);
    notifyListeners();
  }

  bool buyHomeItem(String id, int price, {bool debugMode = false}) {
    if (debugMode || (_player.coins >= price && !_player.homeItems.contains(id))) {
      if (!debugMode) _player.coins -= price;
      _player.homeItems.add(id);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// デバッグ用
  void debugSetCoins(int amount) {
    _player.coins = amount.clamp(0, 99999999);
    notifyListeners();
  }

  void debugSetGems(int amount) {
    _player.gems = amount.clamp(0, 99999);
    notifyListeners();
  }

  void clearPendingLoginBonus() { pendingLoginBonusAmount = null; notifyListeners(); }
  void clearPendingStreakReward() { pendingStreakReward = null; notifyListeners(); }

  // ── データロード/セーブ ──
  Future<void> load() async {
    _loadFailed = false;
    try {
      final loaded = await _playerRepository.loadPlayer();
      if (loaded != null) {
        _player = loaded;
      } else {
        _loadFailed = true; // データ破損時はデフォルトプレイヤーのままエラーフラグ
      }
    } catch (e, s) {
      debugPrint('[PlayerVM] load error: $e\n$s');
      _loadFailed = true;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    await _playerRepository.savePlayer(_player);
  }

  void closeRepository() => _playerRepository.close();
}
