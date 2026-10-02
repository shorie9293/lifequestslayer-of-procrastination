// 職業スキルプルダウン — 純粋ロジックの試練
//
// 対象: lib/features/project/domain/job_skill_pulldown.dart
// TDD RED→GREEN。

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/features/project/domain/job_skill_pulldown.dart';

Player _player({
  Job currentJob = Job.adventurer,
  Map<Job, int>? jobLevels,
  List<EquippedSkill>? equippedSkills,
}) {
  return Player(
    currentJob: currentJob,
    jobLevels: jobLevels,
    equippedSkills: equippedSkills,
  );
}

void main() {
  group('actionFor', () {
    final expected = <JobSkill, JobSkillActionKind>{
      JobSkill.roninSlots: JobSkillActionKind.equipInTemple,
      JobSkill.roninRepeatTask: JobSkillActionKind.navigateRecurring,
      JobSkill.samuraiCombo: JobSkillActionKind.passiveAlwaysOn,
      JobSkill.samuraiFatigueReverse: JobSkillActionKind.passiveAlwaysOn,
      JobSkill.samuraiPomodoro: JobSkillActionKind.navigatePomodoro,
      JobSkill.samuraiBushido: JobSkillActionKind.passiveAlwaysOn,
      JobSkill.monkRepeatAfter: JobSkillActionKind.equipInTemple,
      JobSkill.monkSnooze: JobSkillActionKind.navigateReminder,
      JobSkill.monkStreak: JobSkillActionKind.navigateHabitCalendar,
      JobSkill.monkEnlightenment: JobSkillActionKind.navigateEnlightenment,
      JobSkill.mysticSubtask: JobSkillActionKind.openCreateTaskDialog,
      JobSkill.mysticTags: JobSkillActionKind.openCreateTaskDialog,
      JobSkill.mysticProject: JobSkillActionKind.navigateProject,
      JobSkill.mysticOverview: JobSkillActionKind.navigateOverview,
    };

    test('14スキル全てが期待のアクション種別に写像される', () {
      expect(JobSkill.values.length, 14);
      for (final s in JobSkill.values) {
        expect(
          JobSkillPulldownService.actionFor(s),
          expected[s],
          reason: 'actionFor(${s.name})',
        );
      }
    });

    test('分類の網羅: navigate系 / openCreateTaskDialog系 / passive系 / equipInTemple系', () {
      final navigate = JobSkill.values
          .where((s) => JobSkillPulldownService.actionFor(s).name.startsWith('navigate'))
          .toSet();
      expect(
        navigate,
        {
          JobSkill.roninRepeatTask,
          JobSkill.monkStreak,
          JobSkill.monkSnooze,
          JobSkill.mysticProject,
          JobSkill.samuraiPomodoro,
          JobSkill.mysticOverview,
          JobSkill.monkEnlightenment,
        },
      );

      final openDialog = JobSkill.values
          .where((s) =>
              JobSkillPulldownService.actionFor(s) ==
              JobSkillActionKind.openCreateTaskDialog)
          .toSet();
      expect(openDialog, {JobSkill.mysticSubtask, JobSkill.mysticTags});

      final passive = JobSkill.values
          .where((s) =>
              JobSkillPulldownService.actionFor(s) ==
              JobSkillActionKind.passiveAlwaysOn)
          .toSet();
      expect(passive,
          {JobSkill.samuraiCombo, JobSkill.samuraiFatigueReverse, JobSkill.samuraiBushido});

      final equip = JobSkill.values
          .where((s) =>
              JobSkillPulldownService.actionFor(s) ==
              JobSkillActionKind.equipInTemple)
          .toSet();
      expect(equip, {JobSkill.roninSlots, JobSkill.monkRepeatAfter});
    });
  });

  group('build: 現職のみ', () {
    test('現職スキルのみのPlayerでは groups は current 1件、他職スキルは含まれない', () {
      final p = _player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 12},
      );
      final pd = JobSkillPulldownService.build(p);

      // 未経験職（jobLevels に他職が無い）は継承グループが出ない（v1.5.26 意味論修正）。
      expect(pd.groups.length, 1);
      expect(
        pd.groups.every((g) => g.key != JobSkillPulldownService.inheritedGroupKey),
        isTrue,
      );
      final current = pd.groups
          .singleWhere((g) => g.key == JobSkillPulldownService.currentGroupKey);
      expect(
        current.entries.map((e) => e.skill).toSet(),
        {JobSkill.roninSlots, JobSkill.roninRepeatTask},
      );
      for (final e in current.entries) {
        expect(e.isInherited, isFalse);
      }
      // 現職スキルが継承グループに混入しないこと（未経験職は継承グループ自体が出ない）
      expect(pd.groups.length, 1);
    });

    test('低Lvでも current グループは出る（空グループは含まれない）', () {
      final p = _player(currentJob: Job.adventurer); // 全職 Lv1
      final pd = JobSkillPulldownService.build(p);
      // 未経験職は継承に出ないため current（ronin 2）のみ。
      expect(pd.groups.length, 1);
      final current = pd.groups
          .singleWhere((g) => g.key == JobSkillPulldownService.currentGroupKey);
      // roninSlots (Lv1) のみ unlocked
      final slots = current.entries.singleWhere((e) => e.skill == JobSkill.roninSlots);
      expect(slots.isUnlocked, isTrue);
      final repeat = current.entries.singleWhere((e) => e.skill == JobSkill.roninRepeatTask);
      expect(repeat.isUnlocked, isFalse);
      expect(pd.totalCount, 2);
      expect(pd.isEmpty, isFalse);
    });
  });

  group('build: 継承', () {
    test('jobLevels で過去職が必要Lvに達していると inherited に入る', () {
      final p = _player(
        currentJob: Job.mystic,
        jobLevels: {Job.mystic: 12, Job.adventurer: 10},
      );
      final pd = JobSkillPulldownService.build(p);

      expect(pd.groups.map((g) => g.key).toList(),
          [JobSkillPulldownService.currentGroupKey, JobSkillPulldownService.inheritedGroupKey]);
      final inherited = pd.groups[1];
      expect(inherited.label, '継承の技');
      final inheritedSkills = inherited.entries.map((e) => e.skill).toSet();
      expect(inheritedSkills, contains(JobSkill.roninRepeatTask));
      // 未経験職のスキルは継承に入らない
      expect(inheritedSkills, isNot(contains(anyOf(
        JobSkill.samuraiCombo,
        JobSkill.monkRepeatAfter,
        JobSkill.monkSnooze,
      ))));
      // 現職スキルは継承に入らない
      expect(inheritedSkills, isNot(contains(JobSkill.mysticSubtask)));
      expect(inheritedSkills, isNot(contains(JobSkill.mysticTags)));
      expect(inheritedSkills, isNot(contains(JobSkill.mysticProject)));
      expect(inheritedSkills, isNot(contains(JobSkill.mysticOverview)));
      for (final e in inherited.entries) {
        expect(e.isInherited, isTrue);
        expect(e.isUnlocked, isTrue);
      }
    });

    test('装備中スキルは職Lv未達でも継承に含まれる（isEquipped=true）', () {
      final p = _player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.monkSnooze, isActive: true)],
      );
      final pd = JobSkillPulldownService.build(p);

      final inherited = pd.groups
          .singleWhere((g) => g.key == JobSkillPulldownService.inheritedGroupKey);
      final entry = inherited.entries.singleWhere((e) => e.skill == JobSkill.monkSnooze);
      expect(entry.isEquipped, isTrue);
      expect(entry.isUnlocked, isTrue);
      expect(entry.isInherited, isTrue);
    });

    test('未経験職は継承に出ない（回帰: 他職経験ゼロのPlayer）', () {
      final p = _player(
        currentJob: Job.monk,
        jobLevels: const {Job.monk: 8},
      );
      final pd = JobSkillPulldownService.build(p);
      // current（monk 4）のみ。ronin/samurai/mystic は未経験なので継承グループなし。
      expect(pd.groups.length, 1);
      expect(
        pd.groups.single.key,
        JobSkillPulldownService.currentGroupKey,
      );
      expect(pd.totalCount, 4);
    });

    test('継承は経験済み職のみ（inheritedSkills の直接検証）', () {
      final p = _player(
        currentJob: Job.adventurer,
        jobLevels: const {Job.adventurer: 20, Job.mystic: 12},
      );
      final inherited = JobSkillPulldownService.inheritedSkills(p).toSet();
      // mystic は経験済み → Lv12 で subtask/tags/project は解放（overview は Lv15 で未達）
      expect(inherited, {
        JobSkill.mysticSubtask,
        JobSkill.mysticTags,
        JobSkill.mysticProject,
      });
    });
  });

  group('isUnlocked / isEquipped', () {
    test('現職スキルで必要Lv未達は isUnlocked=false、達成で true', () {
      final p = _player(
        currentJob: Job.mystic,
        jobLevels: {Job.mystic: 9},
      );
      final pd = JobSkillPulldownService.build(p);
      final current = pd.groups
          .singleWhere((g) => g.key == JobSkillPulldownService.currentGroupKey);
      final tags = current.entries.singleWhere((e) => e.skill == JobSkill.mysticTags);
      final project = current.entries.singleWhere((e) => e.skill == JobSkill.mysticProject);
      final subtask = current.entries.singleWhere((e) => e.skill == JobSkill.mysticSubtask);
      expect(subtask.isUnlocked, isTrue); // requiredLevel 1
      expect(tags.isUnlocked, isTrue); // requiredLevel 5, Lv9 で達成
      expect(project.isUnlocked, isFalse); // requiredLevel 10, Lv9 未達
    });

    test('isEquipped: equippedSkills に入っているスキルのみ true', () {
      final p = _player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 12},
        equippedSkills: [EquippedSkill(skill: JobSkill.roninSlots, isActive: true)],
      );
      final pd = JobSkillPulldownService.build(p);
      final slots = pd.allEntries.singleWhere((e) => e.skill == JobSkill.roninSlots);
      final repeat = pd.allEntries.singleWhere((e) => e.skill == JobSkill.roninRepeatTask);
      expect(slots.isEquipped, isTrue);
      expect(repeat.isEquipped, isFalse);
    });
  });

  group('totalCount / allEntries / isEmpty', () {
    test('totalCount と allEntries の整合', () {
      final p = _player(
        currentJob: Job.samurai,
        jobLevels: {Job.samurai: 15, Job.adventurer: 10},
      );
      final pd = JobSkillPulldownService.build(p);
      expect(pd.totalCount, pd.allEntries.length);
      // samurai 4 + 継承: adventurer 2（Lv10・経験済み）
      // （monk / mystic は未経験のため継承に出ない — v1.5.26 意味論修正）
      expect(pd.totalCount, 6);
      expect(pd.isEmpty, isFalse);
      // グループ順の平坦化
      expect(pd.allEntries.take(4).every((e) => e.skill.job == Job.samurai), isTrue);
    });

    // isEmpty は totalCount == 0 の分岐。JobSkill を持つ Player は
    // current グループが必ず非空のため実質 false になるが、
    // 空の JobSkillPulldown で分岐を担保する。
    test('isEmpty: groups が空なら totalCount 0 で isEmpty=true', () {
      const pd = JobSkillPulldown(groups: []);
      expect(pd.totalCount, 0);
      expect(pd.isEmpty, isTrue);
      expect(pd.allEntries, isEmpty);
    });
  });
}
