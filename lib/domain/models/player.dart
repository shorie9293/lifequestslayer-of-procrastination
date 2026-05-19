import 'dart:math';
import 'package:hive/hive.dart';
import 'task.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';

enum Job {
  warrior,
  cleric,
  wizard,
  adventurer,
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
  Set<Job> activeSkills; // Mastery skills equipped
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
  List<String> titles;
  String? equippedTitle;
  String? equippedSkin; // 追加: 装備中のスキンID（旧ショップスキン）
  CharacterSkin characterSkin; // 追加: 5部位カスタマイズ
  int gems; // プレミアム通貨（課金で取得）

  // --- ストリーク（連続ログイン） ---
  int streakDays;
  int longestStreak;
  DateTime? lastLoginDate;

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
    List<String>? titles,
    this.equippedTitle,
    this.equippedSkin,
    CharacterSkin? characterSkin,
    this.gems = 0,
    this.streakDays = 0,
    this.longestStreak = 0,
    this.lastLoginDate,
  })  : characterSkin = characterSkin ?? CharacterSkin(), jobLevels = jobLevels ?? {Job.adventurer: 1},
        jobExps = jobExps ?? {Job.adventurer: 0},
        activeSkills = activeSkills ?? {},
        homeItems = homeItems ?? [],
        titles = titles ?? [];

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

  static const int _formatVersion = 3;

  @override
  Player read(BinaryReader reader) {
    final version = reader.readByte();
    if (version < 1 || version > _formatVersion) {
      throw HiveError('未知のデータバージョン: $version (対応: 1〜$_formatVersion)');
    }
    return _readV2(reader);
  }

  Player _readV2(BinaryReader reader) {
    // デフォルト値で初期化。古いフォーマット(v1,v2)のデータでも
    // 各フィールドを availableBytes でガードしながら安全に読み取る。
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

    return player;
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer.writeByte(_formatVersion);
    writer.writeMap(obj.jobLevels);
    writer.writeMap(obj.jobExps);
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
  }
}
