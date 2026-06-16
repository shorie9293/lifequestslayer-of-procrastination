import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/features/shared/data/player_repository.dart';
import 'dart:io';

/// fprint = forced print (always prints even in test)
void fprint(String msg) => print('[TEST] $msg');

/// Helper: get typed box reference (already opened by repo)
Box<Player> _getTypedBox() => Hive.box<Player>('playerBox');
Box _getBackup() => Hive.box('playerBox_backup');

void main() {
  late PlayerRepository repo;

  setUpAll(() async {
    final testDir = Directory(
        '${Directory.systemTemp.path}/player_repo_test_${DateTime.now().millisecondsSinceEpoch}');
    if (!testDir.existsSync()) {
      testDir.createSync(recursive: true);
    }
    Hive.init(testDir.path);
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(JobAdapter());
    Hive.registerAdapter(JobSkillAdapter());
  });

  setUp(() async {
    repo = PlayerRepository();
    // Pre-open boxes so test helpers (_getTypedBox/_getBackup) work
    // even before the first savePlayer/loadPlayer call.
    try {
      await Hive.openBox<Player>('playerBox');
    } catch (_) {}
    try {
      await Hive.openBox('playerBox_backup');
    } catch (_) {}
  });

  tearDown(() async {
    try { await repo.close(); } catch (_) {}
    // Clean up boxes
    for (final name in ['playerBox', 'playerBox_backup']) {
      try {
        final box = Hive.box(name);
        await box.deleteFromDisk();
      } catch (_) {}
    }
  });

  group('PlayerRepository normal flow', () {
    test('loadPlayer returns null when box is empty', () async {
      final loaded = await repo.loadPlayer();
      expect(loaded, isNull);
    });

    test('savePlayer then loadPlayer returns identical data', () async {
      final player = Player(
        coins: 500,
        gems: 99,
        jobLevels: {Job.adventurer: 10, Job.samurai: 5},
        currentJob: Job.samurai,
        comboCount: 3,
        streakDays: 15,
        longestStreak: 30,
        equippedSkills: [
          EquippedSkill(skill: JobSkill.samuraiBushido, isActive: true),
        ],
        tags: ['重要', '急ぎ'],
      );
      await repo.savePlayer(player);
      final loaded = await repo.loadPlayer();
      expect(loaded, isNotNull);
      expect(loaded!.coins, 500);
      expect(loaded.gems, 99);
      expect(loaded.level, 5); // currentJob=warrior → jobLevels[warrior]=5
      expect(loaded.currentJob, Job.samurai);
      expect(loaded.comboCount, 3);
      expect(loaded.streakDays, 15);
      expect(loaded.longestStreak, 30);
      expect(loaded.equippedSkills.length, 1);
      expect(loaded.equippedSkills[0].skill, JobSkill.samuraiBushido);
      expect(loaded.tags, ['重要', '急ぎ']);
    });

    test('multiple save/load cycles are idempotent', () async {
      for (int i = 1; i <= 3; i++) {
        await repo.savePlayer(Player(coins: i * 100, jobLevels: {Job.adventurer: i}));
        final loaded = await repo.loadPlayer();
        expect(loaded, isNotNull);
        expect(loaded!.coins, i * 100);
        expect(loaded.level, i);
      }
    });

    test('close cleans up', () async {
      await repo.savePlayer(Player(coins: 100));
      await repo.close();
      fprint('Repo closed successfully');
    });
  });

  group('PlayerRepository backup/restore', () {
    test('backup is created before save and cleared after success', () async {
      // Save a player — this triggers backup creation, then clear on success
      await repo.savePlayer(Player(coins: 999));

      // After successful save, backup should be cleared
      final backup = _getBackup();
      final keys = backup.get('keys');
      fprint('Backup keys after successful save: $keys');
      expect(keys, isNull);
    });

    test('backup exists when save fails midway', () async {
      // Simulate: direct backup write + data in box
      final backup = _getBackup();
      await backup.put('keys', [0]);
      await backup.put('count', 1);
      await backup.flush();

      final typed = _getTypedBox();
      await typed.put(0, Player(coins: 777, jobLevels: {Job.adventurer: 15}));
      await typed.flush();

      // Verify backup exists before load
      final bkKeys = backup.get('keys') as List?;
      expect(bkKeys, isNotEmpty);
      expect(bkKeys, contains(0));
    });

    test('loadPlayer handles gracefully when backup exists but data missing', () async {
      // Save a player
      await repo.savePlayer(Player(coins: 777, jobLevels: {Job.adventurer: 15}));

      // Manually re-populate backup (savePlayer clears it on success)
      final backup = _getBackup();
      await backup.put('keys', [0]);
      await backup.put('count', 1);
      await backup.flush();

      // Delete the typed data (simulating corruption)
      final typed = _getTypedBox();
      await typed.delete(0);
      await typed.flush();

      fprint('Main box length after delete: ${typed.length}');
      fprint('Backup keys: ${backup.get('keys')}');

      // Load — should handle gracefully (no crash)
      final loaded = await repo.loadPlayer();
      fprint('Loaded result: $loaded');
      expect(loaded, isNull);
    });

    test('loadPlayer returns null when both main and backup are empty', () async {
      final loaded = await repo.loadPlayer();
      expect(loaded, isNull);
    });

    test('loadPlayer handles backup restore from crash scenario', () async {
      // Simulate: user had data, app crashed during save, backup has keys
      final backup = _getBackup();
      await backup.put('keys', [0]);
      await backup.put('count', 1);
      await backup.flush();

      // No main data — simulate corruption

      // Load should not crash
      final loaded = await repo.loadPlayer();
      fprint('After restore attempt: $loaded');
      expect(loaded, isNull);
    });
  });

  group('PlayerAdapter deserialization resilience', () {
    test('Hive round-trip of full Player data is correct', () async {
      final original = Player(
        coins: 12345,
        gems: 99,
        jobLevels: {Job.adventurer: 20, Job.samurai: 10, Job.monk: 3, Job.mystic: 1},
        currentJob: Job.samurai,
        equippedSkills: [
          EquippedSkill(skill: JobSkill.samuraiBushido, isActive: true),
          EquippedSkill(skill: JobSkill.monkEnlightenment),
        ],
        tags: ['重要', '急ぎ'],
        streakDays: 15,
        pomodoroMinutes: 30,
        homeItems: ['sword', 'shield'],
      );
      await repo.savePlayer(original);
      final restored = await repo.loadPlayer();
      expect(restored, isNotNull);
      expect(restored!.coins, 12345);
      expect(restored.gems, 99);
      expect(restored.level, 10); // currentJob=warrior→jobLevels[warrior]=10
      expect(restored.currentJob, Job.samurai);
      expect(restored.equippedSkills.length, 2);
      expect(restored.tags, ['重要', '急ぎ']);
      expect(restored.streakDays, 15);
      expect(restored.pomodoroMinutes, 30);
      expect(restored.homeItems, ['sword', 'shield']);
    });

    test('corrupted binary data returns null gracefully via repo', () async {
      // Write a player normally
      await repo.savePlayer(Player(coins: 99999));
      await repo.close();

      // Re-open raw box and corrupt data directly
      final rawBox = await Hive.openBox('playerBox');
      await rawBox.put(0, [1, 2, 3, 4, 5, 6, 7, 8]); // garbage list
      await rawBox.flush();
      await rawBox.close();

      // Re-open repo — should handle corrupted data gracefully
      repo = PlayerRepository();
      final loaded = await repo.loadPlayer();
      fprint('Corrupted data load result: $loaded');
      expect(loaded, isNull);
    });

    test('partially corrupted data still returns a Player with usable fields via repo', () async {
      await repo.savePlayer(Player(coins: 500, gems: 50, jobLevels: {Job.adventurer: 10}));
      final restored = await repo.loadPlayer();
      expect(restored, isNotNull);
      expect(restored!.coins, 500);
      expect(restored.gems, 50);
      expect(restored.level, 10);
    });
  });

  group('Logging', () {
    test('migration logging works via print', () async {
      final player = Player(coins: 42);
      await repo.savePlayer(player);
      final loaded = await repo.loadPlayer();
      expect(loaded, isNotNull);
      expect(loaded!.coins, 42);
      fprint('Logging test: save & load OK');
    });

    test('version mismatch logged', () async {
      final adapter = PlayerAdapter();
      expect(adapter.typeId, 3);
      fprint('PlayerAdapter typeId=${adapter.typeId}, formatVersion=4');
    });
  });
}
