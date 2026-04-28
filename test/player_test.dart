import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/models/player.dart';
import 'package:rpg_todo/models/task.dart';

// クエストスロット数はゲーム設計として以下を仕様とする:
//   Lv1: B×1
//   Lv2: B×2
//   Lv5: A×1, B×3
//   Lv10: S×1, A×2, B×3
Player _playerAtAdventurerLevel(int level) =>
    Player(jobLevels: {Job.adventurer: level});

void main() {
  group('Player Quest Slots', () {
    test('Lv1: Bランク×1のみ', () {
      final player = _playerAtAdventurerLevel(1);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 0);
      expect(slots[QuestRank.A], 0);
      expect(slots[QuestRank.B], 1);
      expect(player.canAcceptQuest(QuestRank.B, 0), true);
      expect(player.canAcceptQuest(QuestRank.B, 1), false);
    });

    test('Lv2: Bランク×2', () {
      final player = _playerAtAdventurerLevel(2);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 0);
      expect(slots[QuestRank.A], 0);
      expect(slots[QuestRank.B], 2);
    });

    test('Lv5: Aランク×1, Bランク×3', () {
      final player = _playerAtAdventurerLevel(5);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 0);
      expect(slots[QuestRank.A], 1);
      expect(slots[QuestRank.B], 3);
      expect(player.canAcceptQuest(QuestRank.A, 0), true);
      expect(player.canAcceptQuest(QuestRank.A, 1), false);
    });

    test('Lv10: Sランク×1, Aランク×2, Bランク×3', () {
      final player = _playerAtAdventurerLevel(10);
      final slots = player.questSlots;
      expect(slots[QuestRank.S], 1);
      expect(slots[QuestRank.A], 2);
      expect(slots[QuestRank.B], 3);
    });
  });

  group('Player canAcceptQuest', () {
    test('スロット上限に達していると受注不可', () {
      final player = _playerAtAdventurerLevel(1);
      expect(player.canAcceptQuest(QuestRank.B, 0), true);
      expect(player.canAcceptQuest(QuestRank.B, 1), false);
    });
  });

  group('Player addExp', () {
    test('EXP獲得でレベルアップする', () {
      final player = Player();
      expect(player.level, 1);
      final leveledUp = player.addExp(50); // Lv1→2は50EXP
      expect(leveledUp, true);
      expect(player.level, 2);
    });

    test('EXP不足ではレベルアップしない', () {
      final player = Player();
      final leveledUp = player.addExp(49);
      expect(leveledUp, false);
      expect(player.level, 1);
    });
  });
}
