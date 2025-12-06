import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/models/player.dart';
import 'package:rpg_todo/models/task.dart';

void main() {
  group('Player Quest Slots', () {
    test('Level 1: 1 B-Rank', () {
      final player = Player(level: 1);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 0);
      expect(slots[QuestRank.A], 0);
      expect(slots[QuestRank.B], 1);
      expect(player.canAcceptQuest(QuestRank.B, 0), true);
      expect(player.canAcceptQuest(QuestRank.B, 1), false);
    });

    test('Level 2: 3 B-Ranks', () {
      final player = Player(level: 2);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 0);
      expect(slots[QuestRank.A], 0);
      expect(slots[QuestRank.B], 3);
    });

    test('Level 5: 1 A-Rank, 3 B-Ranks', () {
      final player = Player(level: 5);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 0);
      expect(slots[QuestRank.A], 1);
      expect(slots[QuestRank.B], 3);
      
      expect(player.canAcceptQuest(QuestRank.A, 0), true);
      expect(player.canAcceptQuest(QuestRank.A, 1), false);
    });

    test('Level 10: 1 S, 3 A, 5 B (1-3-5 Rule)', () {
      final player = Player(level: 10);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 1);
      expect(slots[QuestRank.A], 3);
      expect(slots[QuestRank.B], 5);
    });
  });
}
