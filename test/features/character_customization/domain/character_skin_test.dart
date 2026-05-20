import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart';

void main() {
  group('SkinSlot', () {
    test('5つのスロットが定義されている', () {
      expect(SkinSlot.values.length, 5);
      expect(SkinSlot.values, contains(SkinSlot.face));
      expect(SkinSlot.values, contains(SkinSlot.hair));
      expect(SkinSlot.values, contains(SkinSlot.armor));
      expect(SkinSlot.values, contains(SkinSlot.weapon));
      expect(SkinSlot.values, contains(SkinSlot.shield));
    });

    test('displayName が日本語で返る', () {
      expect(SkinSlot.face.displayName, '顔');
      expect(SkinSlot.hair.displayName, '髪型');
      expect(SkinSlot.armor.displayName, '鎧');
      expect(SkinSlot.weapon.displayName, '武器');
      expect(SkinSlot.shield.displayName, '盾');
    });
  });

  group('CharacterSkin', () {
    test('デフォルトは全スロットが "default"', () {
      const skin = CharacterSkin();
      expect(skin.faceId, 'default');
      expect(skin.hairId, 'default');
      expect(skin.armorId, 'default');
      expect(skin.weaponId, 'default');
      expect(skin.shieldId, 'default');
    });

    test('カスタム値で初期化できる', () {
      const skin = CharacterSkin(
        faceId: 'warrior_face',
        hairId: 'spiky',
        armorId: 'iron_armor',
        weaponId: 'longsword',
        shieldId: 'round_shield',
      );
      expect(skin.faceId, 'warrior_face');
      expect(skin.hairId, 'spiky');
      expect(skin.armorId, 'iron_armor');
      expect(skin.weaponId, 'longsword');
      expect(skin.shieldId, 'round_shield');
    });

    test('copyWith で一部だけ変更できる', () {
      const skin = CharacterSkin(
        faceId: 'warrior_face',
        armorId: 'iron_armor',
      );
      final updated = skin.copyWith(armorId: 'gold_armor');

      expect(updated.faceId, 'warrior_face'); // 変更なし
      expect(updated.armorId, 'gold_armor'); // 変更あり
      expect(updated.hairId, 'default'); // デフォルトのまま
    });

    test('等価比較が正しく動作する', () {
      const a = CharacterSkin(faceId: 'warrior_face', armorId: 'iron_armor');
      const b = CharacterSkin(faceId: 'warrior_face', armorId: 'iron_armor');
      const c = CharacterSkin(faceId: 'warrior_face', armorId: 'gold_armor');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('getSlot で指定スロットの値を取得できる', () {
      const skin = CharacterSkin(weaponId: 'katana');
      expect(skin.getSlot(SkinSlot.weapon), 'katana');
      expect(skin.getSlot(SkinSlot.face), 'default');
    });

    test('withSlot で指定スロットだけ変更した新しいCharacterSkinを返す', () {
      const skin = CharacterSkin();
      final updated = skin.withSlot(SkinSlot.hair, 'ponytail');

      expect(updated.hairId, 'ponytail');
      expect(updated.faceId, 'default'); // 他はそのまま
    });

    test('toMap / fromMap で永続化・復元できる', () {
      const original = CharacterSkin(
        faceId: 'warrior_face',
        hairId: 'spiky',
        armorId: 'iron_armor',
        weaponId: 'longsword',
        shieldId: 'round_shield',
      );
      final map = original.toMap();
      final restored = CharacterSkin.fromMap(map);

      expect(restored, equals(original));
    });

    test('fromMap で欠けたキーはデフォルト値になる', () {
      final restored = CharacterSkin.fromMap({'armorId': 'leather'});
      expect(restored.armorId, 'leather');
      expect(restored.faceId, 'default');
      expect(restored.hairId, 'default');
    });
  });

  group('SkinDefinition', () {
    test('スキン定義の生成とプロパティ', () {
      const def = SkinDefinition(
        id: 'iron_armor',
        slot: SkinSlot.armor,
        name: '鉄の鎧',
        icon: '🛡️',
        description: '堅固な鉄の鎧',
        unlockConditionDescription: '称号「鉄壁の守り手」を獲得',
      );

      expect(def.id, 'iron_armor');
      expect(def.slot, SkinSlot.armor);
      expect(def.name, '鉄の鎧');
      expect(def.icon, '🛡️');
      expect(def.unlockConditionDescription, '称号「鉄壁の守り手」を獲得');
    });

    test('isUnlocked が条件に基づいて判定する', () {
      const def = SkinDefinition(
        id: 'flame_crown',
        slot: SkinSlot.hair,
        name: '炎の冠',
        icon: '👑',
        unlockConditionDescription: 'ストリーク30日達成',
        requiredStreakDays: 30,
      );

      // 条件を満たす
      expect(def.isUnlocked(streakDays: 30, totalTasks: 50, level: 10, titles: []), true);
      expect(def.isUnlocked(streakDays: 31, totalTasks: 50, level: 10, titles: []), true);
      // 条件を満たさない
      expect(def.isUnlocked(streakDays: 29, totalTasks: 50, level: 10, titles: []), false);
      expect(def.isUnlocked(streakDays: 0, totalTasks: 50, level: 10, titles: []), false);
    });

    test('requiredTitle で称号による解放判定', () {
      const def = SkinDefinition(
        id: 'dragon_helm',
        slot: SkinSlot.face,
        name: '竜の兜',
        icon: '🐲',
        unlockConditionDescription: '称号「伝説の討伐者」獲得',
        requiredTitle: '伝説の討伐者',
      );

      expect(def.isUnlocked(titles: ['伝説の討伐者']), true);
      expect(def.isUnlocked(titles: ['見習い冒険者']), false);
      expect(def.isUnlocked(titles: []), false);
    });

    test('requiredLevel でレベルによる解放判定', () {
      const def = SkinDefinition(
        id: 'royal_armor',
        slot: SkinSlot.armor,
        name: '王家の鎧',
        icon: '👑',
        unlockConditionDescription: '冒険者Lv.50達成',
        requiredLevel: 50,
      );

      expect(def.isUnlocked(level: 50), true);
      expect(def.isUnlocked(level: 100), true);
      expect(def.isUnlocked(level: 49), false);
      expect(def.isUnlocked(level: 1), false);
    });

    test('requiredTotalTasks で討伐数による解放判定', () {
      const def = SkinDefinition(
        id: 'veteran_shield',
        slot: SkinSlot.shield,
        name: '歴戦の盾',
        icon: '🛡️',
        unlockConditionDescription: '累計100クエスト討伐',
        requiredTotalTasks: 100,
      );

      expect(def.isUnlocked(totalTasks: 100), true);
      expect(def.isUnlocked(totalTasks: 200), true);
      expect(def.isUnlocked(totalTasks: 99), false);
    });

    test('複合条件（AND）の判定', () {
      const def = SkinDefinition(
        id: 'master_sword',
        slot: SkinSlot.weapon,
        name: '免許皆伝の剣',
        icon: '⚔️',
        unlockConditionDescription: 'Lv.30以上かつストリーク7日以上',
        requiredLevel: 30,
        requiredStreakDays: 7,
      );

      // 両方満たす → 解放
      expect(def.isUnlocked(level: 30, streakDays: 7), true);
      // 片方のみ → 未解放
      expect(def.isUnlocked(level: 30, streakDays: 6), false);
      expect(def.isUnlocked(level: 29, streakDays: 7), false);
      // 両方満たさない → 未解放
      expect(def.isUnlocked(level: 1, streakDays: 0), false);
    });
  });

  group('SkinCatalog', () {
    test('全スロットに少なくとも1つのデフォルトスキンがある', () {
      for (final slot in SkinSlot.values) {
        final skins = SkinCatalog.skinsForSlot(slot);
        expect(skins, isNotEmpty, reason: '${slot.displayName}にスキンがない');
        // デフォルトスキン（id=default）が存在すること
        expect(skins.any((s) => s.id == 'default'), true,
            reason: '${slot.displayName}にデフォルトスキンがない');
      }
    });

    test('解放済みスキン一覧を取得できる', () {
      final unlocked = SkinCatalog.unlockedSkins(
        level: 50,
        streakDays: 30,
        totalTasks: 200,
        titles: ['伝説の討伐者', '鉄壁の守り手'],
      );

      expect(unlocked, isNotEmpty);
      // デフォルトスキンは常に解放済み
      expect(unlocked.any((s) => s.id == 'default'), true);
    });

    test('findById でスキン定義を取得できる', () {
      final skin = SkinCatalog.findById('default');
      expect(skin, isNotNull);
      expect(skin!.id, 'default');

      // 存在しないID
      expect(SkinCatalog.findById('nonexistent'), isNull);
    });

    test('スロット別の解放済みスキン一覧', () {
      final armors = SkinCatalog.unlockedSkinsForSlot(
        SkinSlot.armor,
        level: 50,
        streakDays: 30,
        totalTasks: 200,
        titles: [],
      );

      expect(armors, isNotEmpty);
      expect(armors.every((s) => s.slot == SkinSlot.armor), true);
      // 解放条件を満たすものだけが含まれる
      for (final skin in armors) {
        expect(
          skin.isUnlocked(level: 50, streakDays: 30, totalTasks: 200, titles: []),
          true,
          reason: '${skin.name} が誤って解放済みと判定された',
        );
      }
    });
  });
}
