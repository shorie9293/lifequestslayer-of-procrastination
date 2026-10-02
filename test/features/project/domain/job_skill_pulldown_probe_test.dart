// 親探針: 職業スキルプルダウンの合成不変条件
//
// 眷属は actionFor / 個別ケースを試練するが、以下の合成条件は撃たない:
//  1) 全職経験時に全14スキルが過不足なく一度だけ現れる（現職×継承の重複なし）
//  2) 未経験職（jobLevels に無い職）のスキルは継承に現れない
//  3) 装備中スキルは職レベル未達でも継承に現れ isEquipped=true
// 監査: 直毘神（親）— 令和八年長月二日

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_slot.dart';
import 'package:rpg_todo/features/project/domain/job_skill_pulldown.dart';

void main() {
  group('親探針: build の合成不変条件', () {
    test('全職を経験したPlayerで全14スキルが重複なく一度だけ現れる', () {
      final p = Player(
        currentJob: Job.mystic,
        jobLevels: {
          Job.adventurer: 15,
          Job.samurai: 15,
          Job.monk: 15,
          Job.mystic: 15,
        },
      );
      final pd = JobSkillPulldownService.build(p);
      final all = pd.allEntries;

      expect(pd.totalCount, 14);
      expect(all.map((e) => e.skill).toSet().length, 14,
          reason: '同一スキルが現職・継承の両方に重複してはならない');
      expect(all.where((e) => !e.isInherited).length, 4,
          reason: '現職 mystic のスキルは4件');
      expect(all.where((e) => e.isInherited).length, 10,
          reason: '他職のスキルは10件');
      expect(pd.groups.first.key, JobSkillPulldownService.currentGroupKey);
      expect(pd.groups.last.key, JobSkillPulldownService.inheritedGroupKey);
    });

    test('未経験職のスキルは継承に現れず、現職グループのみ', () {
      final p = Player(
        currentJob: Job.adventurer,
        jobLevels: {Job.adventurer: 1},
      );
      final pd = JobSkillPulldownService.build(p);

      expect(pd.groups.length, 1);
      expect(pd.groups.single.key, JobSkillPulldownService.currentGroupKey);
      expect(pd.allEntries.map((e) => e.skill).toList(),
          [JobSkill.roninSlots, JobSkill.roninRepeatTask]);
    });

    test('装備中スキルは職レベル未達でも継承に現れ isEquipped=true', () {
      final p = Player(
        currentJob: Job.mystic,
        jobLevels: {Job.mystic: 1},
        equippedSkills: [EquippedSkill(skill: JobSkill.samuraiCombo)],
      );
      final pd = JobSkillPulldownService.build(p);

      final entry = pd.allEntries.firstWhere((e) => e.skill == JobSkill.samuraiCombo);
      expect(entry.isEquipped, isTrue);
      expect(entry.isInherited, isTrue);
      expect(entry.action, JobSkillActionKind.passiveAlwaysOn);
    });
  });
}
