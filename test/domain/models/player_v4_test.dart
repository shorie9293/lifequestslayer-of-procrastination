import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  group('Player v4 new fields', () {
    test('default equippedSkills is empty', () {
      final player = Player();
      expect(player.equippedSkills, isEmpty);
    });

    test('can set equippedSkills', () {
      final player = Player(equippedSkills: [
        EquippedSkill(skill: JobSkill.roninSlots),
        EquippedSkill(skill: JobSkill.samuraiCombo),
      ]);
      expect(player.equippedSkills.length, 2);
      expect(player.equippedSkills[0].skill, JobSkill.roninSlots);
      expect(player.equippedSkills[1].skill, JobSkill.samuraiCombo);
    });

    test('default pomodoro settings', () {
      final player = Player();
      expect(player.pomodoroMinutes, 25);
      expect(player.pomodoroShortBreakMinutes, 5);
      expect(player.pomodoroLongBreakMinutes, 15);
      expect(player.pomodorosBeforeLongBreak, 4);
    });

    test('default tags and projects are empty', () {
      final player = Player();
      expect(player.tags, isEmpty);
      expect(player.projects, isEmpty);
    });

    test('can set tags', () {
      final player = Player(tags: ['神事', '開発', '勉強']);
      expect(player.tags, ['神事', '開発', '勉強']);
    });

    test('can set projects', () {
      final projects = [
        ProjectGroup(name: '魔導書翻訳', taskIds: ['t1']),
        ProjectGroup(name: '町興し', taskIds: ['t2', 't3']),
      ];
      final player = Player(projects: projects);
      expect(player.projects.length, 2);
      expect(player.projects[0].name, '魔導書翻訳');
      expect(player.projects[1].name, '町興し');
    });
  });

  group('PlayerAdapter v4', () {
    late Box<Player> box;

    setUpAll(() async {
      final testDir = Directory(
          '${Directory.systemTemp.path}/hive_test_v4_${DateTime.now().millisecondsSinceEpoch}');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
      Hive.init(testDir.path);
      Hive.registerAdapter(PlayerAdapter());
      Hive.registerAdapter(JobAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<Player>('player_v4_test');
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    test('Hive v4 round-trip: default Player survives write/read', () async {
      final original = Player();
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.equippedSkills, original.equippedSkills);
      expect(restored.pomodoroMinutes, original.pomodoroMinutes);
      expect(restored.pomodoroShortBreakMinutes, original.pomodoroShortBreakMinutes);
      expect(restored.pomodoroLongBreakMinutes, original.pomodoroLongBreakMinutes);
      expect(restored.pomodorosBeforeLongBreak, original.pomodorosBeforeLongBreak);
      expect(restored.tags, original.tags);
      expect(restored.projects, original.projects);
      expect(restored.level, original.level);
      expect(restored.coins, original.coins);
    });

    test('Hive v4 round-trip: equippedSkills with multiple skills', () async {
      final original = Player(
        equippedSkills: [
          EquippedSkill(skill: JobSkill.roninSlots),
          EquippedSkill(skill: JobSkill.samuraiBushido),
        ],
        pomodoroMinutes: 30,
        tags: ['仕事', 'プライベート'],
        projects: [ProjectGroup(name: '引越し計画')],
      );
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.equippedSkills.length, 2);
      expect(restored.equippedSkills[0].skill, JobSkill.roninSlots);
      expect(restored.equippedSkills[1].skill, JobSkill.samuraiBushido);
      expect(restored.pomodoroMinutes, 30);
      expect(restored.tags, ['仕事', 'プライベート']);
      expect(restored.projects.length, 1);
      expect(restored.projects[0].name, '引越し計画');
    });

    test('Hive v4 round-trip: backward compat from v3 defaults', () async {
      // v3 had activeSkills (Set<Job>). v4 migrates to equippedSkills.
      final player = Player();
      // Deprecated activeSkills still accessible
      player.activeSkills.add(Job.samurai);
      await box.put('p', player);
      final restored = box.get('p')!;
      // activeSkills is deprecated but should survive round-trip
      expect(restored.activeSkills, contains(Job.samurai));
    });
  });

  group('activeSkills deprecation', () {
    test('activeSkills is marked deprecated (compile-time check)', () {
      // This test verifies that activeSkills still works for backward compat
      final player = Player();
      // ignore: deprecated_member_use
      expect(player.activeSkills, isEmpty);
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.samurai);
      // ignore: deprecated_member_use
      expect(player.activeSkills, contains(Job.samurai));
    });
  });

  group('hasSkill(JobSkill)', () {
    test('default player (Lv1 adventurer) has roninSlots', () {
      final player = Player(); // Lv1 adventurer, default
      expect(player.hasSkill(JobSkill.roninSlots), true);
    });

    test('default player (Lv1 adventurer) does NOT have roninRepeatTask', () {
      final player = Player(); // Lv1 adventurer, default
      expect(player.hasSkill(JobSkill.roninRepeatTask), false);
    });

    test('Lv10 adventurer (mastered) has roninRepeatTask', () {
      final player = Player(
        jobLevels: {Job.adventurer: 10},
      );
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
    });

    test('Lv9 adventurer does NOT have roninRepeatTask', () {
      final player = Player(
        jobLevels: {Job.adventurer: 9},
        currentJob: Job.adventurer,
      );
      expect(player.hasSkill(JobSkill.roninRepeatTask), false);
    });

    test('Lv10 adventurer has roninRepeatTask even when currentJob is warrior', () {
      final player = Player(
        jobLevels: {Job.adventurer: 10, Job.samurai: 1},
        currentJob: Job.samurai,
      );
      // Ronin skills are always on when adventurer is mastered
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
      expect(player.hasSkill(JobSkill.roninSlots), true);
    });

    test('Lv1 warrior does NOT have warriorBushido (requires Lv15)', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 1},
        currentJob: Job.samurai,
      );
      expect(player.hasSkill(JobSkill.samuraiBushido), false);
    });

    test('equippedSkills grants specific skill when level requirement is met', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 10},
        currentJob: Job.adventurer,
        equippedSkills: [
          EquippedSkill(skill: JobSkill.samuraiPomodoro), // requires Lv10
        ],
      );
      expect(player.hasSkill(JobSkill.samuraiPomodoro), true);
    });

    test('equippedSkills does NOT grant skill if level is insufficient', () {
      final player = Player(
        jobLevels: {Job.samurai: 5},
        currentJob: Job.adventurer,
        equippedSkills: [
          EquippedSkill(skill: JobSkill.samuraiBushido), // requires Lv15
        ],
      );
      expect(player.hasSkill(JobSkill.samuraiBushido), false);
    });

    test('v3 compat: isMastered + activeSkills grants all job skills', () {
      final player = Player(
        jobLevels: {Job.monk: 15},
        currentJob: Job.adventurer,
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.monk);
      // Monk Lv15 mastered → all Cleric skills available via v3 compat
      expect(player.hasSkill(JobSkill.monkRepeatAfter), true);
      expect(player.hasSkill(JobSkill.monkEnlightenment), true);
    });
  });
}
