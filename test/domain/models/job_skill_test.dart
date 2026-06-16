import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';

void main() {
  group('JobSkill enum', () {
    test('全14スキルが定義されている', () {
      const values = JobSkill.values;
      expect(values.length, 14);
      // Ronin
      expect(values, contains(JobSkill.roninSlots));
      expect(values, contains(JobSkill.roninRepeatTask));
      // Warrior
      expect(values, contains(JobSkill.samuraiCombo));
      expect(values, contains(JobSkill.samuraiFatigueReverse));
      expect(values, contains(JobSkill.samuraiPomodoro));
      expect(values, contains(JobSkill.samuraiBushido));
      // Cleric
      expect(values, contains(JobSkill.monkRepeatAfter));
      expect(values, contains(JobSkill.monkSnooze));
      expect(values, contains(JobSkill.monkStreak));
      expect(values, contains(JobSkill.monkEnlightenment));
      // Wizard
      expect(values, contains(JobSkill.mysticSubtask));
      expect(values, contains(JobSkill.mysticTags));
      expect(values, contains(JobSkill.mysticProject));
      expect(values, contains(JobSkill.mysticOverview));
    });

    test('JobSkill.job が正しい職業を返す', () {
      // Ronin → Job.adventurer
      expect(JobSkill.roninSlots.job, Job.adventurer);
      expect(JobSkill.roninRepeatTask.job, Job.adventurer);
      // Warrior
      expect(JobSkill.samuraiCombo.job, Job.samurai);
      expect(JobSkill.samuraiFatigueReverse.job, Job.samurai);
      expect(JobSkill.samuraiPomodoro.job, Job.samurai);
      expect(JobSkill.samuraiBushido.job, Job.samurai);
      // Cleric
      expect(JobSkill.monkRepeatAfter.job, Job.monk);
      expect(JobSkill.monkSnooze.job, Job.monk);
      expect(JobSkill.monkStreak.job, Job.monk);
      expect(JobSkill.monkEnlightenment.job, Job.monk);
      // Wizard
      expect(JobSkill.mysticSubtask.job, Job.mystic);
      expect(JobSkill.mysticTags.job, Job.mystic);
      expect(JobSkill.mysticProject.job, Job.mystic);
      expect(JobSkill.mysticOverview.job, Job.mystic);
    });
  });

  group('JobSkillMeta', () {
    test('requiredLevel が仕様通り', () {
      // Ronin: roninSlots(Lv1), roninRepeatTask(Lv10)
      expect(JobSkill.roninSlots.requiredLevel, 1);
      expect(JobSkill.roninRepeatTask.requiredLevel, 10);
      // Warrior
      expect(JobSkill.samuraiCombo.requiredLevel, 1);
      expect(JobSkill.samuraiFatigueReverse.requiredLevel, 5);
      expect(JobSkill.samuraiPomodoro.requiredLevel, 10);
      expect(JobSkill.samuraiBushido.requiredLevel, 15);
      // Cleric
      expect(JobSkill.monkRepeatAfter.requiredLevel, 1);
      expect(JobSkill.monkSnooze.requiredLevel, 5);
      expect(JobSkill.monkStreak.requiredLevel, 10);
      expect(JobSkill.monkEnlightenment.requiredLevel, 15);
      // Wizard
      expect(JobSkill.mysticSubtask.requiredLevel, 1);
      expect(JobSkill.mysticTags.requiredLevel, 5);
      expect(JobSkill.mysticProject.requiredLevel, 10);
      expect(JobSkill.mysticOverview.requiredLevel, 15);
    });

    test('isMasterSkill: roninRepeatTask と requiredLevel==15 のみ true', () {
      expect(JobSkill.roninRepeatTask.isMasterSkill, true);
      expect(JobSkill.roninSlots.isMasterSkill, false);

      expect(JobSkill.samuraiBushido.isMasterSkill, true);
      expect(JobSkill.samuraiCombo.isMasterSkill, false);
      expect(JobSkill.samuraiFatigueReverse.isMasterSkill, false);
      expect(JobSkill.samuraiPomodoro.isMasterSkill, false);

      expect(JobSkill.monkEnlightenment.isMasterSkill, true);
      expect(JobSkill.monkRepeatAfter.isMasterSkill, false);
      expect(JobSkill.monkSnooze.isMasterSkill, false);
      expect(JobSkill.monkStreak.isMasterSkill, false);

      expect(JobSkill.mysticOverview.isMasterSkill, true);
      expect(JobSkill.mysticSubtask.isMasterSkill, false);
      expect(JobSkill.mysticTags.isMasterSkill, false);
      expect(JobSkill.mysticProject.isMasterSkill, false);
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
      expect(JobSkill.samuraiBushido.isMastered(14), false);
      expect(JobSkill.samuraiBushido.isMastered(15), true);

      // Cleric: Lv14 not mastered, Lv15 mastered
      expect(JobSkill.monkEnlightenment.isMastered(14), false);
      expect(JobSkill.monkEnlightenment.isMastered(15), true);

      // Wizard: Lv14 not mastered, Lv15 mastered
      expect(JobSkill.mysticOverview.isMastered(14), false);
      expect(JobSkill.mysticOverview.isMastered(15), true);
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
          Job.samurai: 15,
          Job.monk: 15,
          Job.mystic: 15,
        }),
        5,
      );
    });
  });
}
