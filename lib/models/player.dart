
import 'package:hive/hive.dart';
import 'task.dart';

class Player {
  int level;
  int currentExp;
  int expToNextLevel;

  Player({
    this.level = 1,
    this.currentExp = 0,
    this.expToNextLevel = 100, // Initial EXP requirement
  });

  Map<QuestRank, int> get questSlots {
    if (level >= 10) {
      return {QuestRank.S: 1, QuestRank.A: 3, QuestRank.B: 5};
    }
    if (level >= 5) {
      // Level 5: 1 A-Rank, 3 B-Ranks
      return {QuestRank.S: 0, QuestRank.A: 1, QuestRank.B: 3};
    }
    if (level >= 2) {
      // Level 2: 3 B-Ranks
      return {QuestRank.S: 0, QuestRank.A: 0, QuestRank.B: 3};
    }
    // Level 1: 1 B-Rank
    return {QuestRank.S: 0, QuestRank.A: 0, QuestRank.B: 1};
  }

  bool canAcceptQuest(QuestRank rank, int currentRankActiveCount) {
    final maxSlots = questSlots[rank] ?? 0;
    return currentRankActiveCount < maxSlots;
  }

  bool addExp(int amount) {
    currentExp += amount;
    bool leveledUp = false;
    while (currentExp >= expToNextLevel) {
      currentExp -= expToNextLevel;
      level++;
      expToNextLevel = (expToNextLevel * 1.5).round(); // Increase requirement by 50%
      leveledUp = true;
    }
    return leveledUp;
  }
}

class PlayerAdapter extends TypeAdapter<Player> {
  @override
  final int typeId = 3;

  @override
  Player read(BinaryReader reader) {
    return Player(
      level: reader.readInt(),
      currentExp: reader.readInt(),
      expToNextLevel: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, Player obj) {
    writer.writeInt(obj.level);
    writer.writeInt(obj.currentExp);
    writer.writeInt(obj.expToNextLevel);
  }
}
