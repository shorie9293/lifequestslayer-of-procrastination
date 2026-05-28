import 'dart:math';
import 'package:hive/hive.dart';
import 'task.dart';
import 'skill_slot.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';

enum Job {
  warrior,
  cleric,
  wizard,
  adventurer,
}

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

  /// RoninスキルはJobLv>=10、他職業スキルはJobLv>=15 で mastered。
  bool isMastered(int jobLevel) {
    if (job == Job.adventurer) return jobLevel >= 10;
    return jobLevel >= 15;
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

  // --- v4: タグ・プロジェクト ---
  List<String> tags;
  List<ProjectGroup> projects;

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
    List<String>? tags,
    List<ProjectGroup>? projects,
    List<EquippedSkill>? equippedSkills,
  })  : characterSkin = characterSkin ?? const CharacterSkin(), jobLevels = jobLevels ?? {Job.adventurer: 1},
        jobExps = jobExps ?? {Job.adventurer: 0},
        activeSkills = activeSkills ?? {},
        homeItems = homeItems ?? [],
        titles = titles ?? [],
        tags = tags ?? [],
        projects = projects ?? [],
        equippedSkills = equippedSkills ?? [];

  // Getters for current job (Compatibility)
  int get level => jobLevels[currentJob] ?? 1;
  int get currentExp => jobExps[currentJob] ?? 0;

  // Calculate expToNextLevel dynamically based on level
  int get expToNextLevel {
    // Formula: 50 * 1.4^(lvl-1)  Lv1→50, Lv10→~1034, Lv20→~29914
    return (50 * pow(1.4, level - 1)).round();
  }

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

  // v1.3: レベル上限（powオーバーフロー防止）
  static const int maxLevel = 99;

  bool addExp(int amount) {
    // レベル上限到達時はEXPを加算しない
    int lvl = jobLevels[currentJob] ?? 1;
    if (lvl >= maxLevel) return false;

    int cExp = jobExps[currentJob] ?? 0;
    cExp += amount;

    int expNext = (50 * pow(1.4, lvl - 1)).round();
    // v1.3: pow が double.maxFinite を超えた場合のガード
    if (expNext >= double.maxFinite.toInt() || expNext <= 0) {
      expNext = double.maxFinite.toInt() ~/ 2;
    }

    bool leveledUp = false;
    while (cExp >= expNext && lvl < maxLevel) {
      cExp -= expNext;
      lvl++;
      jobLevels[currentJob] = lvl;
      expNext = (50 * pow(1.4, lvl - 1)).round();
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
    return leveledUp;
  }
}

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 3;

  static const int _formatVersion = 4;

  @override
  Player read(BinaryReader reader) {
    final version = reader.readByte();
    if (version == 4) {
      return _readV4(reader);
    }
    if (version == 3) {
      return _readV3(reader);
    }
    if (version < 1 || version > _formatVersion) {
      try {
        return _readV3(reader);
      } catch (_) {
        return Player();
      }
    }
    return _readV3(reader);
  }

  Player _readV4(BinaryReader reader) {
    final player = Player();

    if (reader.availableBytes > 0) {
      player.jobLevels =
          (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 1};
    }
    if (reader.availableBytes > 0) {
      player.jobExps =
          (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 0};
    }
    // v4: equippedSkills (List<EquippedSkill>) を読み取る
    if (reader.availableBytes > 0) {
      final skillRawList = reader.readList();
      player.equippedSkills = (skillRawList as List?)
              ?.map((e) => EquippedSkill.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList() ??
          [];
    }
    // v3互換: activeSkills も読み取る（後方互換）
    if (reader.availableBytes > 0) {
      player.activeSkills =
          (reader.readList() as List?)?.cast<Job>().toSet() ?? {};
    }
    if (reader.availableBytes > 0) {
      player.currentJob = (reader.read() as Job?) ?? Job.adventurer;
    }
    if (reader.availableBytes >= 4) {
      player.comboCount = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.coins = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.homeItems =
          (reader.readList() as List?)?.cast<String>() ?? [];
    }
    if (reader.availableBytes >= 4) {
      player.dailyTasksCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.weeklySRankCompleted = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.lastMissionResetDate = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.nextDayTaskLimitOffset = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.todayTaskLimitOffset = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.lastRestDate = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.totalTasksCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.totalSRankCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.totalARankCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.totalBRankCompleted = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.titles =
          (reader.readList() as List?)?.cast<String>() ?? [];
    }
    if (reader.availableBytes > 0) {
      player.equippedTitle = reader.read();
    }
    // v3 fields
    if (reader.availableBytes > 0) {
      player.equippedSkin = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.characterSkin = CharacterSkin.fromMap(
        (reader.readMap() as Map?)?.cast<String, dynamic>() ?? {},
      );
    }
    if (reader.availableBytes >= 4) {
      player.gems = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.streakDays = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.longestStreak = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.lastLoginDate = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.timesWardenDefeated = reader.readInt();
    }
    // v4: ポモドーロ設定
    if (reader.availableBytes >= 4) {
      player.pomodoroMinutes = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.pomodoroShortBreakMinutes = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.pomodoroLongBreakMinutes = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.pomodorosBeforeLongBreak = reader.readInt();
    }
    // v4: タグ
    if (reader.availableBytes > 0) {
      player.tags =
          (reader.readList() as List?)?.cast<String>() ?? [];
    }
    // v4: プロジェクト
    if (reader.availableBytes > 0) {
      final projRawList = reader.readList();
      player.projects = (projRawList as List?)
              ?.map((e) => ProjectGroup.fromJson(
                  (e as Map).cast<String, dynamic>()))
              .toList() ??
          [];
    }

    return player;
  }

  Player _readV3(BinaryReader reader) {
    final player = Player();

    if (reader.availableBytes > 0) {
      player.jobLevels =
          (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 1};
    }
    if (reader.availableBytes > 0) {
      player.jobExps =
          (reader.readMap() as Map?)?.cast<Job, int>() ?? {Job.adventurer: 0};
    }
    if (reader.availableBytes > 0) {
      player.activeSkills =
          (reader.readList() as List?)?.cast<Job>().toSet() ?? {};
    }
    if (reader.availableBytes > 0) {
      player.currentJob = (reader.read() as Job?) ?? Job.adventurer;
    }
    if (reader.availableBytes >= 4) {
      player.comboCount = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.coins = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.homeItems =
          (reader.readList() as List?)?.cast<String>() ?? [];
    }
    if (reader.availableBytes >= 4) {
      player.dailyTasksCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.weeklySRankCompleted = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.lastMissionResetDate = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.nextDayTaskLimitOffset = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.todayTaskLimitOffset = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.lastRestDate = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.totalTasksCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.totalSRankCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.totalARankCompleted = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.totalBRankCompleted = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.titles =
          (reader.readList() as List?)?.cast<String>() ?? [];
    }
    if (reader.availableBytes > 0) {
      player.equippedTitle = reader.read();
    }

    // 以下、v3以降で追加されたフィールド（元からavailableBytesチェックあり）
    if (reader.availableBytes > 0) {
      player.equippedSkin = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.characterSkin = CharacterSkin.fromMap(
        (reader.readMap() as Map?)?.cast<String, dynamic>() ?? {},
      );
    }
    if (reader.availableBytes >= 4) {
      player.gems = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.streakDays = reader.readInt();
    }
    if (reader.availableBytes >= 4) {
      player.longestStreak = reader.readInt();
    }
    if (reader.availableBytes > 0) {
      player.lastLoginDate = reader.read();
    }
    if (reader.availableBytes >= 4) {
      player.timesWardenDefeated = reader.readInt();
    }

    return player;
  }

  @override
  void write(BinaryWriter writer, Player obj) {
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
    // v4: タグ
    writer.writeList(obj.tags);
    // v4: プロジェクト
    writer.writeList(obj.projects.map((p) => p.toJson()).toList());
  }
}
