import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/services/skill_progression_service.dart';

void main() {
  group('SkillProgressionService.compute — ツリー進捗', () {
    test('初期プレイヤー: 全ツリー 0/N・次ノードは最安の1行目', () {
      final report = SkillProgressionService.compute(Player());
      expect(report.trees.length, 3);
      expect(report.skillPoints, 0);

      final samurai =
          report.trees.firstWhere((t) => t.tree == Job.samurai);
      expect(samurai.unlockedCount, 0);
      expect(samurai.totalCount, 4);
      expect(samurai.nextNode!.id, 'war_flash');
      expect(samurai.nextNodeAffordable, false);
      expect(samurai.pointsShortfall, 2);
    });

    test('スキルポイント付与で次ノードが解放可能になる', () {
      final player = Player(skillPoints: 2);
      final report = SkillProgressionService.compute(player);
      final samurai = report.trees.firstWhere((t) => t.tree == Job.samurai);
      expect(samurai.nextNodeAffordable, true);
      expect(samurai.pointsShortfall, 0);
    });

    test('war_flash 解放後: 侍ツリーの次は war_combo', () {
      final player =
          Player(skillPoints: 9, unlockedSkillIds: ['war_flash']);
      final samurai =
          SkillProgressionService.compute(player).trees.firstWhere(
                (t) => t.tree == Job.samurai,
              );
      expect(samurai.unlockedCount, 1);
      expect(samurai.nextNode!.id, 'war_combo');
      expect(samurai.nextNodeAffordable, true);
    });

    test('前提未達成のノードは次候補に選ばれない', () {
      // skillPoints は十分だが war_flash 未解放 → war_combo/war_critical 不可
      final player = Player(skillPoints: 10);
      final samurai =
          SkillProgressionService.compute(player).trees.firstWhere(
                (t) => t.tree == Job.samurai,
              );
      expect(samurai.nextNode!.id, 'war_flash');
    });

    test('全ノード解放で nextNode=null・isComplete', () {
      final player = Player(
        skillPoints: 0,
        unlockedSkillIds: [
          'war_flash', 'war_combo', 'war_critical', 'war_zanshin',
        ],
      );
      final samurai =
          SkillProgressionService.compute(player).trees.firstWhere(
                (t) => t.tree == Job.samurai,
              );
      expect(samurai.isComplete, true);
      expect(samurai.nextNode, null);
      expect(samurai.hasNextNode, false);
      expect(samurai.pointsShortfall, 0);
    });

    test('合計: 初期で 0/10 ノード', () {
      final report = SkillProgressionService.compute(Player());
      expect(report.totalUnlocked, 0);
      expect(report.totalNodes, 10);
    });
  });

  group('SkillProgressionService.compute — ジョブ習得進捗', () {
    test('初期プレイヤー: 浪人 Lv1・他職も Lv1', () {
      final report = SkillProgressionService.compute(Player());
      expect(report.jobs.length, 4);

      final adventurer =
          report.jobs.firstWhere((j) => j.job == Job.adventurer);
      expect(adventurer.level, 1);
      expect(adventurer.masterLevel, 10);
      expect(adventurer.levelsToMaster, 9);
      expect(adventurer.isMastered, false);
    });

    test('冒険者 Lv10 で浪人は習得済み', () {
      final player = Player(jobLevels: {
        Job.adventurer: 10,
        Job.samurai: 1,
        Job.monk: 1,
        Job.mystic: 1,
      });
      final report = SkillProgressionService.compute(player);
      final adventurer =
          report.jobs.firstWhere((j) => j.job == Job.adventurer);
      expect(adventurer.isMastered, true);
      expect(adventurer.levelsToMaster, 0);

      final samurai = report.jobs.firstWhere((j) => j.job == Job.samurai);
      expect(samurai.masterLevel, 14);
      expect(samurai.levelsToMaster, 13);
    });

    test('侍 Lv14 で習得済み・進捗率は上限1.0', () {
      final player = Player(jobLevels: {
        Job.adventurer: 10,
        Job.samurai: 14,
        Job.monk: 1,
        Job.mystic: 1,
      });
      final samurai =
          SkillProgressionService.compute(player).jobs.firstWhere(
                (j) => j.job == Job.samurai,
              );
      expect(samurai.isMastered, true);
      expect(samurai.progressRatio, 1.0);
    });

    test('進捗率はレベル比・クリップ済み', () {
      final player = Player(jobLevels: {
        Job.adventurer: 5,
        Job.samurai: 7,
        Job.monk: 1,
        Job.mystic: 1,
      });
      final samurai =
          SkillProgressionService.compute(player).jobs.firstWhere(
                (j) => j.job == Job.samurai,
              );
      expect(samurai.progressRatio, closeTo(14 / 14 * 0 + 7 / 14, 0.001));
      expect(samurai.progressRatio, 0.5);
    });

    test('レベル超過（Lv20 侍）でも習得済み・比率は1.0', () {
      final player = Player(jobLevels: {
        Job.adventurer: 10,
        Job.samurai: 20,
        Job.monk: 1,
        Job.mystic: 1,
      });
      final samurai =
          SkillProgressionService.compute(player).jobs.firstWhere(
                (j) => j.job == Job.samurai,
              );
      expect(samurai.isMastered, true);
      expect(samurai.levelsToMaster, 0);
      expect(samurai.progressRatio, 1.0);
    });
  });
}