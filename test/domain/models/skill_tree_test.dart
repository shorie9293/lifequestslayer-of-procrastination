import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/skill_tree.dart';

void main() {
  // ━━━ スキルポイント計算 ━━━

  group('totalEarnedSkillPoints', () {
    test('Lv 1-2 は 0 ポイント', () {
      expect(totalEarnedSkillPoints(1), 0);
      expect(totalEarnedSkillPoints(2), 0);
    });

    test('Lv 3-5 は 1 ポイント', () {
      expect(totalEarnedSkillPoints(3), 1);
      expect(totalEarnedSkillPoints(4), 1);
      expect(totalEarnedSkillPoints(5), 1);
    });

    test('Lv 6-8 は 2 ポイント', () {
      expect(totalEarnedSkillPoints(6), 2);
      expect(totalEarnedSkillPoints(7), 2);
      expect(totalEarnedSkillPoints(8), 2);
    });

    test('Lv 9-11 は 3 ポイント', () {
      expect(totalEarnedSkillPoints(9), 3);
      expect(totalEarnedSkillPoints(11), 3);
    });

    test('Lv 99 で 最大 33 ポイント', () {
      expect(totalEarnedSkillPoints(99), 33);
    });

    test('Lv 0 以下でも 0 を返す', () {
      expect(totalEarnedSkillPoints(0), 0);
      expect(totalEarnedSkillPoints(-1), 0);
    });
  });

  group('totalSpentSkillPoints', () {
    test('何も解放していなければ 0', () {
      expect(totalSpentSkillPoints([]), 0);
    });

    test('一つのノード解放でそのコスト分加算', () {
      expect(totalSpentSkillPoints(['war_flash']), 2);
    });

    test('パス全体で 9 ポイント（2+3+4）', () {
      expect(totalSpentSkillPoints(['war_flash', 'war_combo', 'war_critical']), 9);
    });

    test('全ノード解放で 27 ポイント', () {
      expect(
        totalSpentSkillPoints([
          'war_flash', 'war_combo', 'war_critical',
          'cle_prayer', 'cle_heal', 'cle_ward',
          'wiz_foresight', 'wiz_split', 'wiz_transfer',
        ]),
        27,
      );
    });
  });

  group('availableSkillPoints', () {
    test('Lv1 冒険者は 0', () {
      expect(availableSkillPoints(1, []), 0);
    });

    test('Lv6 冒険者は 2（未使用）', () {
      expect(availableSkillPoints(6, []), 2);
    });

    test('Lv6 冒険者、war_flash 解放済み → 残り 0', () {
      expect(availableSkillPoints(6, ['war_flash']), 0);
    });

    test('Lv6 冒険者、全解放しようとすると -25（不可能）', () {
      final all = [
        'war_flash', 'war_combo', 'war_critical',
        'cle_prayer', 'cle_heal', 'cle_ward',
        'wiz_foresight', 'wiz_split', 'wiz_transfer',
      ];
      expect(availableSkillPoints(6, all), -25);
    });
  });

  // ━━━ スキルノード定義 ━━━

  group('skillTreeDefinition', () {
    test('9 ノードが定義されている', () {
      expect(skillTreeDefinition.length, 9);
    });

    test('各ツリーに 3 ノードずつ', () {
      for (final tree in [Job.samurai, Job.monk, Job.mystic]) {
        final nodes =
            skillTreeDefinition.values.where((n) => n.tree == tree).toList();
        expect(nodes.length, 3, reason: 'Tree $tree should have 3 nodes');
      }
    });

    test('すべてのノードIDがユニーク', () {
      final ids = skillTreeDefinition.keys.toList();
      expect(ids.toSet().length, ids.length);
    });

    test('前提条件ノードは定義に存在する', () {
      for (final node in skillTreeDefinition.values) {
        for (final prereq in node.prerequisites) {
          expect(skillTreeDefinition.containsKey(prereq), true,
              reason: 'Prerequisite $prereq of ${node.id} not found');
        }
      }
    });

    test('各パスのコスト合計は 9', () {
      for (final tree in [Job.samurai, Job.monk, Job.mystic]) {
        final total = skillTreeDefinition.values
            .where((n) => n.tree == tree)
            .fold<int>(0, (sum, n) => sum + n.pointCost);
        expect(total, 9, reason: 'Path $tree total cost mismatch');
      }
    });
  });

  // ━━━ 可視性と解放判定 ━━━

  group('isNodeVisible', () {
    test('前提条件がないノードは常に可視', () {
      expect(
        isNodeVisible(skillTreeDefinition['war_flash']!, unlockedIds: []),
        true,
      );
    });

    test('前提条件が満たされていなければ不可視', () {
      expect(
        isNodeVisible(skillTreeDefinition['war_combo']!, unlockedIds: []),
        false,
      );
    });

    test('前提条件の1つでも解放されていれば可視', () {
      expect(
        isNodeVisible(skillTreeDefinition['war_combo']!,
            unlockedIds: ['war_flash']),
        true,
      );
    });
  });

  group('canUnlockNode', () {
    test('前提条件満たし・ポイント十分 → 解放可', () {
      expect(
        canUnlockNode(
          skillTreeDefinition['war_flash']!,
          unlockedIds: [],
          skillPoints: 2,
        ),
        true,
      );
    });

    test('ポイント不足 → 不可', () {
      expect(
        canUnlockNode(
          skillTreeDefinition['war_combo']!,
          unlockedIds: ['war_flash'],
          skillPoints: 2,
        ),
        false,
      );
    });

    test('前提条件未達成 → 不可', () {
      expect(
        canUnlockNode(
          skillTreeDefinition['war_combo']!,
          unlockedIds: [],
          skillPoints: 5,
        ),
        false,
      );
    });

    test('既解放済み → 不可', () {
      expect(
        canUnlockNode(
          skillTreeDefinition['war_flash']!,
          unlockedIds: ['war_flash'],
          skillPoints: 5,
        ),
        false,
      );
    });

    test('スキルポイントがちょうどコスト分 → 可', () {
      expect(
        canUnlockNode(
          skillTreeDefinition['war_critical']!,
          unlockedIds: ['war_flash', 'war_combo'],
          skillPoints: 4,
        ),
        true,
      );
    });
  });

  group('visibleNodes', () {
    test('未解放時は全ルートノード (3つ) が可視', () {
      final visible = visibleNodes([]).toList();
      expect(visible.length, 3);
      expect(visible.map((n) => n.id).toSet(),
          {'war_flash', 'cle_prayer', 'wiz_foresight'});
    });

    test('war_flash 解放後は war_combo も可視に (計4)', () {
      final visible = visibleNodes(['war_flash']).toList();
      expect(visible.length, 4);
    });
  });

  group('unlockableNodes', () {
    test('Lv6 冒険者（2ポイント）→ war_flash のみ解放可', () {
      final nodes =
          unlockableNodes(unlockedIds: [], skillPoints: 2).toList();
      expect(nodes.length, 3); // 3つのルートノードはどれも2ポイント
      expect(nodes.map((n) => n.id).toSet(),
          {'war_flash', 'cle_prayer', 'wiz_foresight'});
    });

    test('war_flash 解放済み・8ポイント → war_combo 可（war_critical は前提不足で不可）', () {
      final nodes = unlockableNodes(
              unlockedIds: ['war_flash'], skillPoints: 8)
          .toList();
      final ids = nodes.map((n) => n.id).toSet();
      expect(ids.contains('war_combo'), true);
      // war_critical requires war_combo as prerequisite — not yet unlocked
      expect(ids.contains('war_critical'), false);
    });
  });
}
