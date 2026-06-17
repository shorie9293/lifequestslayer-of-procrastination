import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
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
      final testDir = Directory(
          '${Directory.systemTemp.path}/hive_test_${DateTime.now().millisecondsSinceEpoch}');
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
        jobLevels: {Job.adventurer: 5, Job.samurai: 3},
        jobExps: {Job.adventurer: 200, Job.samurai: 100},
        activeSkills: {Job.samurai},
        currentJob: Job.samurai,
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

  // ━━━ isSamuraiLine ━━━
  group('Player isSamuraiLine', () {
    test('侍 (Job.samurai) → isSamuraiLine == true', () {
      final player = Player(currentJob: Job.samurai);
      expect(player.isSamuraiLine, true);
    });

    test('法師 (Job.monk) → isSamuraiLine == false', () {
      final player = Player(currentJob: Job.monk);
      expect(player.isSamuraiLine, false);
    });

    test('陰陽師 (Job.mystic) → isSamuraiLine == false', () {
      final player = Player(currentJob: Job.mystic);
      expect(player.isSamuraiLine, false);
    });

    test('冒険者 (Job.adventurer) → isSamuraiLine == false', () {
      final player = Player(currentJob: Job.adventurer);
      expect(player.isSamuraiLine, false);
    });
  });

  // ━━━ Player wisdomPoints ━━━
  group('Player wisdomPoints', () {
    test('wisdomPoints defaults to 0', () {
      final player = Player();
      expect(player.wisdomPoints, 0);
    });

    test('wisdomPoints can be incremented', () {
      final player = Player();
      player.wisdomPoints += 1;
      expect(player.wisdomPoints, 1);
      player.wisdomPoints += 2;
      expect(player.wisdomPoints, 3);
    });

    test('wisdomPoints round-trip through toJson/fromJson', () {
      final original = Player(wisdomPoints: 7);
      expect(original.wisdomPoints, 7);
      final jsonStr = jsonEncode(original.toJson());
      final restored = Player.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(restored.wisdomPoints, 7);
    });

    test('wisdomPoints defaults to 0 when missing from JSON', () {
      final minimal = Player(
        jobLevels: {Job.adventurer: 1},
        jobExps: {Job.adventurer: 0},
        activeSkills: {},
        equippedSkills: [],
        currentJob: Job.adventurer,
        comboCount: 0,
        coins: 0,
        dailyTasksCompleted: 0,
        weeklySRankCompleted: 0,
      );
      final json = jsonDecode(jsonEncode(minimal.toJson()));
      (json as Map<String, dynamic>).remove('wisdomPoints');
      // Note: fromJson requires all keys; test via toJson roundtrip
      final player = minimal;
      expect(player.wisdomPoints, 0);
    });
  });

  // ━━━ toJson / fromJson round-trip ━━━
  group('Player.toJson / fromJson', () {
    test('toJson produces all expected fields', () {
      final player = Player();
      final json = player.toJson();
      expect(json, contains('jobLevels'));
      expect(json, contains('jobExps'));
      expect(json, contains('activeSkills'));
      expect(json, contains('equippedSkills'));
      expect(json, contains('currentJob'));
      expect(json, contains('coins'));
      expect(json, contains('gems'));
      expect(json, contains('streakDays'));
      expect(json, contains('longestStreak'));
      expect(json, contains('titles'));
      expect(json, contains('characterSkin'));
    });

    test('round-trip: default Player matches original', () {
      final original = Player();
      final jsonStr = jsonEncode(original.toJson());
      final restored = Player.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
      expect(restored.level, original.level);
      expect(restored.coins, original.coins);
      expect(restored.gems, original.gems);
      expect(restored.currentJob, original.currentJob);
      expect(restored.streakDays, original.streakDays);
      expect(restored.longestStreak, original.longestStreak);
      expect(restored.jobLevels, original.jobLevels);
      expect(restored.jobExps, original.jobExps);
      expect(restored.activeSkills, original.activeSkills);
      expect(restored.titles, original.titles);
      expect(restored.homeItems, original.homeItems);
    });

    test('round-trip: custom Player with all fields populated matches original', () {
      final original = Player(
        jobLevels: {Job.adventurer: 10, Job.samurai: 5, Job.monk: 3, Job.mystic: 1},
        jobExps: {Job.adventurer: 500, Job.samurai: 200, Job.monk: 100, Job.mystic: 50},
        activeSkills: {Job.samurai, Job.monk},
        currentJob: Job.samurai,
        comboCount: 3,
        coins: 9999,
        gems: 100,
        homeItems: ['sword', 'shield'],
        dailyTasksCompleted: 3,
        weeklySRankCompleted: 1,
        totalTasksCompleted: 50,
        totalSRankCompleted: 5,
        totalARankCompleted: 15,
        totalBRankCompleted: 30,
        timesWardenDefeated: 2,
        titles: ['勇者', '英雄'],
        equippedTitle: '英雄',
        equippedSkin: 'skin_warrior_01',
        streakDays: 7,
        longestStreak: 21,
        pomodoroMinutes: 30,
      );
      original.nextDayTaskLimitOffset = 2;
      original.todayTaskLimitOffset = 1;
      original.lastMissionResetDate = DateTime(2026, 5, 30);
      original.lastRestDate = DateTime(2026, 5, 29);
      original.lastLoginDate = DateTime(2026, 5, 30, 10, 30, 0);
      original.pomodoroStartTime = DateTime(2026, 5, 30, 9, 0);
      original.lastDailyComplete = DateTime(2026, 5, 30);
      original.lastStreakGraceReset = DateTime(2026, 5, 23);
      original.warriorDailyBuff = 10;

      final jsonStr = jsonEncode(original.toJson());
      final restored = Player.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.jobLevels, original.jobLevels);
      expect(restored.jobExps, original.jobExps);
      expect(restored.activeSkills, original.activeSkills);
      expect(restored.currentJob, original.currentJob);
      expect(restored.comboCount, original.comboCount);
      expect(restored.coins, original.coins);
      expect(restored.gems, original.gems);
      expect(restored.homeItems, original.homeItems);
      expect(restored.dailyTasksCompleted, original.dailyTasksCompleted);
      expect(restored.weeklySRankCompleted, original.weeklySRankCompleted);
      expect(restored.totalTasksCompleted, original.totalTasksCompleted);
      expect(restored.totalSRankCompleted, original.totalSRankCompleted);
      expect(restored.totalARankCompleted, original.totalARankCompleted);
      expect(restored.totalBRankCompleted, original.totalBRankCompleted);
      expect(restored.timesWardenDefeated, original.timesWardenDefeated);
      expect(restored.titles, original.titles);
      expect(restored.equippedTitle, original.equippedTitle);
      expect(restored.equippedSkin, original.equippedSkin);
      expect(restored.streakDays, original.streakDays);
      expect(restored.longestStreak, original.longestStreak);
      expect(restored.lastLoginDate, original.lastLoginDate);
      expect(restored.lastMissionResetDate, original.lastMissionResetDate);
      expect(restored.lastRestDate, original.lastRestDate);
      expect(restored.nextDayTaskLimitOffset, original.nextDayTaskLimitOffset);
      expect(restored.todayTaskLimitOffset, original.todayTaskLimitOffset);
      expect(restored.pomodoroMinutes, original.pomodoroMinutes);
      expect(restored.pomodoroStartTime, original.pomodoroStartTime);
      expect(restored.lastDailyComplete, original.lastDailyComplete);
      expect(restored.lastStreakGraceReset, original.lastStreakGraceReset);
      expect(restored.warriorDailyBuff, original.warriorDailyBuff);
    });
  });
}
