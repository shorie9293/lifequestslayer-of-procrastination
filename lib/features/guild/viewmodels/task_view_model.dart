import 'package:flutter/material.dart' hide DateUtils;
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/repositories/i_task_repository.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';
import 'package:rpg_todo/features/battle/domain/quiz_service.dart';
import 'package:rpg_todo/core/utils/date_utils.dart';
import 'package:rpg_todo/features/kozuchi/domain/kozuchi_quest_model.dart';
import 'package:rpg_todo/features/kozuchi/data/kozuchi_quest_service.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/battle/domain/enemy_asset_service.dart';
import 'package:injectable/injectable.dart';

/// クエストのCRUDと操作を管理するViewModel
@lazySingleton
class TaskViewModel extends ChangeNotifier {
  final ITaskRepository _taskRepository;
  final PlayerViewModel _playerVM;
  final _completion = TaskCompletionService();
  final _completing = <String>{};

  List<Task> _tasks = [];
  bool _isLoaded = false;
  IKozuchiQuestService? _kozuchiQuestService;
  KozuchiQuest? _kozuchiQuest;

  TaskViewModel(this._taskRepository, this._playerVM);

  // ── 保存ガード（同時保存防止） ──
  bool _isSaving = false;
  bool _savePending = false;

  void _autoSave() {
    if (_isSaving) {
      _savePending = true;
      return;
    }
    _isSaving = true;
    _savePending = false;
    _taskRepository.saveTasks(_tasks).then((_) {
      _isSaving = false;
      if (_savePending) {
        _savePending = false;
        _autoSave();
      }
    }).catchError((e) {
      debugPrint('[TaskVM] autoSave failed: $e');
      _isSaving = false;
    });
  }

  List<Task> get tasks => _tasks;
  bool get isLoaded => _isLoaded;
  IKozuchiQuestService? get kozuchiQuestService => _kozuchiQuestService;
  set kozuchiQuestService(IKozuchiQuestService? service) {
    _kozuchiQuestService = service;
  }
  KozuchiQuest? get kozuchiQuest => _kozuchiQuest;

  // ── クエストフィルタ ──
  List<Task> get activeTasks => _tasks.where((t) =>
      t.status == TaskStatus.active && !t.isCompleted && _visible(t)).toList();

  List<Task> get guildTasks => _tasks.where((t) =>
      t.status == TaskStatus.inGuild && !t.isCompleted).toList();

  List<Task> get recurringTasks => _tasks.where((t) =>
      t.repeatInterval != RepeatInterval.none).toList();

  List<Task> get urgentGuildTasks {
    final now = DateTime.now();
    final threshold = now.add(const Duration(hours: 24));
    return guildTasks
        .where((t) => t.deadline != null && t.deadline!.isBefore(threshold))
        .toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  }

  int get guildEstimatedMinutes =>
      guildTasks.fold(0, (s, t) => s + (t.targetTimeMinutes ?? 0));

  int get dailyEstimatedMinutes =>
      activeTasks.fold(0, (s, t) => s + (t.targetTimeMinutes ?? 0));

  bool _visible(Task t) {
    final hasRepeatSkill = _playerVM.player.hasSkill(JobSkill.roninRepeatTask) ||
        _playerVM.player.canUseSkill(Job.monk);
    if (!hasRepeatSkill || t.repeatInterval == RepeatInterval.none) return true;
    final now = DateTime.now();
    if (t.repeatInterval == RepeatInterval.weekly &&
        t.repeatWeekdays.isNotEmpty &&
        !t.repeatWeekdays.contains(now.weekday)) {
      return false;
    }
    if (t.lastCompletedAt != null) {
      final l = t.lastCompletedAt!;
      if (now.year == l.year &&
          now.month == l.month &&
          now.day == l.day) {
        return false;
      }
    }
    return true;
  }

  /// 神託5: 魔導書解析 - 推定時間計算
  int? estimateMinutes(String title, QuestRank rank) {
    final completed = _tasks.where((t) =>
        t.isCompleted && t.targetTimeMinutes != null).toList();
    if (completed.isEmpty) return null;

    final sameRank = completed.where((t) => t.rank == rank).toList();
    final titleWords = title
        .split(RegExp(r'[\s　,、。．.]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final similarTitle = completed.where((t) =>
        t.id != '' &&
        titleWords.any((w) => w.length >= 2 && t.title.contains(w))).toList();

    final relevant = <Task>{...sameRank, ...similarTitle}.toList();
    if (relevant.isEmpty) return null;

    final total = relevant.fold<int>(0, (sum, t) => sum + t.targetTimeMinutes!);
    return total ~/ relevant.length;
  }

  // ── CRUD ──
  void addTask(String title,
      {QuestRank rank = QuestRank.B,
       RepeatInterval repeatInterval = RepeatInterval.none,
       List<int>? repeatWeekdays,
       List<SubTask>? subTasks,
       int? targetTimeMinutes,
       DateTime? deadline}) {
    final enemyEntry = EnemyAssetService.randomEntryForRank(rank);
    _tasks.add(Task(
        id: const Uuid().v4(),
        title: title,
        rank: rank,
        repeatInterval: repeatInterval,
        repeatWeekdays: repeatWeekdays,
        subTasks: subTasks,
        targetTimeMinutes: targetTimeMinutes,
        deadline: deadline,
        enemyAssetPath: enemyEntry.assetPath,
        enemyXpMultiplier: enemyEntry.xpMultiplier));
    notifyListeners();
    _autoSave();
  }

  void addTasks(List<String> titles, QuestRank rank) {
    for (final title in titles) {
      final enemyEntry = EnemyAssetService.randomEntryForRank(rank);
      _tasks.add(Task(
          id: const Uuid().v4(),
          title: title,
          rank: rank,
          enemyAssetPath: enemyEntry.assetPath,
          enemyXpMultiplier: enemyEntry.xpMultiplier));
    }
    notifyListeners();
    _autoSave();
  }

  void editTask(String id, String title,
      {QuestRank rank = QuestRank.B,
       RepeatInterval repeatInterval = RepeatInterval.none,
       List<int>? repeatWeekdays,
       List<SubTask>? subTasks,
       int? targetTimeMinutes,
       DateTime? deadline}) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return;
    _tasks[i]
      ..title = title
      ..rank = rank
      ..repeatInterval = repeatInterval
      ..repeatWeekdays = repeatWeekdays ?? []
      ..subTasks = subTasks ?? []
      ..targetTimeMinutes = targetTimeMinutes
      ..deadline = deadline;
    notifyListeners();
    _autoSave();
  }

  String? acceptTask(String id, {bool debugMode = false}) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) return "クエストが見つかりません";
    final t = _tasks[i];
    if (!debugMode &&
        !_playerVM.player.canAcceptQuest(
            t.rank, activeTasks.where((x) => x.rank == t.rank).length)) {
      return "${t.rank.name}ランクのキャパシティオーバー！";
    }
    _tasks[i].status = TaskStatus.active;
    _tasks[i].activeAt = DateTime.now();
    _tasks[i].cancelledAt = null; // M12: 再受注時に取消フラグをクリア
    notifyListeners();
    _autoSave();
    return null;
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    _autoSave();
  }

  void cancelTask(String id) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i != -1) {
      _tasks[i].status = TaskStatus.inGuild;
      _tasks[i].cancelledAt = DateTime.now(); // M12: 再起動時のautoDeploy抑制
      notifyListeners();
      _autoSave();
    }
  }

  void toggleSubTask(String id, int idx) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i != -1 && idx >= 0 && idx < _tasks[i].subTasks.length) {
      _tasks[i].subTasks[idx].isCompleted =
          !_tasks[i].subTasks[idx].isCompleted;
      HapticFeedback.lightImpact();
      notifyListeners();
      _autoSave();
    }
  }

  /// クエスト完了。戻り値は完了結果のマップ
  Map<String, dynamic>? completeTask(String id,
      {bool knowledgeQuestEnabled = true, bool debugMode = false}) {
    if (_completing.contains(id)) return null;
    _completing.add(id);
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i == -1) {
      _completing.remove(id);
      return null;
    }
    final r = _completion.complete(
        task: _tasks[i],
        player: _playerVM.player,
        hasShownFatiguePopupToday: false, // handled by caller
        knowledgeQuestEnabled: knowledgeQuestEnabled);
    if (r == null) {
      _completing.remove(id);
      return null;
    }
    _playerVM.notifyListeners(); // player state changed
    notifyListeners();
    _playerVM.save(); // player の変更も永続化
    _autoSave();
    _completing.remove(id);
    return {
      'leveledUp': r.leveledUp,
      'coinsGained': r.coinsGained,
      'bonusMessages': r.bonusMessages,
      'showFatiguePopup': r.showFatiguePopup,
      'quizQuestion': r.quizQuestion,
      'baseExp': r.expGain,
      'isOverdueBoss': r.isOverdueBoss,
      'wrongAnswerPenaltyExp': r.wrongAnswerPenaltyExp,
      'wrongAnswerPenaltyCoins': r.wrongAnswerPenaltyCoins,
    };
  }

  void awardKnowledgeBonus(int pct, int base) {
    final b = QuizService.calcBonusExp(pct, base);
    if (b > 0) {
      _playerVM.addExp(b);
      _playerVM.save();
    }
  }

  /// 神託1: 今日・明日が期限のギルドクエストを自動配備（最大6件まで）
  void autoDeployTodaysTasks() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));

    // 今日 + 明日が期限のクエストを集める（ただし手動取消されたものは除外）
    final urgentTasks = guildTasks.where((t) =>
        t.deadline != null &&
        t.cancelledAt == null && // M12: 手動取消されたクエストは再配備しない
        (DateUtils.isSameDay(t.deadline!, now) ||
         DateUtils.isSameDay(t.deadline!, tomorrow))).toList();

    if (urgentTasks.isEmpty) {
      debugPrint('[神託] 近日期限のギルドクエストはありません');
      return;
    }

    const rankOrder = {QuestRank.S: 0, QuestRank.A: 1, QuestRank.B: 2};
    urgentTasks.sort((a, b) =>
        rankOrder[a.rank]!.compareTo(rankOrder[b.rank]!));

    const maxActiveQuests = 6;
    int deployedCount = 0;
    for (final task in urgentTasks) {
      if (activeTasks.length >= maxActiveQuests) break;
      final result = acceptTask(task.id);
      if (result == null) deployedCount++;
    }
    debugPrint('[神託] 自動配備完了: $deployedCount 件 (active計: ${activeTasks.length})');
  }

  // ── 小槌連携 ──
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

  // ── デバッグ ──
  void debugCompleteAllActive() {
    for (final task in activeTasks.toList()) {
      completeTask(task.id);
    }
  }

  void debugAddTestTasks() {
    addTask('デバッグ：魔物討伐（Slimeを3匹倒せ）',
        rank: QuestRank.B, targetTimeMinutes: 15);
    addTask('デバッグ：素材収集（薬草を10個集めよ）',
        rank: QuestRank.B, targetTimeMinutes: 30);
    addTask('デバッグ：古代遺跡の調査', rank: QuestRank.A, targetTimeMinutes: 60);
  }

  /// バックアップ復元時にクエストリストを差し替える。
  void setTasks(List<Task> tasks) {
    _tasks = tasks;
    notifyListeners();
    save();
  }

  /// save()失敗時のコールバック
  VoidCallback? onSaveError;

  // ── データロード/セーブ ──
  Future<void> load() async {
    try {
      _tasks = await _taskRepository.loadTasks();
    } catch (e, s) {
      debugPrint('[TaskVM] load error: $e\n$s');
      _tasks = [];
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    try {
      await _taskRepository.saveTasks(_tasks);
    } catch (e) {
      debugPrint('[TaskVM] save failed: $e');
      onSaveError?.call();
    }
  }

  void closeRepository() => _taskRepository.close();
}
