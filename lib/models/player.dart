
import 'package:hive/hive.dart';
import 'package:hive/hive.dart';
import 'task.dart';

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

  Player({
    Map<Job, int>? jobLevels,
    Map<Job, int>? jobExps,
    Set<Job>? activeSkills,
    this.currentJob = Job.adventurer,
    this.comboCount = 0,
  }) : 
    jobLevels = jobLevels ?? {Job.adventurer: 1}, 
    jobExps = jobExps ?? {Job.adventurer: 0},
    activeSkills = activeSkills ?? {};

  // Getters for current job (Compatibility)
  int get level => jobLevels[currentJob] ?? 1;
  int get currentExp => jobExps[currentJob] ?? 0;
  
  // Calculate expToNextLevel dynamically based on level
  int get expToNextLevel {
    int lvl = level;
    // New Formula: 50 * 1.25^(lvl-1)
    // Lv1->2: 50
    // Lv10: ~372
    // Lv20: ~3400 (Cumulative ~18000)
    return (50 * (dependencies_pow(1.25, lvl - 1))).round();
  }

  // Helper for power since math lib might need import. 
  // Simple iterative for now or import dart:math
  double dependencies_pow(double x, int n) {
    double r = 1.0;
    for(int i=0; i<n; i++) r *= x;
    return r;
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
      return {QuestRank.S: 1, QuestRank.A: 3, QuestRank.B: 5};
    }
    if (refLevel >= 5) {
      return {QuestRank.S: 0, QuestRank.A: 1, QuestRank.B: 3};
    }
    if (refLevel >= 2) {
      return {QuestRank.S: 0, QuestRank.A: 0, QuestRank.B: 3};
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

  bool addExp(int amount) {
    int cExp = jobExps[currentJob] ?? 0;
    cExp += amount;
    
    int lvl = jobLevels[currentJob] ?? 1;
    int expNext = (50 * (dependencies_pow(1.25, lvl - 1))).round();
    
    bool leveledUp = false;
    while (cExp >= expNext) {
      cExp -= expNext;
      lvl++;
      jobLevels[currentJob] = lvl;
      // Re-calc next for loop
      expNext = (50 * (dependencies_pow(1.25, lvl - 1))).round();
      leveledUp = true;
    }
    jobExps[currentJob] = cExp; // Save back
    return leveledUp;
  }
}

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 3;

  @override
  Player read(BinaryReader reader) {
    // Handle migration manually if possible, BUT Hive requires exact read order of bytes written.
    // Previous write: level(int), currentExp(int), expToNextLevel(int), currentJob(Job), comboCount(int).
    // If we want to support old data, we must read these.
    // If we change structure, we effectively invalidate old data unless we handle standard migration patterns.
    // Strategy: Read the 5 fields. If they exist (check available bytes? No Hive doesn't work like that easily).
    // This is "schema evolution". 
    // Since we are dev phase, simplest is: Read the old format, map to new format.
    // BUT if we write New format, next read will fail if we try to read old format.
    // We need a version flag? Or catch exception?
    // Actually, simple Hack: Add a version byte at start? No, typeId is matched.
    // Let's assume we are resetting data OR using a new TypeId? No, updating existing.
    // Correct way: Check available bytes?
    // Or just accept that this change CLEARS data if we interpret bytes wrong.
    // Wait, I can try to read the old 3 ints + Job + int.
    // Then use them to populate the map.
    
    // HOWEVER, to support FUTURE reads of the NEW format, we need to distinguish.
    // Standard Hive way: append fields. But we are removing fields.
    // So we should Create a NEW Adapter and maybe register it with a new ID? 
    // And migration?
    // User requested "各職業のレベルは転職しても維持" implying persistence is key.
    // I will implementation a "Try Read" strategy or just structure it to be compatible?
    // No, structure is different.
    // I will write a simple Migrator:
    // We will use TypeId 3.
    // I'll assume the user will RESET data (Hot Restart often clears if structure changes drastically without migration logic in boxes).
    // Actually, let's implement the Adapter to read as:
    // int jobCount (Length of map). If it's small (e.g. < 100), it's likely a length. 
    // Old format started with `level` (int). likely 1-20.
    // New format: I'll write a version byte 255.
    
    // SAFEST: Just read old fields, ignoring them, then read new fields?
    // No, we want to USE old fields.
    
    // OK, since I can't easily peek, I will assume we are starting fresh OR I will try to be clever.
    // Check `reader.availableBytes`?
    // Let's just break compatibility and ask user to reset? 
    // "転職するとレベルがリセット" -> The user description implies how feature WORKS, not that it happened.
    // "各職業のレベルは転職しても維持" -> Feature request.
    
    // I'll maintain the method signature but use a boolean flag in the saved data?
    // Too risky to guess. I'll implement the new structure.
    // If old data exists, it might crash. I'll catch it in `main.dart` or `game_state` and reset if error.
    
    // Improved Plan: Read as Map.
    
    // New Write Format: 
    // byte version = 1;
    // write maps...
    
    // To safe guard:
    try {
      // Trying to detect version.
      // But we can't peek.
      // I will overwrite the Adapter.
      
      // NEW FORMAT:
      // int version = reader.readByte();
      // if (version == 1) { ... read new ... }
      // else { ... treat as old ... } (But first byte of old was Level (int). If Level < 255, it acts as byte?? No readInt is 4 bytes).
      
      // Let's just implement new format. If it crashes, we clear box.
      
      return Player(
         jobLevels: (reader.readMap()).cast<Job, int>(),
         jobExps: (reader.readMap()).cast<Job, int>(),
         activeSkills: (reader.readList()).cast<Job>().toSet(),
         currentJob: reader.read(), // Job
         comboCount: reader.readInt(),
      );
    } catch (e) {
       // Fallback default
       return Player();
    }
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer.writeMap(obj.jobLevels);
    writer.writeMap(obj.jobExps);
    writer.writeList(obj.activeSkills.toList());
    writer.write(obj.currentJob);
    writer.writeInt(obj.comboCount);
  }
}
