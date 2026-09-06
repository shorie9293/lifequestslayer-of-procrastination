import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/shared/domain/task_completion_service.dart';
import 'package:rpg_todo/features/character_customization/domain/character_skin.dart'
    show CharacterSkin, SkinSlot;
import 'package:rpg_todo/features/temple/domain/enlightenment_stage.dart';
import 'package:rpg_todo/domain/models/return_mission.dart';

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

  group('gems final（段階返済第七段）', () {
    test('gems は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(gems: 120);

      expect(identical(p, p2), isFalse);
      expect(p.gems, 0, reason: '元は不変');
      expect(p2.gems, 120);
    });

    test('addGems/spendGems 相当の copyWith 増減は元を不変に保つ', () {
      final p = Player().copyWith(gems: 50);
      final added = p.copyWith(gems: p.gems + 10);
      final spent = added.copyWith(gems: added.gems - 30);

      expect(p.gems, 50, reason: '元は不変');
      expect(added.gems, 60);
      expect(spent.gems, 30);
    });

    test('copyWith後も元インスタンスの gems は不変のまま', () {
      final p = Player().copyWith(gems: 99);
      final before = p.toJson();
      final _ = p.copyWith(gems: 1);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.gems, 99);
    });
  });

  group('enlightenmentStage final（段階返済第八段）', () {
    test('enlightenmentStage は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(enlightenmentStage: EnlightenmentStage.engi);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.enlightenmentStage, EnlightenmentStage.shohorin,
          reason: '元は不変（デフォルト初転法輪）');
      expect(p2.enlightenmentStage, EnlightenmentStage.engi);
    });

    test('昇格相当のcopyWith（初転法輪→縁起）は元を不変に保つ', () {
      final p = Player();
      final promoted = p.copyWith(
          wisdomPoints: 10, enlightenmentStage: EnlightenmentStage.engi);

      expect(p.enlightenmentStage, EnlightenmentStage.shohorin,
          reason: '元は不変');
      expect(promoted.enlightenmentStage, EnlightenmentStage.engi);
      expect(promoted.wisdomPoints, 10);
    });

    test('copyWith後も元インスタンスの enlightenmentStage は不変のまま', () {
      final p = Player().copyWith(enlightenmentStage: EnlightenmentStage.engi);
      final before = p.toJson();
      final _ =
          p.copyWith(enlightenmentStage: EnlightenmentStage.ku);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.enlightenmentStage, EnlightenmentStage.engi);
    });
  });

  group('activeReturnMission final（段階返済第九段）', () {
    test('activeReturnMission は copyWith でのみ設定され元は不変', () {
      final p = Player();
      final p2 = p.copyWith(
          activeReturnMission:
              ReturnMission(previousStreak: 5, issuedAt: DateTime(2026, 1, 1)));

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.activeReturnMission, isNull, reason: '元は不変');
      expect(p2.activeReturnMission, isNotNull);
      expect(p2.activeReturnMission!.previousStreak, 5);
    });

    test('copyWith(activeReturnMission: null) でクリア可能（_unsetと区別）', () {
      final p = Player().copyWith(
          activeReturnMission:
              ReturnMission(previousStreak: 3, issuedAt: DateTime(2026, 1, 1)));
      final cleared = p.copyWith(activeReturnMission: null);

      expect(cleared.activeReturnMission, isNull, reason: 'nullでクリア可');
      expect(p.activeReturnMission, isNotNull, reason: '元は不変');
    });

    test('copyWith後も元インスタンスの activeReturnMission は不変のまま', () {
      final p = Player().copyWith(
          activeReturnMission:
              ReturnMission(previousStreak: 9, issuedAt: DateTime(2026, 1, 1)));
      final before = p.toJson();
      final _ = p.copyWith(activeReturnMission: null);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
    });
  });

  group('lastReturnMissionIssuedAt final（段階返済第九段）', () {
    test('lastReturnMissionIssuedAt は copyWith で設定され元は不変', () {
      final p = Player();
      final p2 = p.copyWith(lastReturnMissionIssuedAt: DateTime(2026, 1, 1));

      expect(identical(p, p2), isFalse);
      expect(p.lastReturnMissionIssuedAt, isNull, reason: '元は不変');
      expect(p2.lastReturnMissionIssuedAt, DateTime(2026, 1, 1));
    });

    test('copyWith(lastReturnMissionIssuedAt: null) でクリア可能', () {
      final p =
          Player().copyWith(lastReturnMissionIssuedAt: DateTime(2026, 1, 1));
      final cleared = p.copyWith(lastReturnMissionIssuedAt: null);

      expect(cleared.lastReturnMissionIssuedAt, isNull, reason: 'nullでクリア可');
      expect(p.lastReturnMissionIssuedAt, isNotNull, reason: '元は不変');
    });
  });

  group('lastMissionResetDate final（段階返済第十段）', () {
    test('lastMissionResetDate は copyWith でのみ設定され元は不変', () {
      final p = Player();
      final p2 = p.copyWith(lastMissionResetDate: DateTime(2026, 1, 1));

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.lastMissionResetDate, isNull, reason: '元は不変');
      expect(p2.lastMissionResetDate, DateTime(2026, 1, 1));
    });

    test('copyWith(lastMissionResetDate: null) でクリア可能', () {
      final p = Player().copyWith(lastMissionResetDate: DateTime(2026, 1, 1));
      final cleared = p.copyWith(lastMissionResetDate: null);

      expect(cleared.lastMissionResetDate, isNull, reason: 'nullでクリア可');
      expect(p.lastMissionResetDate, isNotNull, reason: '元は不変');
    });

    test('日次リセット相当のcopyWith（dailyTasksCompleted: 0 + 日付更新）は元を不変に保つ', () {
      final p = Player();
      final p2 = p.copyWith(
        lastMissionResetDate: DateTime(2026, 1, 2),
      );

      expect(p.lastMissionResetDate, isNull, reason: '元は不変');
      expect(p2.lastMissionResetDate, DateTime(2026, 1, 2));
    });

    test('copyWith後も元インスタンスの lastMissionResetDate は不変のまま', () {
      final p = Player().copyWith(lastMissionResetDate: DateTime(2026, 1, 1));
      final before = p.toJson();
      final _ = p.copyWith(lastMissionResetDate: DateTime(2026, 2, 1));
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.lastMissionResetDate, DateTime(2026, 1, 1));
    });
  });

  group('homeItems/unlockedSkillIds final（段階返済第十一段）', () {
    test('homeItems は copyWith でのみ設定され元は不変', () {
      final p = Player();
      final p2 = p.copyWith(homeItems: ['home_2']);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.homeItems, isEmpty, reason: '元は不変');
      expect(p2.homeItems, ['home_2']);
    });

    test('unlockedSkillIds は copyWith でのみ設定され元は不変', () {
      final p = Player();
      final p2 = p.copyWith(unlockedSkillIds: ['node_a']);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.unlockedSkillIds, isEmpty, reason: '元は不変');
      expect(p2.unlockedSkillIds, ['node_a']);
    });

    test('copyWith後も元インスタンスのhomeItems/unlockedSkillIdsは不変のまま', () {
      final p = Player().copyWith(homeItems: ['home_1'], unlockedSkillIds: ['n1']);
      final before = p.toJson();
      final _ = p.copyWith(homeItems: ['home_9'], unlockedSkillIds: ['n9']);

      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.homeItems, ['home_1']);
      expect(p.unlockedSkillIds, ['n1']);
    });
  });

  group('currentJob final（段階返済第十二段）', () {
    test('currentJob は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(currentJob: Job.samurai);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.currentJob, Job.adventurer, reason: '元は不変（デフォルト冒険者）');
      expect(p2.currentJob, Job.samurai);
    });

    test('changeJob相当のcopyWith（冒険者→侍）は元を不変に保つ', () {
      final p = Player().copyWith(currentJob: Job.samurai);
      final p2 = p.copyWith(currentJob: Job.monk);

      expect(p.currentJob, Job.samurai, reason: '元は不変');
      expect(p2.currentJob, Job.monk);
    });

    test('copyWith後も元インスタンスの currentJob は不変のまま', () {
      final p = Player().copyWith(currentJob: Job.samurai);
      final before = p.toJson();
      final _ = p.copyWith(currentJob: Job.mystic);
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.currentJob, Job.samurai);
    });
  });

  group('streakDays/longestStreak/lastLoginDate final（段階返済第十三段）', () {
    test('streakDays は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(streakDays: 7);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.streakDays, 0, reason: '元は不変（デフォルト0）');
      expect(p2.streakDays, 7);
    });

    test('longestStreak は copyWith でのみ変更可能で元は不変', () {
      final p = Player().copyWith(streakDays: 5);
      final p2 = p.copyWith(longestStreak: 30);

      expect(p.longestStreak, 0, reason: '元は不変（デフォルト0）');
      expect(p2.longestStreak, 30);
      expect(p.streakDays, 5, reason: '元の他フィールドも不変');
    });

    test('lastLoginDate は copyWith でのみ設定され元は不変', () {
      final p = Player();
      final now = DateTime(2026, 1, 1, 10, 0);
      final p2 = p.copyWith(lastLoginDate: now);

      expect(p.lastLoginDate, isNull, reason: '元は不変');
      expect(p2.lastLoginDate, now);
    });

    test('StreakService相当のストリーク継続copyWith（streakDays+1・longest更新）は元を不変に保つ', () {
      final p = Player()
          .copyWith(streakDays: 3, longestStreak: 3, lastLoginDate: DateTime(2026, 1, 1));
      final p2 = p.copyWith(
        streakDays: p.streakDays + 1,
        longestStreak: p.longestStreak > p.streakDays + 1 ? p.longestStreak : p.streakDays + 1,
        lastLoginDate: DateTime(2026, 1, 2),
      );

      expect(p.streakDays, 3, reason: '元は不変');
      expect(p.longestStreak, 3, reason: '元は不変');
      expect(p.lastLoginDate, DateTime(2026, 1, 1), reason: '元は不変');
      expect(p2.streakDays, 4);
      expect(p2.longestStreak, 4);
      expect(p2.lastLoginDate, DateTime(2026, 1, 2));
    });

    test('copyWith後も元インスタンスの streak3字段は不変のまま', () {
      final p = Player().copyWith(
          streakDays: 3, longestStreak: 3, lastLoginDate: DateTime(2026, 1, 1));
      final before = p.toJson();
      final _ = p.copyWith(
          streakDays: 9, longestStreak: 9, lastLoginDate: DateTime(2026, 1, 9));
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.streakDays, 3);
      expect(p.longestStreak, 3);
    });
  });

  group('nextDayTaskLimitOffset/lastRestDate final（段階返済第十四段・宿屋）', () {
    test('nextDayTaskLimitOffset は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final p2 = p.copyWith(nextDayTaskLimitOffset: 2);

      expect(identical(p, p2), isFalse, reason: 'copyWithは新インスタンスを返す');
      expect(p.nextDayTaskLimitOffset, 0, reason: '元は不変（デフォルト0）');
      expect(p2.nextDayTaskLimitOffset, 2);
    });

    test('lastRestDate は copyWith でのみ設定され元は不変（nullクリア可）', () {
      final now = DateTime(2026, 5, 22, 9, 0);
      final p = Player();
      final rested = p.copyWith(lastRestDate: now);

      expect(p.lastRestDate, isNull, reason: '元は不変');
      expect(rested.lastRestDate, now);
      final cleared = rested.copyWith(lastRestDate: null);
      expect(cleared.lastRestDate, isNull, reason: 'nullでクリア可能');
      expect(rested.lastRestDate, now, reason: '元は不変');
    });

    test('FatigueService.restAtInn相当の宿泊copyWith（コイン減・limitBonus付与・lastRest更新）は元を不変に保つ', () {
      final now = DateTime(2026, 5, 22, 9, 0);
      final p = Player().copyWith(coins: 100);
      final updated = p.copyWith(
        coins: p.coins - 50,
        nextDayTaskLimitOffset: 2,
        lastRestDate: now,
      );

      expect(p.coins, 100, reason: '元は不変');
      expect(p.nextDayTaskLimitOffset, 0, reason: '元は不変');
      expect(p.lastRestDate, isNull, reason: '元は不変');
      expect(updated.coins, 50);
      expect(updated.nextDayTaskLimitOffset, 2);
      expect(updated.lastRestDate, now);
    });

    test('copyWith後も元インスタンスの宿屋フィールドは不変のまま', () {
      final now = DateTime(2026, 5, 22, 9, 0);
      final p =
          Player().copyWith(nextDayTaskLimitOffset: 5, lastRestDate: now);
      final before = p.toJson();
      final _ = p.copyWith(
          nextDayTaskLimitOffset: 0, lastRestDate: DateTime(2026, 5, 23));
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.nextDayTaskLimitOffset, 5);
      expect(p.lastRestDate, now);
    });
  });

  group('pomodoroStartTime/streakGraceRemaining/lastStreakGraceReset final（段階返済第十五段）', () {
    test('pomodoroStartTime は copyWith でのみ変更可能で元は不変', () {
      final p = Player();
      final started = p.copyWith(pomodoroStartTime: DateTime(2026, 1, 1, 9, 0));

      expect(p.pomodoroStartTime, isNull, reason: '元は不変');
      expect(started.pomodoroStartTime, DateTime(2026, 1, 1, 9, 0));
      final cleared = started.copyWith(pomodoroStartTime: null);
      expect(cleared.pomodoroStartTime, isNull, reason: 'nullでクリア可能');
      expect(started.pomodoroStartTime, isNotNull, reason: '元は不変');
    });

    test('startPomodoro/endPomodoro相当（純粋copyWith）は元を不変に保つ', () {
      final p = Player();
      final started = p.copyWith(pomodoroStartTime: DateTime(2026, 1, 1, 9, 0));
      final ended = started.copyWith(pomodoroStartTime: null);

      expect(p.pomodoroStartTime, isNull, reason: '元は不変');
      expect(started.pomodoroStartTime, isNotNull);
      expect(ended.pomodoroStartTime, isNull);
    });

    test('streakGraceRemaining は copyWith でのみ変更可能で元は不変（0未満不可）', () {
      final p = Player();
      final consumed = p.copyWith(streakGraceRemaining: 0);

      expect(p.streakGraceRemaining, 1, reason: '元は不変（デフォルト1）');
      expect(consumed.streakGraceRemaining, 0);
    });

    test('lastStreakGraceReset は copyWith でのみ設定され元は不変（nullクリア可）', () {
      final p = Player().copyWith(streakGraceRemaining: 0);
      final reset = p.copyWith(
          lastStreakGraceReset: DateTime(2026, 1, 8), streakGraceRemaining: 1);

      expect(p.lastStreakGraceReset, isNull, reason: '元は不変');
      expect(p.streakGraceRemaining, 0, reason: '元は不変');
      expect(reset.lastStreakGraceReset, DateTime(2026, 1, 8));
      expect(reset.streakGraceRemaining, 1);
    });

    test('resetStreakGraceIfNeeded相当（7日経過で猶予回復）のcopyWithは元を不変に保つ', () {
      final p = Player().copyWith(
        streakGraceRemaining: 0,
        lastStreakGraceReset: DateTime(2026, 1, 1),
      );
      final reset = p.copyWith(
        lastStreakGraceReset: DateTime(2026, 1, 8),
        streakGraceRemaining: 1,
      );

      expect(p.streakGraceRemaining, 0, reason: '元は不変');
      expect(p.lastStreakGraceReset, DateTime(2026, 1, 1), reason: '元は不変');
      expect(reset.streakGraceRemaining, 1);
      expect(reset.lastStreakGraceReset, DateTime(2026, 1, 8));
    });

    test('copyWith後も元インスタンスのポモドーロ/猶予字段は不変のまま', () {
      final p = Player().copyWith(
        pomodoroStartTime: DateTime(2026, 1, 1, 9, 0),
        streakGraceRemaining: 0,
        lastStreakGraceReset: DateTime(2026, 1, 1),
      );
      final before = p.toJson();
      final _ = p.copyWith(
        pomodoroStartTime: DateTime(2026, 1, 2, 10, 0),
        streakGraceRemaining: 1,
        lastStreakGraceReset: DateTime(2026, 1, 8),
      );
      expect(p.toJson(), before, reason: '元インスタンスは不変のまま');
      expect(p.pomodoroStartTime, DateTime(2026, 1, 1, 9, 0));
      expect(p.streakGraceRemaining, 0);
      expect(p.lastDailyComplete, isNull);
    });
  });

  group('task_completion系7字段 final（段階返済第十六段）', () {
    test('7カウンタ字段はfinalでありcopyWithでのみ変更可能', () {
      final p = Player().copyWith(
        comboCount: 3,
        dailyTasksCompleted: 2,
        weeklySRankCompleted: 1,
        totalTasksCompleted: 10,
        totalSRankCompleted: 1,
        totalARankCompleted: 3,
        totalBRankCompleted: 6,
      );

      expect(p.comboCount, 3);
      expect(p.dailyTasksCompleted, 2);
      expect(p.weeklySRankCompleted, 1);
      expect(p.totalTasksCompleted, 10);
      expect(p.totalSRankCompleted, 1);
      expect(p.totalARankCompleted, 3);
      expect(p.totalBRankCompleted, 6);
    });

    test('recordTaskCompletionPureは元インスタンスのtaskStreaksを不変に保つ', () {
      final p = Player().copyWith(
        taskStreaks: {
          't1': TaskStreak(currentStreak: 5, lastCompletedDate: DateTime(2026, 1, 5)),
        },
      );
      final updated = p.recordTaskCompletionPure('t1', DateTime(2026, 1, 6));

      expect(identical(p, updated), isFalse, reason: '純粋版は新インスタンスを返す');
      expect(p.taskStreaks['t1']!.currentStreak, 5, reason: '元は不変');
      expect(updated.taskStreaks['t1']!.currentStreak, 6, reason: '連続日で+1');
      expect(updated.taskStreaks['t1']!.lastCompletedDate, DateTime(2026, 1, 6));
    });

    test('recordTaskCompletionPure: 同日の複数完了は無視・1日空きでリセット', () {
      final p = Player().copyWith(
        taskStreaks: {
          't1': TaskStreak(currentStreak: 5, lastCompletedDate: DateTime(2026, 1, 5)),
        },
      );
      final sameDay = p.recordTaskCompletionPure('t1', DateTime(2026, 1, 5));
      expect(sameDay.taskStreaks['t1']!.currentStreak, 5, reason: '同日は無視');
      expect(identical(p.taskStreaks['t1'], sameDay.taskStreaks['t1']), isTrue);

      final reset = p.recordTaskCompletionPure('t1', DateTime(2026, 1, 9));
      expect(reset.taskStreaks['t1']!.currentStreak, 1, reason: '1日以上空きでリセット');
      expect(p.taskStreaks['t1']!.currentStreak, 5, reason: '元は不変');
    });

    test('recordDailyCompletionPureは元を不変に保ち初回のみbuff増分', () {
      final p = Player().copyWith(warriorDailyBuff: 3);
      final updated = p.recordDailyCompletionPure();

      expect(identical(p, updated), isFalse);
      expect(p.warriorDailyBuff, 3, reason: '元は不変');
      expect(p.lastDailyComplete, isNull);
      expect(updated.warriorDailyBuff, 4);
      expect(updated.lastDailyComplete, isNotNull);

      final twice = updated.recordDailyCompletionPure();
      expect(twice.warriorDailyBuff, 4, reason: '同日2回目は無視');
      expect(identical(twice, updated), isTrue, reason: '同日は同一インスタンス');
    });

    test('addExpPureは元インスタンスのjobLevels/jobExps/skillPointsを不変に保つ', () {
      final p = Player().copyWith(jobLevels: {Job.adventurer: 1}, jobExps: {Job.adventurer: 40});
      final (updated, leveledUp) = p.addExpPure(50); // Lv1→2 (50EXP)

      expect(leveledUp, isTrue);
      expect(identical(p, updated), isFalse);
      expect(p.jobLevels[Job.adventurer], 1, reason: '元は不変');
      expect(p.jobExps[Job.adventurer], 40, reason: '元は不変');
      expect(p.skillPoints, 0, reason: '元は不変');
      expect(updated.jobLevels[Job.adventurer], 2);
      expect(updated.skillPoints, greaterThanOrEqualTo(0));
    });

    test('TaskCompletionService.completeは引数playerを不変に保ちupdatedPlayerで返す', () {
      final player = Player().copyWith(jobLevels: {Job.adventurer: 10});
      final before = player.toJson();
      final task = Task(
        id: 'pure-1',
        title: '純粋化試練',
        status: TaskStatus.active,
        rank: QuestRank.B,
      );

      final result = TaskCompletionService().complete(
        task: task,
        player: player,
        hasShownFatiguePopupToday: false,
        knowledgeQuestEnabled: false,
      );

      expect(result, isNotNull);
      expect(player.toJson(), before, reason: '引数playerは不変');
      expect(identical(result!.updatedPlayer, player), isFalse);
      expect(result.updatedPlayer.totalTasksCompleted, 1);
      expect(result.updatedPlayer.dailyTasksCompleted, 1);
      expect(result.updatedPlayer.coins, greaterThanOrEqualTo(10));
      expect(result.updatedPlayer.taskStreaks['pure-1']!.currentStreak, 1);
    });
  });
}
