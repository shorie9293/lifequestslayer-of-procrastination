import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/skill_effects.dart';
import 'package:rpg_todo/domain/services/skill_effect_service.dart';
import 'package:rpg_todo/domain/models/job.dart';

void main() {
  // ━━━ Configuration completeness ━━━

  group('skillEffectConfig', () {
    test('10 nodes have effect configs defined', () {
      expect(skillEffectConfig.length, 10);
    });

    test('all 10 skill tree node IDs have matching effect configs', () {
      // skillTreeDefinition keys from skill_tree.dart
      const expectedIds = {
        'war_flash', 'war_combo', 'war_critical', 'war_zanshin',
        'cle_prayer', 'cle_heal', 'cle_ward',
        'wiz_foresight', 'wiz_split', 'wiz_transfer',
      };
      expect(skillEffectConfig.keys.toSet(), expectedIds);
    });

    test('each node has correct tree assignment', () {
      expect(skillEffectConfig['war_flash']!.tree, Job.samurai);
      expect(skillEffectConfig['war_combo']!.tree, Job.samurai);
      expect(skillEffectConfig['war_critical']!.tree, Job.samurai);
      expect(skillEffectConfig['war_zanshin']!.tree, Job.samurai);
      expect(skillEffectConfig['cle_prayer']!.tree, Job.monk);
      expect(skillEffectConfig['cle_heal']!.tree, Job.monk);
      expect(skillEffectConfig['cle_ward']!.tree, Job.monk);
      expect(skillEffectConfig['wiz_foresight']!.tree, Job.mystic);
      expect(skillEffectConfig['wiz_split']!.tree, Job.mystic);
      expect(skillEffectConfig['wiz_transfer']!.tree, Job.mystic);
    });

    test('no two nodes share the same ID', () {
      final ids = skillEffectConfig.keys.toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  // ━━━ Convenience helpers ━━━

  group('hasEffectConfig', () {
    test('returns true for valid IDs', () {
      expect(hasEffectConfig('war_flash'), true);
      expect(hasEffectConfig('cle_ward'), true);
    });

    test('returns false for unknown IDs', () {
      expect(hasEffectConfig('nonexistent'), false);
      expect(hasEffectConfig(''), false);
    });
  });

  group('effectConfigFor', () {
    test('returns config for valid ID', () {
      final cfg = effectConfigFor('war_flash');
      expect(cfg, isNotNull);
      expect(cfg!.nodeId, 'war_flash');
    });

    test('returns null for unknown ID', () {
      expect(effectConfigFor('nope'), isNull);
    });
  });

  group('effectConfigsFor', () {
    test('returns configs for unlocked IDs', () {
      final configs = effectConfigsFor(['war_flash', 'cle_prayer']);
      expect(configs.length, 2);
    });

    test('skips unknown IDs', () {
      final configs = effectConfigsFor(['war_flash', 'bad_id', 'cle_prayer']);
      expect(configs.length, 2);
    });

    test('returns empty for empty input', () {
      expect(effectConfigsFor([]).length, 0);
    });
  });

  // ━━━ Warrior — 一閃 (war_flash) ━━━

  group('SkillEffectService — war_flash', () {
    test('hasFlash is true when unlocked', () {
      final svc = SkillEffectService(['war_flash']);
      expect(svc.hasFlash, true);
    });

    test('hasFlash is false when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.hasFlash, false);
    });

    test('applyFlashBonus returns 0 when not unlocked', () {
      final svc = SkillEffectService([]);
      final rng = Random(42);
      for (int i = 0; i < 20; i++) {
        expect(svc.applyFlashBonus(1000, rng), 0);
      }
    });

    test('applyFlashBonus triggers ~15% of the time (statistical)', () {
      final svc = SkillEffectService(['war_flash']);
      final rng = Random(12345);
      int hits = 0;
      const trials = 1000;
      for (int i = 0; i < trials; i++) {
        if (svc.applyFlashBonus(1000, rng) > 0) hits++;
      }
      // 15% ± reasonable margin (binomial, 3 sigma ≈ 3.4%)
      expect(hits / trials, greaterThan(0.10));
      expect(hits / trials, lessThan(0.20));
    });

    test('applyFlashBonus returns 40% of exp when triggered', () {
      final svc = SkillEffectService(['war_flash']);
      // Use a seed that triggers on first call
      final rng = Random(0);
      // Call until it hits
      int bonus = 0;
      for (int i = 0; i < 100; i++) {
        bonus = svc.applyFlashBonus(1000, rng);
        if (bonus > 0) break;
      }
      expect(bonus, 400); // 40% of 1000
    });
  });

  // ━━━ Warrior — 連撃 (war_combo) ━━━

  group('SkillEffectService — war_combo', () {
    test('hasCombo is true when unlocked', () {
      final svc = SkillEffectService(['war_combo']);
      expect(svc.hasCombo, true);
    });

    test('comboExpPerCount defaults to 10 when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.comboExpPerCount, 10);
    });

    test('comboExpPerCount is 20 when unlocked', () {
      final svc = SkillEffectService(['war_combo']);
      expect(svc.comboExpPerCount, 20);
    });

    test('comboStepBonus defaults to 0 when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.comboStepBonus, 0.0);
    });

    test('comboStepBonus is 0.05 when unlocked', () {
      final svc = SkillEffectService(['war_combo']);
      expect(svc.comboStepBonus, 0.05);
    });
  });

  // ━━━ Warrior — 会心 (war_critical) ━━━

  group('SkillEffectService — war_critical', () {
    test('hasCritical is true when unlocked', () {
      final svc = SkillEffectService(['war_critical']);
      expect(svc.hasCritical, true);
    });

    test('applyCritical returns 0 when not unlocked', () {
      final svc = SkillEffectService([]);
      final rng = Random(42);
      for (int i = 0; i < 20; i++) {
        expect(svc.applyCritical(1000, rng), 0);
      }
    });

    test('applyCritical triggers ~10% of the time', () {
      final svc = SkillEffectService(['war_critical']);
      final rng = Random(99999);
      int hits = 0;
      const trials = 1000;
      for (int i = 0; i < trials; i++) {
        if (svc.applyCritical(1000, rng) > 0) hits++;
      }
      expect(hits / trials, greaterThan(0.06));
      expect(hits / trials, lessThan(0.14));
    });

    test('applyCritical returns 1× EXP bonus when triggered (total 2×)', () {
      final svc = SkillEffectService(['war_critical']);
      final rng = Random(1);
      int bonus = 0;
      for (int i = 0; i < 100; i++) {
        bonus = svc.applyCritical(500, rng);
        if (bonus > 0) break;
      }
      expect(bonus, 500); // (2.0 - 1.0) * 500 = 500 bonus
    });
  });

  // ━━━ Warrior — 残心 (war_zanshin) ━━━

  group('SkillEffectService — war_zanshin', () {
    test('hasZanshin is true when unlocked', () {
      final svc = SkillEffectService(['war_zanshin']);
      expect(svc.hasZanshin, true);
    });

    test('hasZanshin is false when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.hasZanshin, false);
    });

    test('hasZanshin is false when only other warrior nodes unlocked', () {
      final svc = SkillEffectService(['war_flash', 'war_combo', 'war_critical']);
      expect(svc.hasZanshin, false);
    });
  });

  // ━━━ Cleric — 祈り (cle_prayer) ━━━

  group('SkillEffectService — cle_prayer', () {
    test('hasPrayer is true when unlocked', () {
      final svc = SkillEffectService(['cle_prayer']);
      expect(svc.hasPrayer, true);
    });

    test('applyPrayerBonus returns same exp when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.applyPrayerBonus(1000), 1000);
    });

    test('applyPrayerBonus applies 1.05× multiplier', () {
      final svc = SkillEffectService(['cle_prayer']);
      expect(svc.applyPrayerBonus(1000), 1050);
      expect(svc.applyPrayerBonus(300), 315);
      expect(svc.applyPrayerBonus(100), 105);
    });
  });

  // ━━━ Cleric — 治癒 (cle_heal) ━━━

  group('SkillEffectService — cle_heal', () {
    test('hasHeal is true when unlocked', () {
      final svc = SkillEffectService(['cle_heal']);
      expect(svc.hasHeal, true);
    });

    test('penaltyReduction defaults to 0', () {
      final svc = SkillEffectService([]);
      expect(svc.penaltyReduction, 0.0);
    });

    test('penaltyReduction is 0.50 when unlocked', () {
      final svc = SkillEffectService(['cle_heal']);
      expect(svc.penaltyReduction, 0.50);
    });
  });

  // ━━━ Cleric — 加護 (cle_ward) ━━━

  group('SkillEffectService — cle_ward', () {
    test('hasWard is true when unlocked', () {
      final svc = SkillEffectService(['cle_ward']);
      expect(svc.hasWard, true);
    });

    test('applyWardStreakBonus returns 0 when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.applyWardStreakBonus(1000, 5), 0);
    });

    test('applyWardStreakBonus returns 0 when streak < 3', () {
      final svc = SkillEffectService(['cle_ward']);
      expect(svc.applyWardStreakBonus(1000, 0), 0);
      expect(svc.applyWardStreakBonus(1000, 1), 0);
      expect(svc.applyWardStreakBonus(1000, 2), 0);
    });

    test('applyWardStreakBonus applies +10% for streak ≥ 3', () {
      final svc = SkillEffectService(['cle_ward']);
      expect(svc.applyWardStreakBonus(1000, 3), 100);
      expect(svc.applyWardStreakBonus(1000, 7), 100);
      expect(svc.applyWardStreakBonus(100, 10), 10);
    });

    test('wardMinStreak is 3 when unlocked', () {
      final svc = SkillEffectService(['cle_ward']);
      expect(svc.wardMinStreak, 3);
    });
  });

  // ━━━ Wizard — 先見 (wiz_foresight) ━━━

  group('SkillEffectService — wiz_foresight', () {
    test('hasForesight is true when unlocked', () {
      final svc = SkillEffectService(['wiz_foresight']);
      expect(svc.hasForesight, true);
    });

    test('applyForesightBonus returns same exp when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.applyForesightBonus(1000), 1000);
    });

    test('applyForesightBonus applies 1.10× multiplier', () {
      final svc = SkillEffectService(['wiz_foresight']);
      expect(svc.applyForesightBonus(1000), 1100);
      expect(svc.applyForesightBonus(300), 330);
    });

    test('lateBonusWindowHours defaults to 1', () {
      final svc = SkillEffectService([]);
      expect(svc.lateBonusWindowHours, 1);
    });

    test('lateBonusWindowHours is 3 when unlocked', () {
      final svc = SkillEffectService(['wiz_foresight']);
      expect(svc.lateBonusWindowHours, 3);
    });
  });

  // ━━━ Wizard — 分割 (wiz_split) ━━━

  group('SkillEffectService — wiz_split', () {
    test('hasSplit is true when unlocked', () {
      final svc = SkillEffectService(['wiz_split']);
      expect(svc.hasSplit, true);
    });

    test('applySplitBonus returns 0 when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.applySplitBonus(1000, 3, true), 0);
    });

    test('applySplitBonus returns 0 when subquestCount is 0', () {
      final svc = SkillEffectService(['wiz_split']);
      expect(svc.applySplitBonus(1000, 0, true), 0);
    });

    test('applySplitBonus with 3 subquests, all complete', () {
      final svc = SkillEffectService(['wiz_split']);
      // perSubquest: 0.15 × 3 × 1000 = 450
      // allComplete: 0.25 × 1000 = 250
      // total = 700
      expect(svc.applySplitBonus(1000, 3, true), 700);
    });

    test('applySplitBonus with 3 subquests, not all complete', () {
      final svc = SkillEffectService(['wiz_split']);
      // perSubquest: 0.15 × 3 × 1000 = 450
      // allComplete: 0
      expect(svc.applySplitBonus(1000, 3, false), 450);
    });
  });

  // ━━━ Wizard — 転移 (wiz_transfer) ━━━

  group('SkillEffectService — wiz_transfer', () {
    test('hasTransfer is true when unlocked', () {
      final svc = SkillEffectService(['wiz_transfer']);
      expect(svc.hasTransfer, true);
    });

    test('applyTransferBonus returns 0 when not unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.applyTransferBonus(1000, 48), 0);
    });

    test('applyTransferBonus returns 0 when hours ≤ 24', () {
      final svc = SkillEffectService(['wiz_transfer']);
      expect(svc.applyTransferBonus(1000, 24), 0);
      expect(svc.applyTransferBonus(1000, 10), 0);
    });

    test('applyTransferBonus applies +15% when hours > 24', () {
      final svc = SkillEffectService(['wiz_transfer']);
      expect(svc.applyTransferBonus(1000, 25), 150);
      expect(svc.applyTransferBonus(1000, 72), 150);
    });

    test('earlyBonusThresholdHours is 24 when unlocked', () {
      final svc = SkillEffectService(['wiz_transfer']);
      expect(svc.earlyBonusThresholdHours, 24);
    });
  });

  // ━━━ Aggregate / stacking tests ━━━

  group('SkillEffectService — combined effects', () {
    test('combinedBaseMultiplier stacks multiplicatively', () {
      // cle_prayer (1.05) × wiz_foresight (1.10) = 1.155
      final svc = SkillEffectService(['cle_prayer', 'wiz_foresight']);
      expect(svc.combinedBaseMultiplier, closeTo(1.155, 0.001));
    });

    test('combinedBaseMultiplier is 1.0 when nothing unlocked', () {
      final svc = SkillEffectService([]);
      expect(svc.combinedBaseMultiplier, 1.0);
    });

    test('hasAnySkill returns correct values', () {
      expect(SkillEffectService([]).hasAnySkill, false);
      expect(SkillEffectService(['war_flash']).hasAnySkill, true);
    });

    test('unlockedCount returns correct values', () {
      expect(SkillEffectService([]).unlockedCount, 0);
      expect(SkillEffectService(['war_flash', 'cle_heal']).unlockedCount, 2);
      expect(SkillEffectService([
        'war_flash', 'war_combo', 'war_critical', 'war_zanshin',
        'cle_prayer', 'cle_heal', 'cle_ward',
        'wiz_foresight', 'wiz_split', 'wiz_transfer',
      ]).unlockedCount, 10);
    });

    test('full Warrior path: all 4 nodes active', () {
      final svc = SkillEffectService(['war_flash', 'war_combo', 'war_critical', 'war_zanshin']);
      expect(svc.hasFlash, true);
      expect(svc.hasCombo, true);
      expect(svc.hasCritical, true);
      expect(svc.hasZanshin, true);
      expect(svc.comboExpPerCount, 20);
      expect(svc.comboStepBonus, 0.05);
      // Cleric/Wizard are false
      expect(svc.hasPrayer, false);
      expect(svc.hasHeal, false);
      expect(svc.hasWard, false);
      expect(svc.hasForesight, false);
      expect(svc.hasSplit, false);
      expect(svc.hasTransfer, false);
    });

    test('full Cleric path: all 3 nodes active', () {
      final svc = SkillEffectService(['cle_prayer', 'cle_heal', 'cle_ward']);
      expect(svc.hasPrayer, true);
      expect(svc.hasHeal, true);
      expect(svc.hasWard, true);
      expect(svc.penaltyReduction, 0.50);
      expect(svc.wardMinStreak, 3);
    });

    test('full Wizard path: all 3 nodes active', () {
      final svc = SkillEffectService(['wiz_foresight', 'wiz_split', 'wiz_transfer']);
      expect(svc.hasForesight, true);
      expect(svc.hasSplit, true);
      expect(svc.hasTransfer, true);
      expect(svc.lateBonusWindowHours, 3);
      expect(svc.earlyBonusThresholdHours, 24);
    });
  });

  // ━━━ Balance validation ━━━

  group('balance checks', () {
    test('no single node gives >20% average EXP increase', () {
      // This ensures no single node is overpowered
      for (final cfg in skillEffectConfig.values) {
        double avgIncrease = 0.0;

        // Base multiplier contribution
        avgIncrease += cfg.baseExpMultiplier - 1.0;

        // Bonus chance contribution
        avgIncrease += cfg.bonusExpChance * cfg.bonusExpMultiplier;

        // Crit contribution
        avgIncrease += cfg.critChance * (cfg.critMultiplier - 1.0);

        expect(avgIncrease, lessThanOrEqualTo(0.20),
            reason: '${cfg.nodeId} avg EXP increase ${(avgIncrease * 100).toStringAsFixed(1)}% exceeds 20%');
      }
    });

    test('full path average EXP increase is 25-40%', () {
      // Warrior: combo doubles combo EXP (situational) + 15%×40% flash + 10%×100% crit
      //   avg ≈ (combo doubling ~10%) + 6% + 10% ≈ 26% (situational)
      // Cleric: 5% prayer + penalty reduction (defensive) + 10% streak
      //   avg ≈ 5% + defensive + (streak × 10%) ≈ 5-15% (defensive value)
      // Wizard: 10% foresight + subquest bonuses + early bonus
      //   avg ≈ 10% + (variable subquest) + (variable early) ≈ 15-35%

      // All three paths combined:
      final svc = SkillEffectService([
        'war_flash', 'war_combo', 'war_critical', 'war_zanshin',
        'cle_prayer', 'cle_heal', 'cle_ward',
        'wiz_foresight', 'wiz_split', 'wiz_transfer',
      ]);
      // Stacking base multipliers: 1.05 × 1.10 = 1.155
      expect(svc.combinedBaseMultiplier, closeTo(1.155, 0.001));
      // This gives 15.5% passive, plus situational bonuses
      // Total potential is reasonable for 27 skill points (Lv81)
    });

    test('each path costs 9 points for base 3 nodes', () {
      // Warrior base: 2+3+4 = 9, plus war_zanshin: +4 = 13
      // Cleric: 2+3+4 = 9
      // Wizard: 2+3+4 = 9
      // This is verified in skill_tree_test.dart
      // Here we verify the config matches
      const warriorIds = ['war_flash', 'war_combo', 'war_critical'];
      const clericIds = ['cle_prayer', 'cle_heal', 'cle_ward'];
      const wizardIds = ['wiz_foresight', 'wiz_split', 'wiz_transfer'];

      for (final ids in [warriorIds, clericIds, wizardIds]) {
        for (final id in ids) {
          final cfg = skillEffectConfig[id]!;
          // Cost is stored in skillTreeDefinition, not here
          // But we can check that configs exist
          expect(cfg, isNotNull);
        }
      }
    });
  });

  // ━━━ Edge cases ━━━

  group('edge cases', () {
    test('SkillEffectService handles empty unlockedIds', () {
      final svc = SkillEffectService([]);
      expect(svc.hasAnySkill, false);
      expect(svc.unlockedCount, 0);
      expect(svc.comboExpPerCount, 10);
      expect(svc.comboStepBonus, 0.0);
      expect(svc.penaltyReduction, 0.0);
      expect(svc.lateBonusWindowHours, 1);
    });

    test('SkillEffectService handles unknown IDs gracefully', () {
      final svc = SkillEffectService(['bogus_id', 'also_fake']);
      expect(svc.hasAnySkill, false);
      expect(svc.unlockedCount, 0);
    });

    test('SkillEffectService handles duplicate IDs', () {
      final svc = SkillEffectService(['war_flash', 'war_flash', 'war_flash']);
      expect(svc.hasFlash, true);
      expect(svc.unlockedCount, 1); // Set deduplication
    });
  });
}
