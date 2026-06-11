import 'package:flutter/material.dart' hide DateUtils;
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/title_definition.dart';
import 'package:rpg_todo/domain/repositories/i_player_repository.dart';
import 'package:rpg_todo/domain/services/fatigue_service.dart';
import 'package:rpg_todo/domain/services/streak_service.dart';
import 'package:rpg_todo/domain/services/title_service.dart';
import 'package:rpg_todo/domain/services/reflection_badge_service.dart';
import 'package:rpg_todo/domain/models/reflection.dart';
import 'package:rpg_todo/features/town/data/reflection_repository.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'package:rpg_todo/core/utils/date_utils.dart';
import 'package:rpg_todo/features/town/domain/town_scale.dart';
import 'package:injectable/injectable.dart';

/// プレイヤーの状態と操作を管理するViewModel
@lazySingleton
class PlayerViewModel extends ChangeNotifier {
  final IPlayerRepository _playerRepository;

  Player _player = Player();
  bool _loadFailed = false;
  bool _isLoaded = false;
  int? pendingLoginBonusAmount;
  int? pendingStreakReward;

  PlayerViewModel(this._playerRepository);

  // ── 保存ガード（同時保存防止） ──
  bool _isSaving = false;
  bool _savePending = false;

  Player get player => _player;
  bool get isLoaded => _isLoaded;
  bool get loadFailed => _loadFailed;
  /// v1.6: データは存在するが読めない（バージョンアップ等による破損）
  bool get dataCorrupted => _loadFailed && _playerRepository.loadFailedDueToCorruption;

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

  /// 獲得済みの内省バッジID一覧。
  List<String> get reflectionBadges => _player.reflectionBadges;

  /// 累計振り返り回数。
  int get totalReflections => _player.totalReflections;

  /// 振り返りを記録し、内省バッジをチェックする。
  /// [bonusMessages] に獲得したバッジのメッセージが追加される。
  Future<void> checkReflectionBadges({
    required ReflectionRepository repository,
    required Reflection latestReflection,
    List<String>? bonusMessages,
  }) async {
    _player.recordReflection();
    final messages = bonusMessages ?? <String>[];
    await ReflectionBadgeService.checkBadges(
      _player,
      messages,
      repository: repository,
      latestReflection: latestReflection,
    );
    notifyListeners();
    _autoSave();
  }

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
  void _autoSave() {
    if (_isSaving) {
      _savePending = true;
      return;
    }
    _isSaving = true;
    _savePending = false;
    _playerRepository.savePlayer(_player).then((_) {
      _isSaving = false;
      if (_savePending) {
        _savePending = false;
        _autoSave();
      }
    }).catchError((e) {
      debugPrint('[PlayerVM] autoSave failed: $e');
      _isSaving = false;
    });
  }

  void addExp(int amount) { _player.addExp(amount); notifyListeners(); _autoSave(); }
  void addGems(int amount) { _player.gems += amount; notifyListeners(); _autoSave(); }
  bool spendGems(int amount, {bool debugMode = false}) {
    if (debugMode) return true;
    if (_player.gems < amount) return false;
    _player.gems -= amount;
    notifyListeners();
    _autoSave();
    return true;
  }
  void addCoins(int amount) { _player.coins += amount; notifyListeners(); _autoSave(); }
  void spendCoins(int amount) { _player.coins -= amount; notifyListeners(); _autoSave(); }
  void setDailyTasksCompleted(int v) { _player.dailyTasksCompleted = v; notifyListeners(); _autoSave(); }
  void incrementDailyTasksCompleted() { _player.dailyTasksCompleted++; notifyListeners(); _autoSave(); }
  void incrementWeeklySRank() { _player.weeklySRankCompleted++; notifyListeners(); _autoSave(); }
  void setNextDayTaskLimitOffset(int v) { _player.nextDayTaskLimitOffset = v; notifyListeners(); _autoSave(); }

  void changeJob(Job j, {bool debugMode = false}) {
    if (debugMode) {
      _player.currentJob = j;
      notifyListeners();
      _autoSave();
      return;
    }
    if (j == Job.adventurer) {
      _player.currentJob = j;
      notifyListeners();
      _autoSave();
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
    _autoSave();
  }

  void toggleSkill(Job j, {bool debugMode = false}) {
    if (!debugMode && !_player.isMastered(j)) return;
    if (_player.activeSkills.contains(j)) {
      _player.activeSkills.remove(j);
    } else {
      _player.activeSkills.add(j);
    }
    notifyListeners();
    _autoSave();
  }

  /// v4: スキルを装備スロットに追加する。スロット上限・重複チェックあり。
  void equipSkill(JobSkill skill, {bool debugMode = false}) {
    if (!debugMode) {
      final maxSlots = JobSkill.maxSkillSlots(_player.jobLevels);
      if (_player.equippedSkills.length >= maxSlots) return;
      if (_player.equippedSkills.any((es) => es.skill == skill)) return;
    }
    _player.equippedSkills.add(EquippedSkill(skill: skill));
    notifyListeners();
    _autoSave();
  }

  /// v4: 指定スロットの装備スキルを解除する。
  void unequipSkill(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= _player.equippedSkills.length) return;
    _player.equippedSkills.removeAt(slotIndex);
    notifyListeners();
    _autoSave();
  }

  /// v4: 指定スロットの装備スキルのON/OFFをトグルする。
  void toggleEquippedSkill(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= _player.equippedSkills.length) return;
    _player.equippedSkills[slotIndex].isActive =
        !_player.equippedSkills[slotIndex].isActive;
    notifyListeners();
    _autoSave();
  }

  void equipTitle(String t) {
    if (_player.titles.contains(t) || t.isEmpty) {
      _player.equippedTitle = t.isEmpty ? null : t;
      notifyListeners();
      _autoSave();
    }
  }

  void equipSkin(String s) {
    if (_player.homeItems.contains(s) || s.isEmpty) {
      _player.equippedSkin = s.isEmpty ? null : s;
      notifyListeners();
      _autoSave();
    }
  }

  void equipCharacterSkin(SkinSlot slot, String skinId) {
    _player.characterSkin = _player.characterSkin.withSlot(slot, skinId);
    notifyListeners();
    _autoSave();
  }

  bool buyHomeItem(String id, int price, {bool debugMode = false}) {
    if (debugMode || (_player.coins >= price && !_player.homeItems.contains(id))) {
      if (!debugMode) _player.coins -= price;
      _player.homeItems.add(id);
      notifyListeners();
      _autoSave();
      return true;
    }
    return false;
  }

  /// デバッグ用
  void debugSetCoins(int amount) {
    _player.coins = amount.clamp(0, 99999999);
    notifyListeners();
    _autoSave();
  }

  void debugSetGems(int amount) {
    _player.gems = amount.clamp(0, 99999);
    notifyListeners();
    _autoSave();
  }

  void clearPendingLoginBonus() { pendingLoginBonusAmount = null; notifyListeners(); }
  void clearPendingStreakReward() { pendingStreakReward = null; notifyListeners(); }

  /// バックアップ復元時に Player を差し替える。
  void restorePlayer(Player p) {
    _player = p;
    notifyListeners();
    save();
  }

  /// 刻の番人討伐時の称号チェック（GameViewModelから移行）
  void defeatTimeWarden() {
    _player.timesWardenDefeated++;
    TitleService.checkTitles(_player, []);
    notifyListeners();
  }

  /// 誤答ペナルティの適用（GameViewModelから移行）
  void applyWrongAnswerPenalty(int expPenalty, int coinPenalty) {
    final p = _player;
    p.jobExps[p.currentJob] = (p.jobExps[p.currentJob] ?? 0) - expPenalty;
    if (p.jobExps[p.currentJob]! < 0) p.jobExps[p.currentJob] = 0;
    p.coins -= coinPenalty;
    if (p.coins < 0) p.coins = 0;
    notifyListeners();
    _autoSave();
  }

  /// save()失敗時のコールバック
  VoidCallback? onSaveError;

  // ── データロード/セーブ ──
  Future<void> load() async {
    _loadFailed = false;
    try {
      final loaded = await _playerRepository.loadPlayer();
      if (loaded != null) {
        _player = loaded;
        // ignore: avoid_print
        print('[PlayerVM] load OK: Lv.${_player.level}, coins=${_player.coins}, jobLevels=${_player.jobLevels}');
      } else {
        _loadFailed = true;
        // ignore: avoid_print
        print('[PlayerVM] load returned null — using default Player');
      }
    } catch (e, s) {
      debugPrint('[PlayerVM] load error: $e\n$s');
      _loadFailed = true;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    // ★ v1.6: corruption時は旧データを上書きしない
    if (_playerRepository.loadFailedDueToCorruption) {
      debugPrint('[PlayerVM] Skipping save — data corruption detected');
      return;
    }
    try {
      await _playerRepository.savePlayer(_player);
    } catch (e) {
      debugPrint('[PlayerVM] save failed: $e');
      onSaveError?.call();
    }
  }

  void closeRepository() => _playerRepository.close();
}
