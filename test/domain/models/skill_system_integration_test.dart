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
      final player = Player(currentJob: Job.samurai);
      expect(player.canUseSkill(Job.samurai), true);
    });

    test('現在の職業でなければ、mastered+activeSkills登録が必要', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.samurai: 1},
      );
      // warrior Lv1 → not mastered
      expect(player.canUseSkill(Job.samurai), false);
    });

    test('adventurer mastered (Lv10) → Ronin常時オン', () {
      final player = Player(
        currentJob: Job.samurai,
        jobLevels: {Job.adventurer: 10, Job.samurai: 1},
      );
      // Ronin mastered → always true even when currentJob is warrior
      expect(player.canUseSkill(Job.adventurer), true);
    });

    test('adventurer Lv9 (not mastered) → false when not current', () {
      final player = Player(
        currentJob: Job.samurai,
        jobLevels: {Job.adventurer: 9, Job.samurai: 1},
      );
      expect(player.canUseSkill(Job.adventurer), false);
    });

    test('他職業 mastered (Lv14) + activeSkills登録 → true', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.samurai: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.samurai);
      expect(player.canUseSkill(Job.samurai), true);
    });

    test('他職業 mastered でも activeSkills未登録 → false', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.samurai: 14},
      );
      // activeSkills に warrior なし
      expect(player.canUseSkill(Job.samurai), false);
    });

    test('全4職業をテスト', () {
      // Ronin (adventurer)
      final ronin = Player(currentJob: Job.adventurer);
      expect(ronin.canUseSkill(Job.adventurer), true);

      // Warrior
      final warrior = Player(currentJob: Job.samurai);
      expect(warrior.canUseSkill(Job.samurai), true);

      // Cleric
      final cleric = Player(currentJob: Job.monk);
      expect(cleric.canUseSkill(Job.monk), true);

      // Wizard
      final wizard = Player(currentJob: Job.mystic);
      expect(wizard.canUseSkill(Job.mystic), true);
    });

    test('cleric mastered + activeSkills → wizard からでも使用可', () {
      final player = Player(
        currentJob: Job.mystic,
        jobLevels: {Job.mystic: 1, Job.monk: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.monk);
      expect(player.canUseSkill(Job.monk), true);
    });

    test('wizard mastered + activeSkills → warrior からでも使用可', () {
      final player = Player(
        currentJob: Job.samurai,
        jobLevels: {Job.samurai: 1, Job.mystic: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.mystic);
      expect(player.canUseSkill(Job.mystic), true);
    });

    test('activeSkills に複数職業登録 → 全職業使用可', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.samurai: 14, Job.monk: 14},
      );
      // ignore: deprecated_member_use
      player.activeSkills.addAll([Job.samurai, Job.monk]);
      expect(player.canUseSkill(Job.samurai), true);
      expect(player.canUseSkill(Job.monk), true);
      expect(player.canUseSkill(Job.mystic), false); // 未登録
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
      final player = Player(jobLevels: {Job.samurai: 13});
      expect(player.isMastered(Job.samurai), false);
    });

    test('warrior Lv14 → mastered (isMastered uses >=14)', () {
      final player = Player(jobLevels: {Job.samurai: 14});
      expect(player.isMastered(Job.samurai), true);
    });

    test('warrior Lv15 → mastered', () {
      final player = Player(jobLevels: {Job.samurai: 15});
      expect(player.isMastered(Job.samurai), true);
    });

    test('cleric Lv14 → mastered', () {
      final player = Player(jobLevels: {Job.monk: 14});
      expect(player.isMastered(Job.monk), true);
    });

    test('wizard Lv14 → mastered', () {
      final player = Player(jobLevels: {Job.mystic: 14});
      expect(player.isMastered(Job.mystic), true);
    });

    test('未設定の職業 → デフォルト Lv1 → not mastered', () {
      final player = Player();
      expect(player.isMastered(Job.samurai), false);
      expect(player.isMastered(Job.monk), false);
      expect(player.isMastered(Job.mystic), false);
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
        jobLevels: {Job.adventurer: 10, Job.samurai: 1},
        currentJob: Job.samurai,
      );
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
    });

    test('Ronin Lv10 mastered → wizard転職後もRoninスキル常時オン', () {
      final player = Player(
        jobLevels: {Job.adventurer: 10, Job.mystic: 1},
        currentJob: Job.mystic,
      );
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
    });
  });

  group('hasSkill(JobSkill) — Warrior skills', () {
    test('Lv1 warrior → warriorComboのみ有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 1},
        currentJob: Job.samurai,
      );
      expect(player.hasSkill(JobSkill.samuraiCombo), true);
      expect(player.hasSkill(JobSkill.samuraiFatigueReverse), false);
      expect(player.hasSkill(JobSkill.samuraiPomodoro), false);
      expect(player.hasSkill(JobSkill.samuraiBushido), false);
    });

    test('Lv5 warrior → combo + fatigueReverse 有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 5},
        currentJob: Job.samurai,
      );
      expect(player.hasSkill(JobSkill.samuraiCombo), true);
      expect(player.hasSkill(JobSkill.samuraiFatigueReverse), true);
      expect(player.hasSkill(JobSkill.samuraiPomodoro), false);
      expect(player.hasSkill(JobSkill.samuraiBushido), false);
    });

    test('Lv10 warrior → combo + fatigueReverse + pomodoro 有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 10},
        currentJob: Job.samurai,
      );
      expect(player.hasSkill(JobSkill.samuraiCombo), true);
      expect(player.hasSkill(JobSkill.samuraiFatigueReverse), true);
      expect(player.hasSkill(JobSkill.samuraiPomodoro), true);
      expect(player.hasSkill(JobSkill.samuraiBushido), false);
    });

    test('Lv15 warrior → 全Warriorスキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 15},
        currentJob: Job.samurai,
      );
      expect(player.hasSkill(JobSkill.samuraiCombo), true);
      expect(player.hasSkill(JobSkill.samuraiFatigueReverse), true);
      expect(player.hasSkill(JobSkill.samuraiPomodoro), true);
      expect(player.hasSkill(JobSkill.samuraiBushido), true);
    });

    test('Warrior Lv10 → adventurer転職後、equippedSkillsでpomodoro使用可（他職クロス）', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 10},
        currentJob: Job.adventurer,
        equippedSkills: [EquippedSkill(skill: JobSkill.samuraiPomodoro)],
      );
      expect(player.hasSkill(JobSkill.samuraiPomodoro), true);
      // warriorCombo は装備していないので不可
      expect(player.hasSkill(JobSkill.samuraiCombo), false);
    });

    test('Warrior Lv10 → Bushido 未到達 → equippedしてもhasSkill=false', () {
      final player = Player(
        jobLevels: {Job.samurai: 10},
        currentJob: Job.adventurer,
        equippedSkills: [EquippedSkill(skill: JobSkill.samuraiBushido)],
      );
      // Bushido requires Lv15, Lv10 insufficient
      expect(player.hasSkill(JobSkill.samuraiBushido), false);
    });

    test('Warrior Lv15 mastered → v3 compat activeSkills → 全スキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.samurai: 15},
        currentJob: Job.adventurer,
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.samurai);
      expect(player.hasSkill(JobSkill.samuraiCombo), true);
      expect(player.hasSkill(JobSkill.samuraiFatigueReverse), true);
      expect(player.hasSkill(JobSkill.samuraiPomodoro), true);
      expect(player.hasSkill(JobSkill.samuraiBushido), true);
    });
  });

  group('hasSkill(JobSkill) — Cleric skills', () {
    test('Lv1 cleric → clericRepeatAfterのみ有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.monk: 1},
        currentJob: Job.monk,
      );
      expect(player.hasSkill(JobSkill.monkRepeatAfter), true);
      expect(player.hasSkill(JobSkill.monkSnooze), false);
      expect(player.hasSkill(JobSkill.monkStreak), false);
      expect(player.hasSkill(JobSkill.monkEnlightenment), false);
    });

    test('Lv5 cleric → repeatAfter + snooze 有効', () {
      final player = Player(
        jobLevels: {Job.monk: 5},
        currentJob: Job.monk,
      );
      expect(player.hasSkill(JobSkill.monkRepeatAfter), true);
      expect(player.hasSkill(JobSkill.monkSnooze), true);
      expect(player.hasSkill(JobSkill.monkStreak), false);
    });

    test('Lv10 cleric → repeatAfter + snooze + streak 有効', () {
      final player = Player(
        jobLevels: {Job.monk: 10},
        currentJob: Job.monk,
      );
      expect(player.hasSkill(JobSkill.monkRepeatAfter), true);
      expect(player.hasSkill(JobSkill.monkSnooze), true);
      expect(player.hasSkill(JobSkill.monkStreak), true);
      expect(player.hasSkill(JobSkill.monkEnlightenment), false);
    });

    test('Lv15 cleric → 全Clericスキル有効', () {
      final player = Player(
        jobLevels: {Job.monk: 15},
        currentJob: Job.monk,
      );
      expect(player.hasSkill(JobSkill.monkRepeatAfter), true);
      expect(player.hasSkill(JobSkill.monkSnooze), true);
      expect(player.hasSkill(JobSkill.monkStreak), true);
      expect(player.hasSkill(JobSkill.monkEnlightenment), true);
    });

    test('Cleric Lv15 mastered → v3 compat activeSkills → 他職業からでも全スキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.monk: 15},
        currentJob: Job.adventurer,
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.monk);
      expect(player.hasSkill(JobSkill.monkRepeatAfter), true);
      expect(player.hasSkill(JobSkill.monkSnooze), true);
      expect(player.hasSkill(JobSkill.monkStreak), true);
      expect(player.hasSkill(JobSkill.monkEnlightenment), true);
    });
  });

  group('hasSkill(JobSkill) — Wizard skills', () {
    test('Lv1 wizard → wizardSubtaskのみ有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.mystic: 1},
        currentJob: Job.mystic,
      );
      expect(player.hasSkill(JobSkill.mysticSubtask), true);
      expect(player.hasSkill(JobSkill.mysticTags), false);
      expect(player.hasSkill(JobSkill.mysticProject), false);
      expect(player.hasSkill(JobSkill.mysticOverview), false);
    });

    test('Lv5 wizard → subtask + tags 有効', () {
      final player = Player(
        jobLevels: {Job.mystic: 5},
        currentJob: Job.mystic,
      );
      expect(player.hasSkill(JobSkill.mysticSubtask), true);
      expect(player.hasSkill(JobSkill.mysticTags), true);
      expect(player.hasSkill(JobSkill.mysticProject), false);
    });

    test('Lv10 wizard → subtask + tags + project 有効', () {
      final player = Player(
        jobLevels: {Job.mystic: 10},
        currentJob: Job.mystic,
      );
      expect(player.hasSkill(JobSkill.mysticSubtask), true);
      expect(player.hasSkill(JobSkill.mysticTags), true);
      expect(player.hasSkill(JobSkill.mysticProject), true);
      expect(player.hasSkill(JobSkill.mysticOverview), false);
    });

    test('Lv15 wizard → 全Wizardスキル有効', () {
      final player = Player(
        jobLevels: {Job.mystic: 15},
        currentJob: Job.mystic,
      );
      expect(player.hasSkill(JobSkill.mysticSubtask), true);
      expect(player.hasSkill(JobSkill.mysticTags), true);
      expect(player.hasSkill(JobSkill.mysticProject), true);
      expect(player.hasSkill(JobSkill.mysticOverview), true);
    });

    test('Wizard Lv15 mastered → v3 compat activeSkills → 他職業からでも全スキル有効', () {
      final player = Player(
        jobLevels: {Job.adventurer: 1, Job.mystic: 15},
        currentJob: Job.adventurer,
      );
      // ignore: deprecated_member_use
      player.activeSkills.add(Job.mystic);
      expect(player.hasSkill(JobSkill.mysticSubtask), true);
      expect(player.hasSkill(JobSkill.mysticTags), true);
      expect(player.hasSkill(JobSkill.mysticProject), true);
      expect(player.hasSkill(JobSkill.mysticOverview), true);
    });
  });

  // ═══════════════════════════════════════════
  // クロスジョブスキル相互作用
  // ═══════════════════════════════════════════
  group('Cross-job skill interaction', () {
    test('Ronin mastered + Warrior equippedSkills（pomodoro）→ 両方有効', () {
      final player = Player(
        currentJob: Job.samurai,
        jobLevels: {Job.adventurer: 10, Job.samurai: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.samuraiPomodoro)],
      );
      // Ronin mastered → 常時オン
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
      // Samurai current + Lv10 → pomodoro 有効
      expect(player.hasSkill(JobSkill.samuraiPomodoro), true);
    });

    test('Ronin mastered + Cleric equippedSkills（streak）→ 両方有効', () {
      final player = Player(
        currentJob: Job.samurai,
        jobLevels: {Job.adventurer: 10, Job.samurai: 1, Job.monk: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.monkStreak)],
      );
      // Ronin mastered → 常時オン
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);
      // Monk streak via equippedSkills (Lv10 → ok)
      expect(player.hasSkill(JobSkill.monkStreak), true);
      // Monk snooze → NOT equipped
      expect(player.hasSkill(JobSkill.monkSnooze), false);
    });

    test('Ronin mastered + Wizard equippedSkills（project + tags）→ 3スキル有効', () {
      final player = Player(
        currentJob: Job.monk,
        jobLevels: {Job.adventurer: 10, Job.monk: 1, Job.mystic: 10},
        equippedSkills: [
          EquippedSkill(skill: JobSkill.mysticProject),
          EquippedSkill(skill: JobSkill.mysticTags),
        ],
      );
      // Ronin mastered
      expect(player.hasSkill(JobSkill.roninSlots), true);
      // Mystic project + tags via equippedSkills
      expect(player.hasSkill(JobSkill.mysticProject), true);
      expect(player.hasSkill(JobSkill.mysticTags), true);
      // Mystic subtask → NOT equipped
      expect(player.hasSkill(JobSkill.mysticSubtask), false);
    });

    test('全職業 mastered → 全スキル activeSkills登録で使用可', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {
          Job.adventurer: 10,
          Job.samurai: 15,
          Job.monk: 15,
          Job.mystic: 15,
        },
      );
      // ignore: deprecated_member_use
      player.activeSkills.addAll([Job.samurai, Job.monk, Job.mystic]);

      // Ronin always-on (mastered)
      expect(player.hasSkill(JobSkill.roninSlots), true);
      expect(player.hasSkill(JobSkill.roninRepeatTask), true);

      // All jobs via v3 compat
      expect(player.hasSkill(JobSkill.samuraiBushido), true);
      expect(player.hasSkill(JobSkill.monkEnlightenment), true);
      expect(player.hasSkill(JobSkill.mysticOverview), true);
    });

    test('未mastered職業のスキルはequippedSkillsしても使用不可', () {
      final player = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1, Job.samurai: 5},
        equippedSkills: [EquippedSkill(skill: JobSkill.samuraiPomodoro)],
      );
      // warrior is NOT mastered (Lv5 < 14) + NOT current → canUseSkill fails
      // → hasSkill requires canUseSkill for equippedSkills path
      // But wait: hasSkill checks equippedSkills first: yes (it IS equipped + level>=required)
      // Let's test: level 5 >= requiredLevel 10? NO. So returns false.
      expect(player.hasSkill(JobSkill.samuraiPomodoro), false);
    });
  });

  // ═══════════════════════════════════════════
  // EquippedSkill isActive — ユニットテスト
  // ═══════════════════════════════════════════
  group('EquippedSkill isActive', () {
    test('default isActive is true', () {
      final eq = EquippedSkill(skill: JobSkill.samuraiCombo);
      expect(eq.isActive, true);
    });

    test('can set isActive to false at construction', () {
      final eq = EquippedSkill(skill: JobSkill.monkStreak, isActive: false);
      expect(eq.isActive, false);
    });

    test('isActive can be toggled at runtime', () {
      final eq = EquippedSkill(skill: JobSkill.mysticSubtask);
      eq.isActive = false;
      expect(eq.isActive, false);
      eq.isActive = true;
      expect(eq.isActive, true);
    });

    test('fromJson preserves isActive', () {
      final json = {'skill': JobSkill.samuraiCombo.index, 'isActive': false};
      final eq = EquippedSkill.fromJson(json);
      expect(eq.isActive, false);
    });

    test('fromJson defaults isActive to true when missing', () {
      final json = {'skill': JobSkill.samuraiCombo.index};
      final eq = EquippedSkill.fromJson(json);
      expect(eq.isActive, true);
    });

    test('toJson includes isActive', () {
      final eq = EquippedSkill(skill: JobSkill.samuraiCombo, isActive: false);
      final json = eq.toJson();
      expect(json['isActive'], false);
    });

    test('Equality ignores isActive', () {
      final a = EquippedSkill(skill: JobSkill.samuraiCombo, isActive: true);
      final b = EquippedSkill(skill: JobSkill.samuraiCombo, isActive: false);
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
        jobLevels: {Job.adventurer: 1, Job.samurai: 10},
        equippedSkills: [EquippedSkill(skill: JobSkill.samuraiPomodoro)],
      );
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.equippedSkills.length, 1);
      expect(restored.equippedSkills[0].skill, JobSkill.samuraiPomodoro);
    });

    test('v4 equippedSkills: 複数スキル round-trip', () async {
      final original = Player(
        jobLevels: {Job.adventurer: 10, Job.samurai: 10, Job.monk: 10},
        equippedSkills: [
          EquippedSkill(skill: JobSkill.samuraiPomodoro, isActive: true),
          EquippedSkill(skill: JobSkill.monkStreak, isActive: false),
        ],
      );
      await box.put('p', original);
      final restored = box.get('p')!;
      expect(restored.equippedSkills.length, 2);
      expect(restored.equippedSkills[0].skill, JobSkill.samuraiPomodoro);
      expect(restored.equippedSkills[0].isActive, true);
      expect(restored.equippedSkills[1].skill, JobSkill.monkStreak);
      expect(restored.equippedSkills[1].isActive, false);
    });

    test('v4 warriorDailyBuff round-trip', () async {
      final original = Player(
        jobLevels: {Job.samurai: 15},
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
        jobLevels: {Job.monk: 15},
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
        jobLevels: {Job.samurai: 10},
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
      original.activeSkills.addAll([Job.samurai, Job.monk]);
      await box.put('p', original);
      final restored = box.get('p')!;
      // ignore: deprecated_member_use
      expect(restored.activeSkills, contains(Job.samurai));
      // ignore: deprecated_member_use
      expect(restored.activeSkills, contains(Job.monk));
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
