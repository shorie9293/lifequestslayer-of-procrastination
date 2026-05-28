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
        EquippedSkill(skill: JobSkill.warriorCombo),
      ]);
      expect(player.equippedSkills.length, 2);
      expect(player.equippedSkills[0].skill, JobSkill.roninSlots);
      expect(player.equippedSkills[1].skill, JobSkill.warriorCombo);
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
          EquippedSkill(skill: JobSkill.warriorBushido),
        ],
        pomodoroMinutes: 30,
        tags: ['仕事', 'プライベート'],
        projects: [ProjectGroup(name: '引越し計画')],
      );
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.equippedSkills.length, 2);
      expect(restored.equippedSkills[0].skill, JobSkill.roninSlots);
      expect(restored.equippedSkills[1].skill, JobSkill.warriorBushido);
      expect(restored.pomodoroMinutes, 30);
      expect(restored.tags, ['仕事', 'プライベート']);
      expect(restored.projects.length, 1);
      expect(restored.projects[0].name, '引越し計画');
    });

    test('Hive v4 round-trip: backward compat from v3 defaults', () async {
      // v3 had activeSkills (Set<Job>). v4 migrates to equippedSkills.
      final player = Player();
      // Deprecated activeSkills still accessible
      player.activeSkills.add(Job.warrior);
      await box.put('p', player);
      final restored = box.get('p')!;
      // activeSkills is deprecated but should survive round-trip
      expect(restored.activeSkills, contains(Job.warrior));
    });
  });

  group('activeSkills deprecation', () {
    test('activeSkills is marked deprecated (compile-time check)', () {
      // This test verifies that activeSkills still works for backward compat
      final player = Player();
      // ignore: deprecated_member_use
      expect(player.activeSkills, isEmpty);
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.warrior);
      // ignore: deprecated_member_use
      expect(player.activeSkills, contains(Job.warrior));
    });
  });
}
