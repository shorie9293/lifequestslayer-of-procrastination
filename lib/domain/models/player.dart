import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'task.dart';
import 'skill_slot.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';
import 'skill_tree.dart';
import 'job.dart';

/// 職業スキル — 14スキル (Ronin 2, Warrior 4, Cleric 4, Wizard 4)
enum JobSkill {
  // Ronin (冒険者) — 基本スキル
  roninSlots,
  roninRepeatTask,

  // Warrior (戦士) — 討伐特化
  warriorCombo,
  warriorFatigueReverse,
  warriorPomodoro,
  warriorBushido,

  // Cleric (僧侶) — 継続支援
  clericRepeatAfter,
  clericSnooze,
  clericStreak,
  clericEnlightenment,

  // Wizard (魔法使い) — 管理強化
  wizardSubtask,
  wizardTags,
  wizardProject,
  wizardOverview,
  ;

  /// 装備可能な最大スキルスロット数。
  /// 基本1枠 + Roninマスター(+1) + 各職マスター(+1)。
  static int maxSkillSlots(Map<Job, int> jobLevels) {
    int slots = 1;
    if ((jobLevels[Job.adventurer] ?? 1) >= 10) slots++;
    if ((jobLevels[Job.warrior] ?? 1) >= 15) slots++;
    if ((jobLevels[Job.cleric] ?? 1) >= 15) slots++;
    if ((jobLevels[Job.wizard] ?? 1) >= 15) slots++;
    return slots;
  }
}

extension JobSkillMeta on JobSkill {
  Job get job {
    switch (this) {
      case JobSkill.roninSlots:
      case JobSkill.roninRepeatTask:
        return Job.adventurer;
      case JobSkill.warriorCombo:
      case JobSkill.warriorFatigueReverse:
      case JobSkill.warriorPomodoro:
      case JobSkill.warriorBushido:
        return Job.warrior;
      case JobSkill.clericRepeatAfter:
      case JobSkill.clericSnooze:
      case JobSkill.clericStreak:
      case JobSkill.clericEnlightenment:
        return Job.cleric;
      case JobSkill.wizardSubtask:
      case JobSkill.wizardTags:
      case JobSkill.wizardProject:
      case JobSkill.wizardOverview:
        return Job.wizard;
    }
  }

  int get requiredLevel {
    switch (this) {
      // Ronin
      case JobSkill.roninSlots:
        return 1;
      case JobSkill.roninRepeatTask:
        return 10;
      // Warrior
      case JobSkill.warriorCombo:
        return 1;
      case JobSkill.warriorFatigueReverse:
        return 5;
      case JobSkill.warriorPomodoro:
        return 10;
      case JobSkill.warriorBushido:
        return 15;
      // Cleric
      case JobSkill.clericRepeatAfter:
        return 1;
      case JobSkill.clericSnooze:
        return 5;
      case JobSkill.clericStreak:
        return 10;
      case JobSkill.clericEnlightenment:
        return 15;
      // Wizard
      case JobSkill.wizardSubtask:
        return 1;
      case JobSkill.wizardTags:
        return 5;
      case JobSkill.wizardProject:
        return 10;
      case JobSkill.wizardOverview:
        return 15;
    }
  }

  bool get isMasterSkill {
    if (this == JobSkill.roninRepeatTask) return true;
    return requiredLevel == 15;
  }

  static const _displayNames = {
    JobSkill.roninSlots: '冒険者の勘',
    JobSkill.roninRepeatTask: '果てなき挑戦',
    JobSkill.warriorCombo: '連撃の構え',
    JobSkill.warriorFatigueReverse: '逆転の気魄',
    JobSkill.warriorPomodoro: '集中の型',
    JobSkill.warriorBushido: '武士道の極意',
    JobSkill.clericRepeatAfter: '後追いの祈り',
    JobSkill.clericSnooze: '微睡みの加護',
    JobSkill.clericStreak: '連続の誓い',
    JobSkill.clericEnlightenment: '悟りの境地',
    JobSkill.wizardSubtask: '分割の理',
    JobSkill.wizardTags: '札の掌握',
    JobSkill.wizardProject: '計画の陣',
    JobSkill.wizardOverview: '俯瞰の魔眼',
  };

  String get displayName => _displayNames[this] ?? name;

  static const _descriptions = {
    JobSkill.roninSlots: 'クエストランクと枠数が拡大。S/A/Bランクの上限が増える',
    JobSkill.roninRepeatTask: '完了済みクエストを「繰り返し」として再発行可能に',
    JobSkill.warriorCombo: '連続達成でEXPボーナス。コンボ数が多いほど報酬が増える',
    JobSkill.warriorFatigueReverse: '疲労度が高いほどEXP倍率が上昇。逆境が強さに変わる',
    JobSkill.warriorPomodoro: 'ポモドーロタイマー連動。集中時間に応じてEXPボーナス',
    JobSkill.warriorBushido: '毎日1つクエストを完了するだけでバフが蓄積。継続が力に',
    JobSkill.clericRepeatAfter: '完了後、指定日数で自動的にクエストを再発行',
    JobSkill.clericSnooze: 'クエストをスヌーズ（後回し）可能。猶予を与えられる',
    JobSkill.clericStreak: 'タスクごとの連続完了を記録。ストリークで報酬UP',
    JobSkill.clericEnlightenment: '週1回、ストリークを守る猶予。中断しても連続記録が消えない',
    JobSkill.wizardSubtask: 'クエストをサブクエスト（小タスク）に分割可能に',
    JobSkill.wizardTags: 'クエストに札（タグ）を付けて整理・検索',
    JobSkill.wizardProject: '複数クエストをプロジェクトとしてまとめ、全達成でボーナス',
    JobSkill.wizardOverview: 'プロジェクト全体を俯瞰し、進捗を一覧表示',
  };

  String get description => _descriptions[this] ?? '';

  /// RoninスキルはJobLv>=10、他職業スキルはJobLv>=15 で mastered。
  bool isMastered(int jobLevel) {
    if (job == Job.adventurer) return jobLevel >= 10;
    return jobLevel >= 15;
  }
}

/// Cleric Lv10: タスクごとの連続完了記録
class TaskStreak {
  int currentStreak;
  DateTime lastCompletedDate;

  TaskStreak({
    this.currentStreak = 1,
    required this.lastCompletedDate,
  });

  Map<String, dynamic> toJson() => {
        'currentStreak': currentStreak,
        'lastCompletedDate': lastCompletedDate.toIso8601String(),
      };

  factory TaskStreak.fromJson(Map<String, dynamic> json) {
    return TaskStreak(
      currentStreak: json['currentStreak'] as int,
      lastCompletedDate: DateTime.parse(json['lastCompletedDate'] as String),
    );
  }
}

class JobSkillAdapter extends TypeAdapter<JobSkill> {
  @override
  final int typeId = 10;

  @override
  JobSkill read(BinaryReader reader) {
    return JobSkill.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, JobSkill obj) {
    writer.writeByte(obj.index);
  }
}

class JobAdapter extends TypeAdapter<Job> {
  @override
  final int typeId = 4;

  @override
  Job read(BinaryReader reader) {
    return Job.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, Job obj) {
    writer.writeByte(obj.index);
  }
}

class Player {
  // Deprecated single fields, kept for migration if needed, or removed and handled in Adapter logic.
  // Actually, let's keep them as getters/setters for compatibility if referenced elsewhere, or just migrate internally.
  // Let's store the Maps.
  Map<Job, int> jobLevels;
  Map<Job, int> jobExps;
  @Deprecated('v4: equippedSkills に移行。互換性のため維持')
  Set<Job> activeSkills; // Mastery skills equipped (v3互換、削除予定)
  List<EquippedSkill> equippedSkills; // v4: 装備スキル
  Job currentJob;
  int comboCount;
  int coins;
  List<String> homeItems;
  int dailyTasksCompleted;
  int weeklySRankCompleted;
  DateTime? lastMissionResetDate;

  // Inn / Sleep System (Plan 1)
  int nextDayTaskLimitOffset;
  int todayTaskLimitOffset;
  DateTime? lastRestDate;

  // Title / Achievement System (Plan 3)
  int totalTasksCompleted;
  int totalSRankCompleted;
  int totalARankCompleted;
  int totalBRankCompleted;
  int timesWardenDefeated; // 刻の番人討伐回数
  List<String> titles;
  String? equippedTitle;
  String? equippedSkin; // 追加: 装備中のスキンID（旧ショップスキン）
  CharacterSkin characterSkin; // 追加: 5部位カスタマイズ
  int gems; // プレミアム通貨（課金で取得）

  // --- ストリーク（連続ログイン） ---
  int streakDays;
  int longestStreak;
  DateTime? lastLoginDate;

  // --- v4: ポモドーロ設定 ---
  int pomodoroMinutes;
  int pomodoroShortBreakMinutes;
  int pomodoroLongBreakMinutes;
  int pomodorosBeforeLongBreak;
  /// T9: Warrior Lv10 集中の型 — ポモドーロアクティブセッションの開始時刻
  DateTime? pomodoroStartTime;

  /// T10: Warrior Lv15 武士道の極意 — 最終完了日
  DateTime? lastDailyComplete;
  /// T10: 武士道の極意 — 蓄積バフ（0.1%単位、例: 10 = 1.0%）
  int warriorDailyBuff = 0;

  /// T10: 悟りの境地 — 猶予回数（週1回リセット、最大1）
  int streakGraceRemaining = 1;
  /// T10: 悟りの境地 — 最終猶予リセット日
  DateTime? lastStreakGraceReset;

  // --- v5: スキルツリー ---
  /// 未使用のスキルポイント。冒険者Lv上昇時に獲得。
  int skillPoints = 0;
  /// 解放済みのスキルノードID一覧。
  List<String> unlockedSkillIds = [];

  /// T9: 集中の型 — ポモドーロセッションがアクティブか
  bool get isPomodoroActive {
    if (pomodoroStartTime == null) return false;
    return DateTime.now().difference(pomodoroStartTime!).inMinutes < pomodoroMinutes;
  }

  /// T9: 集中の型 — ポモドーロセッションを開始
  void startPomodoro() {
    pomodoroStartTime = DateTime.now();
  }

  /// T9: 集中の型 — ポモドーロセッションを終了
  void endPomodoro() {
    pomodoroStartTime = null;
  }

  /// T10: 武士道の極意 — 本日の初回完了かを判定し、buffを蓄積
  void recordDailyCompletion() {
    final now = DateTime.now();
    final last = lastDailyComplete;
    if (last == null ||
        last.year != now.year ||
        last.month != now.month ||
        last.day != now.day) {
      lastDailyComplete = DateTime(now.year, now.month, now.day);
      warriorDailyBuff++;
    }
  }

  /// T10: 悟りの境地 — 猶予を消費
  void consumeStreakGrace() {
    if (streakGraceRemaining > 0) {
      streakGraceRemaining--;
    }
  }

  /// T10: 悟りの境地 — 週次リセット判定
  void resetStreakGraceIfNeeded() {
    final now = DateTime.now();
    if (lastStreakGraceReset == null) {
      lastStreakGraceReset = DateTime(now.year, now.month, now.day);
      streakGraceRemaining = 1;
      return;
    }
    final diff = now.difference(lastStreakGraceReset!).inDays;
    if (diff >= 7) {
      lastStreakGraceReset = DateTime(now.year, now.month, now.day);
      streakGraceRemaining = 1;
    }
  }

  // --- v4: タグ・プロジェクト ---
  List<String> tags;
  List<ProjectGroup> projects;

  // --- v4: wizardTags — タグ→タスクIDの逆引きマップ ---
  Map<String, List<String>> taskTags;
  // --- v4: wizardProject — タスクID→プロジェクト名の逆引きマップ ---
  Map<String, String> taskProjects;

  // --- v4: Cleric スキル用 ---
  /// Lv5: 微睡みの加護 — snooze済みタスクID → snooze実行日
  Map<String, DateTime> snoozedTasks = {};
  /// Lv10: 連続の誓い — タスクごとの連続完了記録
  Map<String, TaskStreak> taskStreaks = {};

  Player({
    Map<Job, int>? jobLevels,
    Map<Job, int>? jobExps,
    Set<Job>? activeSkills,
    this.currentJob = Job.adventurer,
    this.comboCount = 0,
    this.coins = 0,
    List<String>? homeItems,
    this.dailyTasksCompleted = 0,
    this.weeklySRankCompleted = 0,
    this.lastMissionResetDate,
    this.nextDayTaskLimitOffset = 0,
    this.todayTaskLimitOffset = 0,
    this.lastRestDate,
    this.totalTasksCompleted = 0,
    this.totalSRankCompleted = 0,
    this.totalARankCompleted = 0,
    this.totalBRankCompleted = 0,
    this.timesWardenDefeated = 0,
    List<String>? titles,
    this.equippedTitle,
    this.equippedSkin,
    CharacterSkin? characterSkin,
    this.gems = 0,
    this.streakDays = 0,
    this.longestStreak = 0,
    this.lastLoginDate,
    this.pomodoroMinutes = 25,
    this.pomodoroShortBreakMinutes = 5,
    this.pomodoroLongBreakMinutes = 15,
    this.pomodorosBeforeLongBreak = 4,
    this.pomodoroStartTime,
    this.lastDailyComplete,
    this.warriorDailyBuff = 0,
    this.streakGraceRemaining = 1,
    this.lastStreakGraceReset,
    List<String>? tags,
    List<ProjectGroup>? projects,
    List<EquippedSkill>? equippedSkills,
    Map<String, List<String>>? taskTags,
    Map<String, String>? taskProjects,
    Map<String, DateTime>? snoozedTasks,
    Map<String, TaskStreak>? taskStreaks,
    this.skillPoints = 0,
    List<String>? unlockedSkillIds,
  })  : characterSkin = characterSkin ?? const CharacterSkin(), jobLevels = jobLevels ?? {Job.adventurer: 1},
        jobExps = jobExps ?? {Job.adventurer: 0},
        activeSkills = activeSkills ?? {},
        homeItems = homeItems ?? [],
        titles = titles ?? [],
        tags = tags ?? [],
        projects = projects ?? [],
        equippedSkills = equippedSkills ?? [],
        taskTags = taskTags ?? {},
        taskProjects = taskProjects ?? {},
        snoozedTasks = snoozedTasks ?? {},
        taskStreaks = taskStreaks ?? {},
        unlockedSkillIds = unlockedSkillIds ?? [];

  // Getters for current job (Compatibility)
  int get level => jobLevels[currentJob] ?? 1;
  int get currentExp => jobExps[currentJob] ?? 0;

  // Calculate expToNextLevel dynamically based on level
  int get expToNextLevel => expForLevel(level);

  /// 指定レベルに必要な経験値を計算（Lv1→50, Lv10→~1034, Lv20→~29914）
  static int expForLevel(int lvl) =>
      (50 * pow(1.4, lvl - 1)).round();

  Map<QuestRank, int> get questSlots {
    // Mastery: Adventurer Lv10 unlocks max slots permanently?
    // Request: "冒険者のスキル(タスクランク、数の解放)は常時オン" implies if Adventurer mastered, we use Adventurer stats?
    // "基本色は20レベルになると...冒険者は10レベル"
    // "各職業のレベルは転職しても維持"
    // "冒険者のスキルのタスクランク...は常時オン" -> This likely means if you master Adventurer, you get the slots of a high level adventurer even if you are Lv1 Warrior.

    int refLevel = level;
    if (isMastered(Job.adventurer)) {
      // Adventurer max level cap is 10 for mastery?
      // Assuming gaining mastery means effectively Lv10+ benefits.
      // If mastered, use max logic?
      // Let's use the HIGHER of current level OR Adventurer level (if mastered/high).
      int advLvl = jobLevels[Job.adventurer] ?? 1;
      if (advLvl > refLevel) refLevel = advLvl;
    }

    if (refLevel >= 10) {
      return {QuestRank.S: 1, QuestRank.A: 2, QuestRank.B: 3};
    }
    if (refLevel >= 5) {
      return {QuestRank.S: 0, QuestRank.A: 1, QuestRank.B: 3};
    }
    if (refLevel >= 2) {
      return {QuestRank.S: 0, QuestRank.A: 0, QuestRank.B: 2};
    }

    return {QuestRank.S: 0, QuestRank.A: 0, QuestRank.B: 1};
  }

  bool canAcceptQuest(QuestRank rank, int currentRankActiveCount) {
    final maxSlots = questSlots[rank] ?? 0;
    return currentRankActiveCount < maxSlots;
  }

  bool isMastered(Job job) {
    int lvl = jobLevels[job] ?? 1;
    if (job == Job.adventurer) return lvl >= 10;
    return lvl >= 14;
  }

  bool canUseSkill(Job job) {
    if (currentJob == job) return true;
    if (isMastered(job) && activeSkills.contains(job)) return true;
    // Adventurer passive is Always On if Mastered? "常時オン"
    if (job == Job.adventurer && isMastered(Job.adventurer)) return true;
    return false;
  }

  /// v4: JobSkill 単位のスキル使用可否判定。
  /// - Ronin スキル: Adventurer mastered (Lv10+) で常時オン
  /// - v4 equippedSkills: 明示装備 + 必要レベル達成
  /// - v3 互換: isMastered + activeSkills
  /// - 現在の職業: 現在レベル以下の全スキル有効
  bool hasSkill(JobSkill skill) {
    final job = skill.job;
    final jobLevel = jobLevels[job] ?? 1;

    // Ronin: adventurer mastered (Lv10+) → 全Roninスキル常時オン
    if (job == Job.adventurer && isMastered(Job.adventurer)) return true;

    // v4: equippedSkills に明示装備 + 必要レベル達成
    if (equippedSkills.any((es) => es.skill == skill) &&
        jobLevel >= skill.requiredLevel) {
      return true;
    }

    // v3互換: isMastered + activeSkills → その職の全スキル有効
    if (isMastered(job) && activeSkills.contains(job)) return true;

    // 現在の職業: 現在レベル以下なら全スキル有効
    if (currentJob == job && jobLevel >= skill.requiredLevel) return true;

    return false;
  }

  /// wizardSubtask etc: equippedSkills への明示装備チェック
  /// hasSkill と異なり、マスター特権や現職全開放を適用せず、
  /// スキル個別の装備のみを判定する。
  bool isSkillEquipped(JobSkill skill) {
    return equippedSkills.any((es) => es.skill == skill) &&
        canUseSkill(skill.job);
  }

  // --- wizardTags ---

  /// タスクに札（タグ）を付ける
  void tagTask(String taskId, String tag) {
    taskTags.putIfAbsent(tag, () => []);
    if (!taskTags[tag]!.contains(taskId)) {
      taskTags[tag]!.add(taskId);
    }
  }

  /// タスクから札を外す
  void untagTask(String taskId, String tag) {
    taskTags[tag]?.remove(taskId);
    if (taskTags[tag]?.isEmpty ?? false) {
      taskTags.remove(tag);
    }
  }

  /// 指定された札に紐づくタスクID一覧を返す
  List<String> getTaskIdsByTag(String tag) {
    return List.unmodifiable(taskTags[tag] ?? []);
  }

  // --- wizardProject ---

  /// タスクをプロジェクトに所属させる
  void addToProject(String taskId, String projectName) {
    taskProjects[taskId] = projectName;
  }

  /// タスクをプロジェクトから外す
  void removeFromProject(String taskId) {
    taskProjects.remove(taskId);
  }

  // v1.3: レベル上限（powオーバーフロー防止）
  static const int maxLevel = 99;

  /// Cleric Lv5: 微睡みの加護 — タスクのdeadlineを翌日に延期
  void snoozeTask(String taskId, Task task, DateTime now) {
    if (task.deadline == null) return;
    final currentDeadline = task.deadline!;
    // 現在のdeadlineから1日追加
    task.deadline = currentDeadline.add(const Duration(days: 1));
    snoozedTasks[taskId] = now;
  }

  /// Cleric Lv10: 連続の誓い — タスク完了を記録しstreakを更新
  void recordTaskCompletion(String taskId, DateTime completedDate) {
    final today = DateTime(completedDate.year, completedDate.month, completedDate.day);
    final existing = taskStreaks[taskId];

    if (existing == null) {
      taskStreaks[taskId] = TaskStreak(
        currentStreak: 1,
        lastCompletedDate: today,
      );
      return;
    }

    final lastDate = existing.lastCompletedDate;
    final diffDays = today.difference(lastDate).inDays;

    if (diffDays == 0) {
      // 同日の複数完了は無視
      return;
    } else if (diffDays == 1) {
      // 連続日 → streak増加
      existing.currentStreak++;
      existing.lastCompletedDate = today;
    } else {
      // 1日以上空いた → streakリセット
      existing.currentStreak = 1;
      existing.lastCompletedDate = today;
    }
  }

  /// Cleric Lv10: 7日以上のstreakで +20% EXPボーナス
  double getTaskStreakBonus(String taskId) {
    final streak = taskStreaks[taskId];
    if (streak == null) return 1.0;
    return streak.currentStreak >= 7 ? 1.2 : 1.0;
  }

  // --- v5: スキルツリー ---

  /// 冒険者Lv上昇時に呼び、獲得したスキルポイントを加算する。
  ///
  /// [oldAdventurerLevel] はレベルアップ前の冒険者Lv。
  /// 計算式: max(0, (newLv - 2) ~/ 3) - max(0, (oldLv - 2) ~/ 3)
  void awardSkillPointsOnLevelUp(int oldAdventurerLevel) {
    final newLevel = jobLevels[Job.adventurer] ?? 1;
    final oldEarned = totalEarnedSkillPoints(oldAdventurerLevel);
    final newEarned = totalEarnedSkillPoints(newLevel);
    final delta = newEarned - oldEarned;
    if (delta > 0) {
      skillPoints += delta;
    }
  }

  /// スキルノードを解放する。
  ///
  /// 戻り値: 解放に成功した場合は `true`。
  /// ポイント不足、前提条件未達成、または既解放の場合は `false`。
  bool unlockSkillNode(String nodeId) {
    final node = skillTreeDefinition[nodeId];
    if (node == null) return false;
    if (unlockedSkillIds.contains(nodeId)) return false;
    if (skillPoints < node.pointCost) return false;
    for (final prereq in node.prerequisites) {
      if (!unlockedSkillIds.contains(prereq)) return false;
    }
    skillPoints -= node.pointCost;
    unlockedSkillIds.add(nodeId);
    return true;
  }

  /// スキルポイントを冒険者Lvに基づいて再計算する。
  ///
  /// Hive v4→v5 移行時やデバッグ用途に使用。
  void recalculateSkillPoints() {
    final advLevel = jobLevels[Job.adventurer] ?? 1;
    skillPoints = availableSkillPoints(advLevel, unlockedSkillIds);
  }

  /// このノードが解放済みか。
  bool isSkillUnlocked(String nodeId) => unlockedSkillIds.contains(nodeId);

  bool addExp(int amount) {
    // レベル上限到達時はEXPを加算しない
    int lvl = jobLevels[currentJob] ?? 1;
    if (lvl >= maxLevel) return false;

    int cExp = jobExps[currentJob] ?? 0;
    cExp += amount;

    // v5: 冒険者の場合、レベルアップ前のLvを記録（スキルポイント用）
    final isAdventurer = currentJob == Job.adventurer;
    final int oldAdvLevel = isAdventurer ? lvl : 0;

    int expNext = expForLevel(lvl);
    // v1.3: pow が double.maxFinite を超えた場合のガード
    if (expNext >= double.maxFinite.toInt() || expNext <= 0) {
      expNext = double.maxFinite.toInt() ~/ 2;
    }

    bool leveledUp = false;
    while (cExp >= expNext && lvl < maxLevel) {
      cExp -= expNext;
      lvl++;
      jobLevels[currentJob] = lvl;
      expNext = expForLevel(lvl);
      if (expNext >= double.maxFinite.toInt() || expNext <= 0) {
        expNext = double.maxFinite.toInt() ~/ 2;
      }
      leveledUp = true;
    }

    // レベル上限到達時はEXPを上限値で固定
    if (lvl >= maxLevel) {
      cExp = 0;
    }

    jobExps[currentJob] = cExp;

    // v5: 冒険者のレベルアップ時にスキルポイントを付与
    if (isAdventurer && leveledUp) {
      awardSkillPointsOnLevelUp(oldAdvLevel);
    }

    return leveledUp;
  }

  Map<String, dynamic> toJson() => {
        'jobLevels': jobLevels.map((k, v) => MapEntry(k.name, v)),
        'jobExps': jobExps.map((k, v) => MapEntry(k.name, v)),
        'activeSkills': activeSkills.map((j) => j.name).toList(),
        'equippedSkills': equippedSkills.map((e) => e.toJson()).toList(),
        'currentJob': currentJob.name,
        'comboCount': comboCount,
        'coins': coins,
        'homeItems': homeItems,
        'dailyTasksCompleted': dailyTasksCompleted,
        'weeklySRankCompleted': weeklySRankCompleted,
        'lastMissionResetDate': lastMissionResetDate?.toIso8601String(),
        'nextDayTaskLimitOffset': nextDayTaskLimitOffset,
        'todayTaskLimitOffset': todayTaskLimitOffset,
        'lastRestDate': lastRestDate?.toIso8601String(),
        'totalTasksCompleted': totalTasksCompleted,
        'totalSRankCompleted': totalSRankCompleted,
        'totalARankCompleted': totalARankCompleted,
        'totalBRankCompleted': totalBRankCompleted,
        'timesWardenDefeated': timesWardenDefeated,
        'titles': titles,
        'equippedTitle': equippedTitle,
        'equippedSkin': equippedSkin,
        'characterSkin': characterSkin.toMap(),
        'gems': gems,
        'streakDays': streakDays,
        'longestStreak': longestStreak,
        'lastLoginDate': lastLoginDate?.toIso8601String(),
        'pomodoroMinutes': pomodoroMinutes,
        'pomodoroShortBreakMinutes': pomodoroShortBreakMinutes,
        'pomodoroLongBreakMinutes': pomodoroLongBreakMinutes,
        'pomodorosBeforeLongBreak': pomodorosBeforeLongBreak,
        'pomodoroStartTime': pomodoroStartTime?.toIso8601String(),
        'lastDailyComplete': lastDailyComplete?.toIso8601String(),
        'warriorDailyBuff': warriorDailyBuff,
        'streakGraceRemaining': streakGraceRemaining,
        'lastStreakGraceReset': lastStreakGraceReset?.toIso8601String(),
        'tags': tags,
        'projects': projects.map((p) => p.toJson()).toList(),
        'taskTags': taskTags,
        'taskProjects': taskProjects,
        'snoozedTasks':
            snoozedTasks.map((k, v) => MapEntry(k, v.toIso8601String())),
        'taskStreaks': taskStreaks.entries
            .map((e) => {
                  'taskId': e.key,
                  'streak': e.value.toJson(),
                })
            .toList(),
        // v5: スキルツリー
        'skillPoints': skillPoints,
        'unlockedSkillIds': unlockedSkillIds,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      jobLevels: (json['jobLevels'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(Job.values.byName(k), v as int)),
      jobExps: (json['jobExps'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(Job.values.byName(k), v as int)),
      activeSkills: (json['activeSkills'] as List<dynamic>)
          .map((e) => Job.values.byName(e as String))
          .toSet(),
      equippedSkills: (json['equippedSkills'] as List<dynamic>)
          .map((e) => EquippedSkill.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentJob: Job.values.byName(json['currentJob'] as String),
      comboCount: json['comboCount'] as int,
      coins: json['coins'] as int,
      homeItems: (json['homeItems'] as List<dynamic>).cast<String>(),
      dailyTasksCompleted: json['dailyTasksCompleted'] as int,
      weeklySRankCompleted: json['weeklySRankCompleted'] as int,
      lastMissionResetDate: json['lastMissionResetDate'] != null
          ? DateTime.parse(json['lastMissionResetDate'] as String)
          : null,
      nextDayTaskLimitOffset: json['nextDayTaskLimitOffset'] as int,
      todayTaskLimitOffset: json['todayTaskLimitOffset'] as int,
      lastRestDate: json['lastRestDate'] != null
          ? DateTime.parse(json['lastRestDate'] as String)
          : null,
      totalTasksCompleted: json['totalTasksCompleted'] as int,
      totalSRankCompleted: json['totalSRankCompleted'] as int,
      totalARankCompleted: json['totalARankCompleted'] as int,
      totalBRankCompleted: json['totalBRankCompleted'] as int,
      timesWardenDefeated: json['timesWardenDefeated'] as int,
      titles: (json['titles'] as List<dynamic>).cast<String>(),
      equippedTitle: json['equippedTitle'] as String?,
      equippedSkin: json['equippedSkin'] as String?,
      characterSkin: CharacterSkin.fromMap(
          json['characterSkin'] as Map<String, dynamic>),
      gems: json['gems'] as int,
      streakDays: json['streakDays'] as int,
      longestStreak: json['longestStreak'] as int,
      lastLoginDate: json['lastLoginDate'] != null
          ? DateTime.parse(json['lastLoginDate'] as String)
          : null,
      pomodoroMinutes: json['pomodoroMinutes'] as int,
      pomodoroShortBreakMinutes: json['pomodoroShortBreakMinutes'] as int,
      pomodoroLongBreakMinutes: json['pomodoroLongBreakMinutes'] as int,
      pomodorosBeforeLongBreak: json['pomodorosBeforeLongBreak'] as int,
      pomodoroStartTime: json['pomodoroStartTime'] != null
          ? DateTime.parse(json['pomodoroStartTime'] as String)
          : null,
      lastDailyComplete: json['lastDailyComplete'] != null
          ? DateTime.parse(json['lastDailyComplete'] as String)
          : null,
      warriorDailyBuff: json['warriorDailyBuff'] as int? ?? 0,
      streakGraceRemaining: json['streakGraceRemaining'] as int? ?? 1,
      lastStreakGraceReset: json['lastStreakGraceReset'] != null
          ? DateTime.parse(json['lastStreakGraceReset'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      projects: (json['projects'] as List<dynamic>)
          .map((e) => ProjectGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      taskTags: (json['taskTags'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as List<dynamic>).cast<String>()),
      ),
      taskProjects: (json['taskProjects'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
      snoozedTasks: (json['snoozedTasks'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, DateTime.parse(v as String)),
      ),
      taskStreaks: (json['taskStreaks'] as List<dynamic>?)
          ?.map((e) => MapEntry(
                (e as Map)['taskId'] as String,
                TaskStreak.fromJson(
                    (e['streak'] as Map).cast<String, dynamic>()),
              ))
          .fold<Map<String, TaskStreak>>(
              {}, (map, entry) => map..[entry.key] = entry.value),
      // v5: スキルツリー
      skillPoints: (json['skillPoints'] as int?) ?? 0,
      unlockedSkillIds: (json['unlockedSkillIds'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
    );
  }
}

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 3;

  static const int _formatVersion = 5;

  /// Release でも logcat に出力する簡易ロガー
  void _log(String msg, [Object? error]) {
    // ignore: avoid_print
    print('[PlayerAdapter] $msg${error != null ? ': $error' : ''}');
  }

  @override
  Player read(BinaryReader reader) {
    final version = reader.readByte();
    _log('Reading Player data (formatVersion=$version, currentVersion=$_formatVersion)');

    try {
      if (version == 5) {
        return _readV5(reader);
      }
      if (version == 4) {
        _log('Migrating v4→v5 format');
        final player = _readV4(reader);
        player.recalculateSkillPoints();
        return player;
      }
      if (version == 3) {
        _log('Migrating v3→v4 format');
        return _readV3(reader);
      }
      if (version < 1 || version > _formatVersion) {
        _log('Unknown format version $version, attempting v3 fallback');
        try {
          return _readV3(reader);
        } catch (e) {
          _log('v3 fallback also failed, returning default Player', e);
          return Player();
        }
      }
      _log('Version $version handler not found, using v3');
      return _readV3(reader);
    } catch (e, s) {
      _log('Fatal error reading Player data, returning default Player', e);
      debugPrint('[PlayerAdapter] Stack: $s');
      return Player();
    }
  }

  Player _readV5(BinaryReader reader) {
    final player = _readV4(reader);

    try {
      if (reader.availableBytes >= 4) {
        player.skillPoints = reader.readInt();
      }
    } catch (e) { _log('skillPoints read failed', e); }
    try {
      if (reader.availableBytes > 0) {
        final raw = reader.readList();
        player.unlockedSkillIds =
            (raw as List?)?.cast<String>() ?? [];
      }
    } catch (e) { _log('unlockedSkillIds read failed', e); }

    _log('Player v5 read complete (skillPoints=${player.skillPoints}, unlocked=${player.unlockedSkillIds.length})');
    return player;
  }

  Player _readV4(BinaryReader reader) {
    final player = Player();

    try {
      if (reader.availableBytes > 0) {
        player.jobLevels =
            (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 1};
      }
    } catch (e) { _log('jobLevels read failed', e); }
    try {
      if (reader.availableBytes > 0) {
        player.jobExps =
            (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 0};
      }
    } catch (e) { _log('jobExps read failed', e); }
    // v4: equippedSkills (List<EquippedSkill>)
    try {
      if (reader.availableBytes > 0) {
        final skillRawList = reader.readList();
        player.equippedSkills = (skillRawList as List?)
                ?.map((e) {
                  try {
                    return EquippedSkill.fromJson(
                        (e as Map).cast<String, dynamic>());
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<EquippedSkill>()
                .toList() ??
            [];
      }
    } catch (e) { _log('equippedSkills read failed', e); }
    // v3互換: activeSkills
    try {
      if (reader.availableBytes > 0) {
        player.activeSkills =
            (reader.readList() as List?)?.cast<Job>().toSet() ?? {};
      }
    } catch (e) { _log('activeSkills read failed', e); }
    try {
      if (reader.availableBytes > 0) {
        player.currentJob = (reader.read() as Job?) ?? Job.adventurer;
      }
    } catch (e) { _log('currentJob read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.comboCount = reader.readInt(); }
    } catch (e) { _log('comboCount read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.coins = reader.readInt(); }
    } catch (e) { _log('coins read failed', e); }
    try {
      if (reader.availableBytes > 0) {
        player.homeItems =
            (reader.readList() as List?)?.cast<String>() ?? [];
      }
    } catch (e) { _log('homeItems read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.dailyTasksCompleted = reader.readInt(); }
    } catch (e) { _log('dailyTasksCompleted read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.weeklySRankCompleted = reader.readInt(); }
    } catch (e) { _log('weeklySRankCompleted read failed', e); }
    try {
      if (reader.availableBytes > 0) { player.lastMissionResetDate = reader.read(); }
    } catch (e) { _log('lastMissionResetDate read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.nextDayTaskLimitOffset = reader.readInt(); }
    } catch (e) { _log('nextDayTaskLimitOffset read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.todayTaskLimitOffset = reader.readInt(); }
    } catch (e) { _log('todayTaskLimitOffset read failed', e); }
    try {
      if (reader.availableBytes > 0) { player.lastRestDate = reader.read(); }
    } catch (e) { _log('lastRestDate read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.totalTasksCompleted = reader.readInt(); }
    } catch (e) { _log('totalTasksCompleted read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.totalSRankCompleted = reader.readInt(); }
    } catch (e) { _log('totalSRankCompleted read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.totalARankCompleted = reader.readInt(); }
    } catch (e) { _log('totalARankCompleted read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.totalBRankCompleted = reader.readInt(); }
    } catch (e) { _log('totalBRankCompleted read failed', e); }
    try {
      if (reader.availableBytes > 0) {
        player.titles =
            (reader.readList() as List?)?.cast<String>() ?? [];
      }
    } catch (e) { _log('titles read failed', e); }
    try {
      if (reader.availableBytes > 0) { player.equippedTitle = reader.read(); }
    } catch (e) { _log('equippedTitle read failed', e); }
    try {
      if (reader.availableBytes > 0) { player.equippedSkin = reader.read(); }
    } catch (e) { _log('equippedSkin read failed', e); }
    try {
      if (reader.availableBytes >= 4) {
        player.characterSkin = CharacterSkin.fromMap(
          (reader.readMap() as Map?)?.cast<String, dynamic>() ?? {},
        );
      }
    } catch (e) { _log('characterSkin read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.gems = reader.readInt(); }
    } catch (e) { _log('gems read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.streakDays = reader.readInt(); }
    } catch (e) { _log('streakDays read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.longestStreak = reader.readInt(); }
    } catch (e) { _log('longestStreak read failed', e); }
    try {
      if (reader.availableBytes > 0) { player.lastLoginDate = reader.read(); }
    } catch (e) { _log('lastLoginDate read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.timesWardenDefeated = reader.readInt(); }
    } catch (e) { _log('timesWardenDefeated read failed', e); }
    // v4: ポモドーロ設定
    try {
      if (reader.availableBytes >= 4) { player.pomodoroMinutes = reader.readInt(); }
    } catch (e) { _log('pomodoroMinutes read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.pomodoroShortBreakMinutes = reader.readInt(); }
    } catch (e) { _log('pomodoroShortBreakMinutes read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.pomodoroLongBreakMinutes = reader.readInt(); }
    } catch (e) { _log('pomodoroLongBreakMinutes read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.pomodorosBeforeLongBreak = reader.readInt(); }
    } catch (e) { _log('pomodorosBeforeLongBreak read failed', e); }
    try {
      if (reader.availableBytes > 0) { player.pomodoroStartTime = reader.read(); }
    } catch (e) { _log('pomodoroStartTime read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.warriorDailyBuff = reader.readInt(); }
    } catch (e) { _log('warriorDailyBuff read failed', e); }
    try {
      if (reader.availableBytes >= 4) { player.streakGraceRemaining = reader.readInt(); }
    } catch (e) { _log('streakGraceRemaining read failed', e); }
    try {
      if (reader.availableBytes > 0) { player.lastStreakGraceReset = reader.read(); }
    } catch (e) { _log('lastStreakGraceReset read failed', e); }
    // v4: タグ
    try {
      if (reader.availableBytes > 0) {
        player.tags =
            (reader.readList() as List?)?.cast<String>() ?? [];
      }
    } catch (e) { _log('tags read failed', e); }
    // v4: プロジェクト
    try {
      if (reader.availableBytes > 0) {
        final projRawList = reader.readList();
        player.projects = (projRawList as List?)
                ?.map((e) {
                  try {
                    return ProjectGroup.fromJson(
                        (e as Map).cast<String, dynamic>());
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<ProjectGroup>()
                .toList() ??
            [];
      }
    } catch (e) { _log('projects read failed', e); }
    // v4: Cleric snoozedTasks
    try {
      if (reader.availableBytes > 0) {
        final snoozeRaw = reader.readMap();
        player.snoozedTasks = (snoozeRaw as Map?)?.map(
              (k, v) => MapEntry(k as String, v as DateTime),
            ) ??
            {};
      }
    } catch (e) { _log('snoozedTasks read failed', e); }
    // v4: Cleric taskStreaks
    try {
      if (reader.availableBytes > 0) {
        final streakRawList = reader.readList();
        player.taskStreaks = (streakRawList as List?)
                ?.map((e) {
                  try {
                    return MapEntry(
                          (e as Map)['taskId'] as String,
                          TaskStreak.fromJson(
                              (e['streak'] as Map).cast<String, dynamic>()),
                        );
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<MapEntry<String, TaskStreak>>()
                .fold<Map<String, TaskStreak>>(
                    {}, (map, entry) => map..[entry.key] = entry.value) ??
            {};
      }
    } catch (e) { _log('taskStreaks read failed', e); }
    // v4: wizardTags — taskTags map
    try {
      if (reader.availableBytes > 0) {
        final raw = reader.readMap();
        player.taskTags = (raw as Map?)?.map(
              (k, v) => MapEntry(k as String, (v as List).cast<String>()),
            ) ??
            {};
      }
    } catch (e) { _log('taskTags read failed', e); }
    // v4: wizardProject — taskProjects map
    try {
      if (reader.availableBytes > 0) {
        final raw = reader.readMap();
        player.taskProjects = (raw as Map?)?.cast<String, String>() ?? {};
      }
    } catch (e) { _log('taskProjects read failed', e); }

    _log('Player read complete (Lv.${player.level}, coins=${player.coins})');
    return player;
  }

  Player _readV3(BinaryReader reader) {
    final player = Player();

    void _safeRead(String field, void Function() readFn) {
      try {
        if (reader.availableBytes > 0) {
          readFn();
        }
      } catch (e) {
        _log('Field "$field" read failed (v3), using default', e);
      }
    }

    _safeRead('jobLevels', () {
      player.jobLevels =
          (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 1};
    });
    _safeRead('jobExps', () {
      player.jobExps =
          (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 0};
    });
    _safeRead('activeSkills', () {
      player.activeSkills =
          (reader.readList() as List?)?.cast<Job>().toSet() ?? {};
    });
    _safeRead('currentJob', () {
      player.currentJob = (reader.read() as Job?) ?? Job.adventurer;
    });
    _safeRead('comboCount', () {
      if (reader.availableBytes >= 4) player.comboCount = reader.readInt();
    });
    _safeRead('coins', () {
      if (reader.availableBytes >= 4) player.coins = reader.readInt();
    });
    _safeRead('homeItems', () {
      player.homeItems =
          (reader.readList() as List?)?.cast<String>() ?? [];
    });
    _safeRead('dailyTasksCompleted', () {
      if (reader.availableBytes >= 4) player.dailyTasksCompleted = reader.readInt();
    });
    _safeRead('weeklySRankCompleted', () {
      if (reader.availableBytes >= 4) player.weeklySRankCompleted = reader.readInt();
    });
    _safeRead('lastMissionResetDate', () {
      player.lastMissionResetDate = reader.read();
    });
    _safeRead('nextDayTaskLimitOffset', () {
      if (reader.availableBytes >= 4) player.nextDayTaskLimitOffset = reader.readInt();
    });
    _safeRead('todayTaskLimitOffset', () {
      if (reader.availableBytes >= 4) player.todayTaskLimitOffset = reader.readInt();
    });
    _safeRead('lastRestDate', () {
      player.lastRestDate = reader.read();
    });
    _safeRead('totalTasksCompleted', () {
      if (reader.availableBytes >= 4) player.totalTasksCompleted = reader.readInt();
    });
    _safeRead('totalSRankCompleted', () {
      if (reader.availableBytes >= 4) player.totalSRankCompleted = reader.readInt();
    });
    _safeRead('totalARankCompleted', () {
      if (reader.availableBytes >= 4) player.totalARankCompleted = reader.readInt();
    });
    _safeRead('totalBRankCompleted', () {
      if (reader.availableBytes >= 4) player.totalBRankCompleted = reader.readInt();
    });
    _safeRead('titles', () {
      player.titles =
          (reader.readList() as List?)?.cast<String>() ?? [];
    });
    _safeRead('equippedTitle', () {
      player.equippedTitle = reader.read();
    });
    _safeRead('equippedSkin', () {
      player.equippedSkin = reader.read();
    });
    _safeRead('characterSkin', () {
      player.characterSkin = CharacterSkin.fromMap(
        (reader.readMap() as Map?)?.cast<String, dynamic>() ?? {},
      );
    });
    _safeRead('gems', () {
      if (reader.availableBytes >= 4) player.gems = reader.readInt();
    });
    _safeRead('streakDays', () {
      if (reader.availableBytes >= 4) player.streakDays = reader.readInt();
    });
    _safeRead('longestStreak', () {
      if (reader.availableBytes >= 4) player.longestStreak = reader.readInt();
    });
    _safeRead('lastLoginDate', () {
      player.lastLoginDate = reader.read();
    });
    _safeRead('timesWardenDefeated', () {
      if (reader.availableBytes >= 4) player.timesWardenDefeated = reader.readInt();
    });

    return player;
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    _log('Writing Player (Lv.${obj.level}, coins=${obj.coins}, gems=${obj.gems})');
    writer.writeByte(_formatVersion);
    writer.writeMap(obj.jobLevels);
    writer.writeMap(obj.jobExps);
    // v4: equippedSkills as JSON list
    writer.writeList(obj.equippedSkills.map((e) => e.toJson()).toList());
    // v3互換: activeSkills
    writer.writeList(obj.activeSkills.toList());
    writer.write(obj.currentJob);
    writer.writeInt(obj.comboCount);
    writer.writeInt(obj.coins);
    writer.writeList(obj.homeItems);
    writer.writeInt(obj.dailyTasksCompleted);
    writer.writeInt(obj.weeklySRankCompleted);
    writer.write(obj.lastMissionResetDate);
    writer.writeInt(obj.nextDayTaskLimitOffset);
    writer.writeInt(obj.todayTaskLimitOffset);
    writer.write(obj.lastRestDate);
    writer.writeInt(obj.totalTasksCompleted);
    writer.writeInt(obj.totalSRankCompleted);
    writer.writeInt(obj.totalARankCompleted);
    writer.writeInt(obj.totalBRankCompleted);
    writer.writeList(obj.titles);
    writer.write(obj.equippedTitle);
    writer.write(obj.equippedSkin);
    writer.writeMap(obj.characterSkin.toMap());
    writer.writeInt(obj.gems);
    writer.writeInt(obj.streakDays);
    writer.writeInt(obj.longestStreak);
    writer.write(obj.lastLoginDate);
    writer.writeInt(obj.timesWardenDefeated);
    // v4: ポモドーロ設定
    writer.writeInt(obj.pomodoroMinutes);
    writer.writeInt(obj.pomodoroShortBreakMinutes);
    writer.writeInt(obj.pomodoroLongBreakMinutes);
    writer.writeInt(obj.pomodorosBeforeLongBreak);
    // v4+: pomodoroStartTime (T9: 集中の型)
    writer.write(obj.pomodoroStartTime);
    // v4+: warriorDailyBuff (T10: 武士道の極意)
    writer.writeInt(obj.warriorDailyBuff);
    // v4+: streakGraceRemaining + lastStreakGraceReset (T10: 悟りの境地)
    writer.writeInt(obj.streakGraceRemaining);
    writer.write(obj.lastStreakGraceReset);
    // v4: タグ
    writer.writeList(obj.tags);
    // v4: プロジェクト
    writer.writeList(obj.projects.map((p) => p.toJson()).toList());
    // v4: Cleric snoozedTasks
    writer.writeMap(obj.snoozedTasks);
    // v4: Cleric taskStreaks
    writer.writeList(obj.taskStreaks.entries
        .map((e) => {
              'taskId': e.key,
              'streak': e.value.toJson(),
            })
        .toList());
    // v4: wizardTags — taskTags map
    writer.writeMap(obj.taskTags);
    // v4: wizardProject — taskProjects map
    writer.writeMap(obj.taskProjects);
    // v5: スキルツリー
    writer.writeInt(obj.skillPoints);
    writer.writeList(obj.unlockedSkillIds);
  }
}
