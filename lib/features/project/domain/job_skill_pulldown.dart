// 職業チップ＋スキルプルダウン — 純粋ドメイン層
//
// 現職のスキルと継承の技（他職で必要Lv達成 or 装備中）をグループ化する。
// UI層に依存しない純粋ロジック（TDD 対象）。
//
// 制定: 令和八年長月二日

import 'package:rpg_todo/domain/models/player.dart';

/// プルダウン項目選択時のアクション種別。
enum JobSkillActionKind {
  navigateProject,
  navigateRecurring,
  navigateHabitCalendar,
  navigateReminder,
  openCreateTaskDialog,
  navigatePomodoro,
  navigateOverview,
  navigateEnlightenment,
  equipInTemple,
  passiveAlwaysOn,
}

/// プルダウンの1項目。
class JobSkillPulldownEntry {
  final JobSkill skill;
  final int requiredLevel;
  final bool isUnlocked;
  final bool isEquipped;
  final bool isInherited;
  final JobSkillActionKind action;
  const JobSkillPulldownEntry({
    required this.skill,
    required this.requiredLevel,
    required this.isUnlocked,
    required this.isEquipped,
    required this.isInherited,
    required this.action,
  });
}

/// プルダウンのグループ（現職 / 継承）。
class JobSkillPulldownGroup {
  /// 'current' | 'inherited'
  final String key;
  final String label;
  final List<JobSkillPulldownEntry> entries;
  const JobSkillPulldownGroup({
    required this.key,
    required this.label,
    required this.entries,
  });
}

/// プルダウン全体。
class JobSkillPulldown {
  final List<JobSkillPulldownGroup> groups;
  const JobSkillPulldown({required this.groups});

  /// 全グループのentries数の和。
  int get totalCount =>
      groups.fold(0, (sum, g) => sum + g.entries.length);

  bool get isEmpty => totalCount == 0;

  /// 全entryをグループ順に平坦化。
  List<JobSkillPulldownEntry> get allEntries =>
      groups.expand((g) => g.entries).toList();
}

class JobSkillPulldownService {
  JobSkillPulldownService._();

  static const String currentGroupKey = 'current';
  static const String inheritedGroupKey = 'inherited';
  static const String currentGroupLabel = '現在の職業のスキル';
  static const String inheritedGroupLabel = '継承の技';

  /// スキル→アクション種別の写像（14スキル全件）。
  static JobSkillActionKind actionFor(JobSkill skill) {
    switch (skill) {
      case JobSkill.roninRepeatTask:
        return JobSkillActionKind.navigateRecurring;
      case JobSkill.monkStreak:
        return JobSkillActionKind.navigateHabitCalendar;
      case JobSkill.monkSnooze:
        return JobSkillActionKind.navigateReminder;
      case JobSkill.mysticProject:
        return JobSkillActionKind.navigateProject;
      case JobSkill.mysticSubtask:
      case JobSkill.mysticTags:
        return JobSkillActionKind.openCreateTaskDialog;
      case JobSkill.samuraiPomodoro:
        return JobSkillActionKind.navigatePomodoro;
      case JobSkill.mysticOverview:
        return JobSkillActionKind.navigateOverview;
      case JobSkill.monkEnlightenment:
        return JobSkillActionKind.navigateEnlightenment;
      case JobSkill.roninSlots:
      case JobSkill.monkRepeatAfter:
        return JobSkillActionKind.equipInTemple;
      case JobSkill.samuraiCombo:
      case JobSkill.samuraiFatigueReverse:
      case JobSkill.samuraiBushido:
        return JobSkillActionKind.passiveAlwaysOn;
    }
  }

  /// 継承の技: その職を経験済み（jobLevels に含まれる）かつ必要Lv達成、
  /// または装備中。未経験職は必要Lv1でも継承に出さない。
  static List<JobSkill> inheritedSkills(Player p) {
    return JobSkill.values
        .where((s) =>
            s.job != p.currentJob &&
            ((p.jobLevels.containsKey(s.job) &&
                    (p.jobLevels[s.job] ?? 1) >= s.requiredLevel) ||
                p.equippedSkills.any((e) => e.skill == s)))
        .toList();
  }

  /// Player からプルダウン構造を構築する。
  static JobSkillPulldown build(Player p) {
    final groups = <JobSkillPulldownGroup>[];

    final currentSkills = JobSkill.values
        .where((s) => s.job == p.currentJob)
        .toList();
    if (currentSkills.isNotEmpty) {
      final currentJobLevel = p.jobLevels[p.currentJob] ?? 1;
      groups.add(JobSkillPulldownGroup(
        key: currentGroupKey,
        label: currentGroupLabel,
        entries: currentSkills
            .map((s) => JobSkillPulldownEntry(
                  skill: s,
                  requiredLevel: s.requiredLevel,
                  isUnlocked: p.canUseSkill(s.job) &&
                      currentJobLevel >= s.requiredLevel,
                  isEquipped:
                      p.equippedSkills.any((e) => e.skill == s),
                  isInherited: false,
                  action: actionFor(s),
                ))
            .toList(),
      ));
    }

    final inherited = inheritedSkills(p);
    if (inherited.isNotEmpty) {
      // JobSkill.values の宣言順に並べる。
      final ordered = JobSkill.values.where(inherited.contains).toList();
      groups.add(JobSkillPulldownGroup(
        key: inheritedGroupKey,
        label: inheritedGroupLabel,
        entries: ordered
            .map((s) => JobSkillPulldownEntry(
                  skill: s,
                  requiredLevel: s.requiredLevel,
                  isUnlocked: true,
                  isEquipped:
                      p.equippedSkills.any((e) => e.skill == s),
                  isInherited: true,
                  action: actionFor(s),
                ))
            .toList(),
      ));
    }

    return JobSkillPulldown(groups: groups);
  }
}
