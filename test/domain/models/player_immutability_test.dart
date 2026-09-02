import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart'
    show CharacterSkin, SkinSlot;

/// 道標§五#7: Player モデルイミュータブル化の試練（第一段階）。
///
/// 現時点で実装済みの基盤：
/// 1. Player.copyWith — 指定フィールドのみ変更した新インスタンスを返し、元を不変に保つ。
/// 2. TaskStreak のイミュータブル化（final + copyWith）。
/// 3. recordTaskCompletion が TaskStreak.copyWith 経由で更新する。
void main() {
  group('Player.copyWith', () {
    test('指定したフィールドのみ変更し新インスタンスを返す', () {
      final p = Player();
      final p2 = p.copyWith(coins: 100);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p2.coins, 100);
      expect(p.coins, 0, reason: '元インスタンスは不変');
    });

    test('未指定フィールドは元の値を保持する', () {
      final p = Player()
          .copyWith(coins: 10, gems: 20, currentJob: Job.samurai);
      final p2 = p.copyWith(coins: 99);

      expect(p2.gems, 20, reason: '未指定フィールドは保持');
      expect(p2.currentJob, Job.samurai);
      expect(p2.coins, 99);
    });

    test('nullable フィールドを null にクリアできる', () {
      final p = Player().copyWith(equippedTitle: '勇者');
      expect(p.equippedTitle, '勇者');
      final cleared = p.copyWith(equippedTitle: null);
      expect(cleared.equippedTitle, isNull, reason: 'nullでクリア可能');
    });

    test('copyWith後も元インスタンスの全フィールドが不変', () {
      final p = Player()
          .copyWith(coins: 50, gems: 7, currentJob: Job.monk, streakDays: 5);
      final before = p.toJson();
      final _ = p.copyWith(coins: 9999);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
    });
  });

  group('TaskStreak イミュータブル', () {
    test('copyWith は新インスタンスを返し元は不変', () {
      final s = TaskStreak(
          currentStreak: 3, lastCompletedDate: DateTime(2026, 1, 1));
      final s2 = s.copyWith(currentStreak: 4);

      expect(identical(s, s2), isFalse);
      expect(s.currentStreak, 3, reason: '元は不変');
      expect(s2.currentStreak, 4);
      expect(s2.lastCompletedDate, DateTime(2026, 1, 1),
          reason: '未指定フィールドは保持');
    });
  });

  group('アニメーション視聴フラグ final（段階返済第二段）', () {
    test('hasSeenMandalaAnimation は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(hasSeenMandalaAnimation: true);

      expect(identical(p, p2), isFalse);
      expect(p.hasSeenMandalaAnimation, isFalse, reason: '元は不変');
      expect(p2.hasSeenMandalaAnimation, isTrue);
    });

    test('hasSeenReversalAnimation は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(hasSeenReversalAnimation: true);

      expect(identical(p, p2), isFalse);
      expect(p.hasSeenReversalAnimation, isFalse, reason: '元は不変');
      expect(p2.hasSeenReversalAnimation, isTrue);
    });

    test('copyWith後も元インスタンスの視聴フラグは不変のまま', () {
      final p = Player();
      final before = p.toJson();
      final _ = p.copyWith(
          hasSeenMandalaAnimation: true, hasSeenReversalAnimation: true);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
    });
  });

  group('装備称号・装備スキン final（段階返済第三段）', () {
    test('equippedTitle は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(equippedTitle: '勇者');

      expect(identical(p, p2), isFalse);
      expect(p.equippedTitle, isNull, reason: '元は不変');
      expect(p2.equippedTitle, '勇者');
    });

    test('equippedTitle は null でクリア可能', () {
      final p = Player().copyWith(equippedTitle: '勇者');
      final cleared = p.copyWith(equippedTitle: null);

      expect(cleared.equippedTitle, isNull, reason: 'nullでクリア可能');
      expect(p.equippedTitle, '勇者', reason: '元は不変');
    });

    test('equippedSkin は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(equippedSkin: 'skin_warrior_01');

      expect(identical(p, p2), isFalse);
      expect(p.equippedSkin, isNull, reason: '元は不変');
      expect(p2.equippedSkin, 'skin_warrior_01');
    });

    test('equippedSkin は null でクリア可能', () {
      final p = Player().copyWith(equippedSkin: 'skin_warrior_01');
      final cleared = p.copyWith(equippedSkin: null);

      expect(cleared.equippedSkin, isNull, reason: 'nullでクリア可能');
      expect(p.equippedSkin, 'skin_warrior_01', reason: '元は不変');
    });

    test('copyWith後も元インスタンスの装備称号・装備スキンは不変のまま', () {
      final p = Player().copyWith(equippedTitle: '英雄', equippedSkin: 'skin_1');
      final before = p.toJson();
      final _ = p.copyWith(equippedTitle: '勇者', equippedSkin: 'skin_2');
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
    });
  });

  group('characterSkin final（段階返済第四段）', () {
    test('characterSkin は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(
          characterSkin: const CharacterSkin(hairId: 'hair_red'));

      expect(identical(p, p2), isFalse);
      expect(p.characterSkin.hairId, 'default', reason: '元は不変');
      expect(p2.characterSkin.hairId, 'hair_red');
    });

    test('copyWithでwithSlot結果を設定でき元は不変', () {
      final p = Player();
      final updated = p.characterSkin.withSlot(SkinSlot.hair, 'hair_blue');
      final p2 = p.copyWith(characterSkin: updated);

      expect(p.characterSkin.hairId, 'default', reason: '元は不変');
      expect(p2.characterSkin.hairId, 'hair_blue');
      expect(identical(p.characterSkin, p2.characterSkin), isFalse);
    });

    test('copyWith後も元インスタンスの characterSkin は不変のまま', () {
      final p = Player()
          .copyWith(characterSkin: const CharacterSkin(hairId: 'hair_black'));
      final before = p.toJson();
      final _ = p.copyWith(
          characterSkin: const CharacterSkin(hairId: 'hair_green'));
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.characterSkin.hairId, 'hair_black');
    });
  });

  group('timesWardenDefeated final（段階返済第五段）', () {
    test('timesWardenDefeated は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(timesWardenDefeated: 3);

      expect(identical(p, p2), isFalse);
      expect(p.timesWardenDefeated, 0, reason: '元は不変');
      expect(p2.timesWardenDefeated, 3);
    });

    test('defeatTimeWarden 相当のcopyWith増分は元を不変に保つ', () {
      final p = Player();
      final p2 = p.copyWith(timesWardenDefeated: p.timesWardenDefeated + 1);

      expect(p.timesWardenDefeated, 0, reason: '元は不変');
      expect(p2.timesWardenDefeated, 1);
    });

    test('copyWith後も元インスタンスの timesWardenDefeated は不変のまま', () {
      final p = Player().copyWith(timesWardenDefeated: 5);
      final before = p.toJson();
      final _ = p.copyWith(timesWardenDefeated: 9);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.timesWardenDefeated, 5);
    });
  });

  group('todayTaskLimitOffset final（段階返済第六段）', () {
    test('todayTaskLimitOffset は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(todayTaskLimitOffset: 4);

      expect(identical(p, p2), isFalse);
      expect(p.todayTaskLimitOffset, 0, reason: '元は不変');
      expect(p2.todayTaskLimitOffset, 4);
    });

    test('checkAndResetMissions相当の nextDay→today 引継は元を不変に保つ', () {
      // player_view_model.checkAndResetMissions の `_player.todayTaskLimitOffset = _player.nextDayTaskLimitOffset` 相当
      final p = Player().copyWith(nextDayTaskLimitOffset: 3);
      final p2 = p.copyWith(todayTaskLimitOffset: p.nextDayTaskLimitOffset);

      expect(p.todayTaskLimitOffset, 0, reason: '元は不変');
      expect(p.nextDayTaskLimitOffset, 3, reason: '元の nextDay も不変');
      expect(p2.todayTaskLimitOffset, 3);
      expect(p2.nextDayTaskLimitOffset, 3);
    });

    test('copyWith後も元インスタンスの todayTaskLimitOffset は不変のまま', () {
      final p = Player().copyWith(todayTaskLimitOffset: 7);
      final before = p.toJson();
      final _ = p.copyWith(todayTaskLimitOffset: 2);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.todayTaskLimitOffset, 7);
    });
  });
}
