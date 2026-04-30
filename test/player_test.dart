import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/models/player.dart';
import 'package:rpg_todo/models/task.dart';
import 'package:hive/hive.dart';
import 'dart:io';

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

    // v1.3: レベル上限テスト
    test('レベル上限（Lv.99）到達後はEXPを加算しない', () {
      final player = Player(jobLevels: {Job.adventurer: 99});
      final leveledUp = player.addExp(999999);
      expect(leveledUp, false);
      expect(player.level, 99);
    });

    test('巨大EXPを与えても無限ループしない', () {
      final player = Player();
      // 非常に大きいEXPを与えてもクラッシュ・無限ループしないこと
      final leveledUp = player.addExp(1000000000);
      expect(leveledUp, isA<bool>());
      // レベル上限を超えないこと
      expect(player.level, lessThanOrEqualTo(Player.maxLevel));
    });
  });

  // v1.3: PlayerAdapter の読み書きラウンドトリップテスト
  group('PlayerAdapter', () {
    late Box<Player> box;

    setUpAll(() async {
      // テスト用の一時ディレクトリで Hive を初期化
      final testDir = Directory('${Directory.systemTemp.path}/hive_test_${DateTime.now().millisecondsSinceEpoch}');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
      Hive.init(testDir.path);
      Hive.registerAdapter(PlayerAdapter());
      Hive.registerAdapter(JobAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<Player>('player_test_box');
    });

    tearDown(() async {
      // deleteFromDisk は内部で close を呼ぶため、事前の close は不要（二重close防止）
      await box.deleteFromDisk();
    });

    test('デフォルトPlayerの読み書きが一致する', () async {
      final original = Player();
      await box.put('p1', original);
      final restored = box.get('p1')!;
      expect(restored.level, original.level);
      expect(restored.coins, original.coins);
      expect(restored.gems, original.gems);
      expect(restored.streakDays, original.streakDays);
      expect(restored.longestStreak, original.longestStreak);
      expect(restored.currentJob, original.currentJob);
    });

    test('カスタムPlayerの読み書きが一致する（全フィールド）', () async {
      final original = Player(
        jobLevels: {Job.adventurer: 5, Job.warrior: 3},
        jobExps: {Job.adventurer: 200, Job.warrior: 100},
        activeSkills: {Job.warrior},
        currentJob: Job.warrior,
        comboCount: 3,
        coins: 500,
        homeItems: ['tent', 'sword'],
        dailyTasksCompleted: 3,
        weeklySRankCompleted: 1,
        totalTasksCompleted: 42,
        totalSRankCompleted: 2,
        totalARankCompleted: 10,
        totalBRankCompleted: 30,
        titles: ['見習い冒険者'],
        equippedTitle: '見習い冒険者',
        equippedSkin: 'skin_warrior',
        gems: 100,
        streakDays: 7,
        longestStreak: 14,
        lastLoginDate: DateTime(2026, 4, 28),
      );
      original.nextDayTaskLimitOffset = 2;
      original.todayTaskLimitOffset = 1;
      original.lastRestDate = DateTime(2026, 4, 27);
      original.lastMissionResetDate = DateTime(2026, 4, 28);

      await box.put('p2', original);
      final restored = box.get('p2')!;
      expect(restored.level, original.level);
      expect(restored.coins, original.coins);
      expect(restored.gems, original.gems);
      expect(restored.streakDays, original.streakDays);
      expect(restored.longestStreak, original.longestStreak);
      expect(restored.currentJob, original.currentJob);
      expect(restored.comboCount, original.comboCount);
      expect(restored.homeItems, original.homeItems);
      expect(restored.dailyTasksCompleted, original.dailyTasksCompleted);
      expect(restored.weeklySRankCompleted, original.weeklySRankCompleted);
      expect(restored.totalTasksCompleted, original.totalTasksCompleted);
      expect(restored.totalSRankCompleted, original.totalSRankCompleted);
      expect(restored.totalARankCompleted, original.totalARankCompleted);
      expect(restored.totalBRankCompleted, original.totalBRankCompleted);
      expect(restored.titles, original.titles);
      expect(restored.equippedTitle, original.equippedTitle);
      expect(restored.equippedSkin, original.equippedSkin);
      expect(restored.nextDayTaskLimitOffset, original.nextDayTaskLimitOffset);
      expect(restored.todayTaskLimitOffset, original.todayTaskLimitOffset);
    });
  });
}
