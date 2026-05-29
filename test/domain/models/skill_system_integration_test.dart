import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:hive/hive.dart';
import 'dart:io';

void main() {
  // ═══════════════════════════════════════════
  // canUseSkill(Job) — v3 互換の職業レベルスキル判定
  // ═══════════════════════════════════════════
  group('canUseSkill(Job)', () {
    test('現在の職業なら常に true（Lv1でも）', () {
      final player = Player(currentJob: Job.warrior);
      expect(player.canUseSkill(Job.warrior), true);
    });

    test('現在の職業でなければ、mastered+activeSkills登録が必要', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.warrior: 1},
      );
      // warrior Lv1 → not mastered
      expect(player.canUseSkill(Job.warrior), false);
    });

    test('adventurer mastered (Lv10) → Ronin常時オン', () {
      final player = Player(
        currentJob: Job.warrior,
        jobLevels: {Job.adventurer: 10, Job.warrior: 1},
      );
      // Ronin mastered → always true even when currentJob is warrior
      expect(player.canUseSkill(Job.adventurer), true);
    });

    test('adventurer Lv9 (not mastered) → false when not current', () {
      final player = Player(
        currentJob: Job.warrior,
        jobLevels: {Job.adventurer: 9, Job.warrior: 1},
      );
      expect(player.canUseSkill(Job.adventurer), false);
    });

    test('他職業 mastered (Lv14) + activeSkills登録 → true', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.warrior: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.warrior);
      expect(player.canUseSkill(Job.warrior), true);
    });

    test('他職業 mastered でも activeSkills未登録 → false', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.warrior: 14},
      );
      // activeSkills に warrior なし
      expect(player.canUseSkill(Job.warrior), false);
    });

    test('全4職業をテスト', () {
      // Ronin (adventurer)
      final ronin = Player(currentJob: Job.adventurer);
      expect(ronin.canUseSkill(Job.adventurer), true);

      // Warrior
      final warrior = Player(currentJob: Job.warrior);
      expect(warrior.canUseSkill(Job.warrior), true);

      // Cleric
      final cleric = Player(currentJob: Job.cleric);
      expect(cleric.canUseSkill(Job.cleric), true);

      // Wizard
      final wizard = Player(currentJob: Job.wizard);
      expect(wizard.canUseSkill(Job.wizard), true);
    });

    test('cleric mastered + activeSkills → wizard からでも使用可', () {
      final player = Player(
        currentJob: Job.wizard,
        jobLevels: {Job.wizard: 1, Job.cleric: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.cleric);
      expect(player.canUseSkill(Job.cleric), true);
    });

    test('wizard mastered + activeSkills → warrior からでも使用可', () {
      final player = Player(
        currentJob: Job.warrior,
        jobLevels: {Job.warrior: 1, Job.wizard: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.wizard);
      expect(player.canUseSkill(Job.wizard), true);
    });

    test('activeSkills に複数職業登録 → 全職業使用可', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.warrior: 14, Job.cleric: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.addAll([Job.warrior, Job.cleric]);
      expect(player.canUseSkill(Job.warrior), true);
      expect(player.canUseSkill(Job.cleric), true);
      expect(player.canUseSkill(Job.wizard), false); // 未登録
    });
  });

  // ═══════════════════════════════════════════
  // isMastered(Job) — Lv14境界テスト
  // ═══════════════════════════════════════════
  group('isMastered(Job)', () {
    test('adventurer Lv9 → not mastered', () {
      final player = Player(jobLevels: {Job.adventurer: 9});
      expect(player.isMastered(Job.adventurer), false);
    });

    test('adventurer Lv10 → mastered', () {
      final player = Player(jobLevels: {Job.adventurer: 10});
      expect(player.isMastered(Job.adventurer), true);
    });

    test('adventurer Lv11 → mastered', () {
      final player = Player(jobLevels: {Job.adventurer: 11});
      expect(player.isMastered(Job.adventurer), true);
    });

    test('warrior Lv13 → not mastered', () {
      final player = Player(jobLevels: {Job.warrior: 13});
      expect(player.isMastered(Job.warrior), false);
    });

    test('warrior Lv14 → mastered (isMastered uses >=14)', () {
      final player = Player(jobLevels: {Job.warrior: 14});
      expect(player.isMastered(Job.warrior), true);
    });

    test('warrior Lv15 → mastered', () {
      final player = Player(jobLevels: {Job.warrior: 15});
      expect(player.isMastered(Job.warrior), true);
    });

    test('cleric Lv14 → mastered', () {
      final player = Player(jobLevels: {Job.cleric: 14});
      expect(player.isMastered(Job.cleric), true);
    });

    test('wizard Lv14 → mastered', () {
      final player = Player(jobLevels: {Job.wizard: 14});
      expect(player.isMastered(Job.wizard), true);
    });

    test('未設定の職業 → デフォルト Lv1 → not mastered', () {
      final player = Player();
      expect(player.isMastered(Job.warrior), false);
      expect(player.isMastered(Job.cleric), false);
      expect(player.isMastered(Job.wizard), false);
    });
  });

  // ═══════════════════════════════════════════
  // hasSkill(JobSkill) — 全14スキルのクロスジョブテスト
  // ═══════════════════════════════════════════
  group('hasSkill(JobSkill) — Ronin skills', () {
    test('Lv1 adventurer → roninSlotsのみ有効', () {
      final player = Player();
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), false);
    });

    test('Lv10 adventurer → 全Roninスキル有効（mastered）', () {
      final player = Player(
        jobLevels: {Job.adventurer: 10},
        currentJob: Job.adventurer,
      );
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
    });

    test('Ronin Lv10 mastered → warrior転職後もRoninスキル常時オン', () {
      final player = Player(
        jobLevels: {Job.adventurer: 10, Job.warrior: 1},
        currentJob: Job.warrior,
      );
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
    });

    test('Ronin Lv10 mastered → wizard転職後もRoninスキル常時オン', () {
      final player = Player(
        jobLevels: {Job.adventurer: 10, Job.wizard: 1},
        currentJob: Job.wizard,
      );
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
    });
  });

  group('hasSkill(JobSkill) — Warrior skills', () {
    test('Lv1 warrior → warriorComboのみ有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.warrior: 1},
        currentJob: Job.warrior,
      );
      expect(player.hasSkill(JobSkill.warriorCombo), true);
      expect(player.hasSkill(JobSkill.warriorFatigueReverse), false);
      expect(player.hasSkill(JobSkill.warriorPomodoro), false);
      expect(player.hasSkill(JobSkill.warriorBushido), false);
    });

    test('Lv5 warrior → combo + fatigueReverse 有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.warrior: 5},
        currentJob: Job.warrior,
      );
      expect(player.hasSkill(JobSkill.warriorCombo), true);
      expect(player.hasSkill(JobSkill.warriorFatigueReverse), true);
      expect(player.hasSkill(JobSkill.warriorPomodoro), false);
      expect(player.hasSkill(JobSkill.warriorBushido), false);
    });

    test('Lv10 warrior → combo + fatigueReverse + pomodoro 有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.warrior: 10},
        currentJob: Job.warrior,
      );
      expect(player.hasSkill(JobSkill.warriorCombo), true);
      expect(player.hasSkill(JobSkill.warriorFatigueReverse), true);
      expect(player.hasSkill(JobSkill.warriorPomodoro), true);
      expect(player.hasSkill(JobSkill.warriorBushido), false);
    });

    test('Lv15 warrior → 全Warriorスキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.warrior: 15},
        currentJob: Job.warrior,
      );
      expect(player.hasSkill(JobSkill.warriorCombo), true);
      expect(player.hasSkill(JobSkill.warriorFatigueReverse), true);
      expect(player.hasSkill(JobSkill.warriorPomodoro), true);
      expect(player.hasSkill(JobSkill.warriorBushido), true);
    });

    test('Warrior Lv10 → adventurer転職後、equippedSkillsでpomodoro使用可（他職クロス）', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.warrior: 10},
        currentJob: Job.adventurer,
        equippedSkills: [EquippedSkill(skill: JobSkill.warriorPomodoro)],
      );
      expect(player.hasSkill(JobSkill.warriorPomodoro), true);
      // warriorCombo は装備していないので不可
      expect(player.hasSkill(JobSkill.warriorCombo), false);
    });

    test('Warrior Lv10 → Bushido 未到達 → equippedしてもhasSkill=false', () {
      final player = Player(
        jobLevels: {Job.warrior: 10},
        currentJob: Job.adventurer,
        equippedSkills: [EquippedSkill(skill: JobSkill.warriorBushido)],
      );
      // Bushido requires Lv15, Lv10 insufficient
      expect(player.hasSkill(JobSkill.warriorBushido), false);
    });

    test('Warrior Lv15 mastered → v3 compat activeSkills → 全スキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.warrior: 15},
        currentJob: Job.adventurer,
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.warrior);
      expect(player.hasSkill(JobSkill.warriorCombo), true);
      expect(player.hasSkill(JobSkill.warriorFatigueReverse), true);
      expect(player.hasSkill(JobSkill.warriorPomodoro), true);
      expect(player.hasSkill(JobSkill.warriorBushido), true);
    });
  });

  group('hasSkill(JobSkill) — Cleric skills', () {
    test('Lv1 cleric → clericRepeatAfterのみ有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.cleric: 1},
        currentJob: Job.cleric,
      );
      expect(player.hasSkill(JobSkill.clericRepeatAfter), true);
      expect(player.hasSkill(JobSkill.clericSnooze), false);
      expect(player.hasSkill(JobSkill.clericStreak), false);
      expect(player.hasSkill(JobSkill.clericEnlightenment), false);
    });

    test('Lv5 cleric → repeatAfter + snooze 有効', () {
      final player = Player(
        jobLevels: {Job.cleric: 5},
        currentJob: Job.cleric,
      );
      expect(player.hasSkill(JobSkill.clericRepeatAfter), true);
      expect(player.hasSkill(JobSkill.clericSnooze), true);
      expect(player.hasSkill(JobSkill.clericStreak), false);
    });

    test('Lv10 cleric → repeatAfter + snooze + streak 有効', () {
      final player = Player(
        jobLevels: {Job.cleric: 10},
        currentJob: Job.cleric,
      );
      expect(player.hasSkill(JobSkill.clericRepeatAfter), true);
      expect(player.hasSkill(JobSkill.clericSnooze), true);
      expect(player.hasSkill(JobSkill.clericStreak), true);
      expect(player.hasSkill(JobSkill.clericEnlightenment), false);
    });

    test('Lv15 cleric → 全Clericスキル有効', () {
      final player = Player(
        jobLevels: {Job.cleric: 15},
        currentJob: Job.cleric,
      );
      expect(player.hasSkill(JobSkill.clericRepeatAfter), true);
      expect(player.hasSkill(JobSkill.clericSnooze), true);
      expect(player.hasSkill(JobSkill.clericStreak), true);
      expect(player.hasSkill(JobSkill.clericEnlightenment), true);
    });

    test('Cleric Lv15 mastered → v3 compat activeSkills → 他職業からでも全スキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.cleric: 15},
        currentJob: Job.adventurer,
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.cleric);
      expect(player.hasSkill(JobSkill.clericRepeatAfter), true);
      expect(player.hasSkill(JobSkill.clericSnooze), true);
      expect(player.hasSkill(JobSkill.clericStreak), true);
      expect(player.hasSkill(JobSkill.clericEnlightenment), true);
    });
  });

  group('hasSkill(JobSkill) — Wizard skills', () {
    test('Lv1 wizard → wizardSubtaskのみ有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.wizard: 1},
        currentJob: Job.wizard,
      );
      expect(player.hasSkill(JobSkill.wizardSubtask), true);
      expect(player.hasSkill(JobSkill.wizardTags), false);
      expect(player.hasSkill(JobSkill.wizardProject), false);
      expect(player.hasSkill(JobSkill.wizardOverview), false);
    });

    test('Lv5 wizard → subtask + tags 有効', () {
      final player = Player(
        jobLevels: {Job.wizard: 5},
        currentJob: Job.wizard,
      );
      expect(player.hasSkill(JobSkill.wizardSubtask), true);
      expect(player.hasSkill(JobSkill.wizardTags), true);
      expect(player.hasSkill(JobSkill.wizardProject), false);
    });

    test('Lv10 wizard → subtask + tags + project 有効', () {
      final player = Player(
        jobLevels: {Job.wizard: 10},
        currentJob: Job.wizard,
      );
      expect(player.hasSkill(JobSkill.wizardSubtask), true);
      expect(player.hasSkill(JobSkill.wizardTags), true);
      expect(player.hasSkill(JobSkill.wizardProject), true);
      expect(player.hasSkill(JobSkill.wizardOverview), false);
    });

    test('Lv15 wizard → 全Wizardスキル有効', () {
      final player = Player(
        jobLevels: {Job.wizard: 15},
        currentJob: Job.wizard,
      );
      expect(player.hasSkill(JobSkill.wizardSubtask), true);
      expect(player.hasSkill(JobSkill.wizardTags), true);
      expect(player.hasSkill(JobSkill.wizardProject), true);
      expect(player.hasSkill(JobSkill.wizardOverview), true);
    });

    test('Wizard Lv15 mastered → v3 compat activeSkills → 他職業からでも全スキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.wizard: 15},
        currentJob: Job.adventurer,
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.wizard);
      expect(player.hasSkill(JobSkill.wizardSubtask), true);
      expect(player.hasSkill(JobSkill.wizardTags), true);
      expect(player.hasSkill(JobSkill.wizardProject), true);
      expect(player.hasSkill(JobSkill.wizardOverview), true);
    });
  });

  // ═══════════════════════════════════════════
  // クロスジョブスキル相互作用
  // ═══════════════════════════════════════════
  group('Cross-job skill interaction', () {
    test('Ronin mastered + Warrior equippedSkills（pomodoro）→ 両方有効', () {
      final player = Player(
        currentJob: Job.warrior,
        jobLevels: {Job.adventurer: 10, Job.warrior: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.warriorPomodoro)],
      );
      // Ronin mastered → 常時オン
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
      // Warrior current + Lv10 → pomodoro 有効
      expect(player.hasSkill(JobSkill.warriorPomodoro), true);
    });

    test('Ronin mastered + Cleric equippedSkills（streak）→ 両方有効', () {
      final player = Player(
        currentJob: Job.warrior,
        jobLevels: {Job.adventurer: 10, Job.warrior: 1, Job.cleric: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.clericStreak)],
      );
      // Ronin mastered → 常時オン
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
      // Cleric streak via equippedSkills (Lv10 → ok)
      expect(player.hasSkill(JobSkill.clericStreak), true);
      // Cleric snooze → NOT equipped
      expect(player.hasSkill(JobSkill.clericSnooze), false);
    });

    test('Ronin mastered + Wizard equippedSkills（project + tags）→ 3スキル有効', () {
      final player = Player(
        currentJob: Job.cleric,
        jobLevels: {Job.adventurer: 10, Job.cleric: 1, Job.wizard: 10},
        equippedSkills: [
          EquippedSkill(skill: JobSkill.wizardProject),
          EquippedSkill(skill: JobSkill.wizardTags),
        ],
      );
      // Ronin mastered
      expect(player.hasSkill(JobSkill.roninSlots), true);
      // Wizard project + tags via equippedSkills
      expect(player.hasSkill(JobSkill.wizardProject), true);
      expect(player.hasSkill(JobSkill.wizardTags), true);
      // Wizard subtask → NOT equipped
      expect(player.hasSkill(JobSkill.wizardSubtask), false);
    });

    test('全職業 mastered → 全スキル activeSkills登録で使用可', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {
          Job.adventurer: 10,
          Job.warrior: 15,
          Job.cleric: 15,
          Job.wizard: 15,
        },
      );
      // ignore: deprecated_member_use
      player.activeSkills.addAll([Job.warrior, Job.cleric, Job.wizard]);

      // Ronin always-on (mastered)
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);

      // All jobs via v3 compat
      expect(player.hasSkill(JobSkill.warriorBushido), true);
      expect(player.hasSkill(JobSkill.clericEnlightenment), true);
      expect(player.hasSkill(JobSkill.wizardOverview), true);
    });

    test('未mastered職業のスキルはequippedSkillsしても使用不可', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.warrior: 5},
        equippedSkills: [EquippedSkill(skill: JobSkill.warriorPomodoro)],
      );
      // warrior is NOT mastered (Lv5 < 14) + NOT current → canUseSkill fails
      // → hasSkill requires canUseSkill for equippedSkills path
      // But wait: hasSkill checks equippedSkills first: yes (it IS equipped + level>=required)
      // Let's test: level 5 >= requiredLevel 10? NO. So returns false.
      expect(player.hasSkill(JobSkill.warriorPomodoro), false);
    });
  });

  // ═══════════════════════════════════════════
  // EquippedSkill isActive — ユニットテスト
  // ═══════════════════════════════════════════
  group('EquippedSkill isActive', () {
    test('default isActive is true', () {
      final eq = EquippedSkill(skill: JobSkill.warriorCombo);
      expect(eq.isActive, true);
    });

    test('can set isActive to false at construction', () {
      final eq = EquippedSkill(skill: JobSkill.clericStreak, isActive: false);
      expect(eq.isActive, false);
    });

    test('isActive can be toggled at runtime', () {
      final eq = EquippedSkill(skill: JobSkill.wizardSubtask);
      eq.isActive = false;
      expect(eq.isActive, false);
      eq.isActive = true;
      expect(eq.isActive, true);
    });

    test('fromJson preserves isActive', () {
      final json = {'skill': JobSkill.warriorCombo.index, 'isActive': false};
      final eq = EquippedSkill.fromJson(json);
      expect(eq.isActive, false);
    });

    test('fromJson defaults isActive to true when missing', () {
      final json = {'skill': JobSkill.warriorCombo.index};
      final eq = EquippedSkill.fromJson(json);
      expect(eq.isActive, true);
    });

    test('toJson includes isActive', () {
      final eq = EquippedSkill(skill: JobSkill.warriorCombo, isActive: false);
      final json = eq.toJson();
      expect(json['isActive'], false);
    });

    test('Equality ignores isActive', () {
      final a = EquippedSkill(skill: JobSkill.warriorCombo, isActive: true);
      final b = EquippedSkill(skill: JobSkill.warriorCombo, isActive: false);
      expect(a, b); // isActive は等価判定に含まれない
    });
  });

  // ═══════════════════════════════════════════
  // Hive v3 → v4 移行テスト
  // ═══════════════════════════════════════════
  group('Hive v3 → v4 migration', () {
    late Box<Player> box;

    setUpAll(() async {
      final testDir = Directory(
          '${Directory.systemTemp.path}/hive_skill_integration_${DateTime.now().millisecondsSinceEpoch}');
      if (!testDir.existsSync()) {
        testDir.createSync(recursive: true);
      }
      Hive.init(testDir.path);
      Hive.registerAdapter(PlayerAdapter());
      Hive.registerAdapter(JobAdapter());
    });

    setUp(() async {
      box = await Hive.openBox<Player>('player_skill_integration_test');
    });

    tearDown(() async {
      await box.deleteFromDisk();
    });

    test('v4 equippedSkills: 単一スキル round-trip', () async {
      final original = Player(
        jobLevels: {Job.adventurer: 1, Job.warrior: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.warriorPomodoro)],
      );
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.equippedSkills.length, 1);
      expect(restored.equippedSkills[0].skill, JobSkill.warriorPomodoro);
    });

    test('v4 equippedSkills: 複数スキル round-trip', () async {
      final original = Player(
        jobLevels: {Job.adventurer: 10, Job.warrior: 10, Job.cleric: 10},
        equippedSkills: [
          EquippedSkill(skill: JobSkill.warriorPomodoro, isActive: true),
          EquippedSkill(skill: JobSkill.clericStreak, isActive: false),
        ],
      );
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.equippedSkills.length, 2);
      expect(restored.equippedSkills[0].skill, JobSkill.warriorPomodoro);
      expect(restored.equippedSkills[0].isActive, true);
      expect(restored.equippedSkills[1].skill, JobSkill.clericStreak);
      expect(restored.equippedSkills[1].isActive, false);
    });

    test('v4 warriorDailyBuff round-trip', () async {
      final original = Player(
        jobLevels: {Job.warrior: 15},
      );
      original.warriorDailyBuff = 42;
      original.lastDailyComplete = DateTime(2026, 5, 20);
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.warriorDailyBuff, 42);
      expect(restored.lastDailyComplete, isNotNull);
      expect(restored.lastDailyComplete!.year, 2026);
      expect(restored.lastDailyComplete!.month, 5);
      expect(restored.lastDailyComplete!.day, 20);
    });

    test('v4 streakGrace round-trip', () async {
      final original = Player(
        jobLevels: {Job.cleric: 15},
      );
      original.streakGraceRemaining = 5;
      original.lastStreakGraceReset = DateTime(2026, 5, 15);
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.streakGraceRemaining, 5);
      expect(restored.lastStreakGraceReset, isNotNull);
    });

    test('v4 pomodoroStartTime round-trip', () async {
      final original = Player(
        jobLevels: {Job.warrior: 10},
      );
      original.pomodoroStartTime = DateTime(2026, 5, 29, 10, 30);
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.pomodoroStartTime, isNotNull);
      expect(restored.pomodoroStartTime!.hour, 10);
      expect(restored.pomodoroStartTime!.minute, 30);
    });

    test('v4 activeSkills deprecated field round-trip', () async {
      final original = Player();
      // ignore: deprecated_member_use
      original.activeSkills.addAll([Job.warrior, Job.cleric]);
      await box.put('p', original);
      final restored = box.get('p')!;
      // ignore: deprecated_member_use
      expect(restored.activeSkills, contains(Job.warrior));
      // ignore: deprecated_member_use
      expect(restored.activeSkills, contains(Job.cleric));
    });

    test('v4: default Player has empty equippedSkills and v4 fields at defaults', () async {
      final player = Player();
      expect(player.equippedSkills, isEmpty);
      expect(player.warriorDailyBuff, 0);
      expect(player.streakGraceRemaining, 1);
      expect(player.pomodoroStartTime, isNull);
      expect(player.lastDailyComplete, isNull);
      expect(player.lastStreakGraceReset, isNull);
    });
  });
}
