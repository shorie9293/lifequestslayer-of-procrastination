import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';

void main() {
  group('JobSkill enum', () {
    test('全14スキルが定義されている', () {
      final values = JobSkill.values;
      expect(values.length, 14);
      // Ronin
      expect(values, contains(JobSkill.roninSlots));
      expect(values, contains(JobSkill.roninRepeatTask));
      // Warrior
      expect(values, contains(JobSkill.warriorCombo));
      expect(values, contains(JobSkill.warriorFatigueReverse));
      expect(values, contains(JobSkill.warriorPomodoro));
      expect(values, contains(JobSkill.warriorBushido));
      // Cleric
      expect(values, contains(JobSkill.clericRepeatAfter));
      expect(values, contains(JobSkill.clericSnooze));
      expect(values, contains(JobSkill.clericStreak));
      expect(values, contains(JobSkill.clericEnlightenment));
      // Wizard
      expect(values, contains(JobSkill.wizardSubtask));
      expect(values, contains(JobSkill.wizardTags));
      expect(values, contains(JobSkill.wizardProject));
      expect(values, contains(JobSkill.wizardOverview));
    });

    test('JobSkill.job が正しい職業を返す', () {
      // Ronin → Job.adventurer
      expect(JobSkill.roninSlots.job, Job.adventurer);
      expect(JobSkill.roninRepeatTask.job, Job.adventurer);
      // Warrior
      expect(JobSkill.warriorCombo.job, Job.warrior);
      expect(JobSkill.warriorFatigueReverse.job, Job.warrior);
      expect(JobSkill.warriorPomodoro.job, Job.warrior);
      expect(JobSkill.warriorBushido.job, Job.warrior);
      // Cleric
      expect(JobSkill.clericRepeatAfter.job, Job.cleric);
      expect(JobSkill.clericSnooze.job, Job.cleric);
      expect(JobSkill.clericStreak.job, Job.cleric);
      expect(JobSkill.clericEnlightenment.job, Job.cleric);
      // Wizard
      expect(JobSkill.wizardSubtask.job, Job.wizard);
      expect(JobSkill.wizardTags.job, Job.wizard);
      expect(JobSkill.wizardProject.job, Job.wizard);
      expect(JobSkill.wizardOverview.job, Job.wizard);
    });
  });

  group('JobSkillMeta', () {
    test('requiredLevel が仕様通り', () {
      // Ronin: roninSlots(Lv1), roninRepeatTask(Lv10)
      expect(JobSkill.roninSlots.requiredLevel, 1);
      expect(JobSkill.roninRepeatTask.requiredLevel, 10);
      // Warrior
      expect(JobSkill.warriorCombo.requiredLevel, 1);
      expect(JobSkill.warriorFatigueReverse.requiredLevel, 5);
      expect(JobSkill.warriorPomodoro.requiredLevel, 10);
      expect(JobSkill.warriorBushido.requiredLevel, 15);
      // Cleric
      expect(JobSkill.clericRepeatAfter.requiredLevel, 1);
      expect(JobSkill.clericSnooze.requiredLevel, 5);
      expect(JobSkill.clericStreak.requiredLevel, 10);
      expect(JobSkill.clericEnlightenment.requiredLevel, 15);
      // Wizard
      expect(JobSkill.wizardSubtask.requiredLevel, 1);
      expect(JobSkill.wizardTags.requiredLevel, 5);
      expect(JobSkill.wizardProject.requiredLevel, 10);
      expect(JobSkill.wizardOverview.requiredLevel, 15);
    });

    test('isMasterSkill: roninRepeatTask と requiredLevel==15 のみ true', () {
      expect(JobSkill.roninRepeatTask.isMasterSkill, true);
      expect(JobSkill.roninSlots.isMasterSkill, false);

      expect(JobSkill.warriorBushido.isMasterSkill, true);
      expect(JobSkill.warriorCombo.isMasterSkill, false);
      expect(JobSkill.warriorFatigueReverse.isMasterSkill, false);
      expect(JobSkill.warriorPomodoro.isMasterSkill, false);

      expect(JobSkill.clericEnlightenment.isMasterSkill, true);
      expect(JobSkill.clericRepeatAfter.isMasterSkill, false);
      expect(JobSkill.clericSnooze.isMasterSkill, false);
      expect(JobSkill.clericStreak.isMasterSkill, false);

      expect(JobSkill.wizardOverview.isMasterSkill, true);
      expect(JobSkill.wizardSubtask.isMasterSkill, false);
      expect(JobSkill.wizardTags.isMasterSkill, false);
      expect(JobSkill.wizardProject.isMasterSkill, false);
    });

    test('displayName が空でない日本語名を返す', () {
      for (final skill in JobSkill.values) {
        expect(skill.displayName, isA<String>());
        expect(skill.displayName.isNotEmpty, true);
      }
    });

    test('isMastered: Ronin系はLv10以上、他はLv15以上で mastered', () {
      // roninSlots (Ronin Lv9 → not mastered)
      expect(JobSkill.roninSlots.isMastered(9), false);
      // roninSlots (Ronin Lv10 → mastered)
      expect(JobSkill.roninSlots.isMastered(10), true);
      // roninSlots (Ronin Lv11 → mastered)
      expect(JobSkill.roninSlots.isMastered(11), true);

      // roninRepeatTask (Ronin Lv10 → mastered, since isMasterSkill)
      expect(JobSkill.roninRepeatTask.isMastered(10), true);

      // Warrior: Lv14 not mastered, Lv15 mastered
      expect(JobSkill.warriorBushido.isMastered(14), false);
      expect(JobSkill.warriorBushido.isMastered(15), true);

      // Cleric: Lv14 not mastered, Lv15 mastered
      expect(JobSkill.clericEnlightenment.isMastered(14), false);
      expect(JobSkill.clericEnlightenment.isMastered(15), true);

      // Wizard: Lv14 not mastered, Lv15 mastered
      expect(JobSkill.wizardOverview.isMastered(14), false);
      expect(JobSkill.wizardOverview.isMastered(15), true);
    });

    test('maxSkillSlots が返す値を確認', () {
      // 未熟練: 基本1枠のみ
      expect(JobSkill.maxSkillSlots({Job.adventurer: 1}), 1);
      // Roninマスター(Lv10): +1
      expect(JobSkill.maxSkillSlots({Job.adventurer: 10}), 2);
      // 全職マスター(Lv15): 1 + 4 = 5
      expect(
        JobSkill.maxSkillSlots({
          Job.adventurer: 10,
          Job.warrior: 15,
          Job.cleric: 15,
          Job.wizard: 15,
        }),
        5,
      );
    });
  });
}
