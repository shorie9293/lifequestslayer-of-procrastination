import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_service.dart';
import 'package:rpg_todo/features/streak_freeze/domain/streak_freeze_state.dart';

void main() {
  group('dateKey / missedDaysBetween', () {
    test('dateKey はゼロ埋め YYYY-MM-DD', () {
      expect(StreakFreezeService.dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('前回なしは休み0日', () {
      expect(StreakFreezeService.missedDaysBetween(null, DateTime(2026, 10, 20)),
          0);
    });

    test('同日・昨日は休み0日', () {
      final now = DateTime(2026, 10, 20, 9);
      expect(StreakFreezeService.missedDaysBetween(DateTime(2026, 10, 20, 1), now), 0);
      expect(StreakFreezeService.missedDaysBetween(DateTime(2026, 10, 19, 23), now), 0);
    });

    test('2日前は休み1日、4日前は休み3日', () {
      final now = DateTime(2026, 10, 20, 9);
      expect(StreakFreezeService.missedDaysBetween(DateTime(2026, 10, 18), now), 1);
      expect(StreakFreezeService.missedDaysBetween(DateTime(2026, 10, 16), now), 3);
    });

    test('missedDateKeys は休んだ日を古い順に返す', () {
      final keys = StreakFreezeService.missedDateKeys(
          DateTime(2026, 10, 17), DateTime(2026, 10, 20));
      expect(keys, ['2026-10-18', '2026-10-19']);
    });

    test('休みなしは空', () {
      expect(
          StreakFreezeService.missedDateKeys(
              DateTime(2026, 10, 19), DateTime(2026, 10, 20)),
          isEmpty);
    });
  });

  group('milestonesUpTo / reconcile', () {
    test('7日未満はマイルストーンなし', () {
      expect(StreakFreezeService.milestonesUpTo(6), isEmpty);
      expect(StreakFreezeService.milestonesUpTo(7), [7]);
      expect(StreakFreezeService.milestonesUpTo(15), [7, 14]);
    });

    test('7日到達で1枚付与', () {
      final (state, granted) = StreakFreezeService.reconcile(
          StreakFreezeState.defaults, 7);
      expect(granted, 1);
      expect(state.tickets, 1);
      expect(state.grantedMilestones, [7]);
    });

    test('冪等（同じ連続日数で二重付与しない）', () {
      final (first, _) = StreakFreezeService.reconcile(
          StreakFreezeState.defaults, 14);
      expect(first.tickets, 2);
      final (second, granted2) = StreakFreezeService.reconcile(first, 14);
      expect(granted2, 0);
      expect(second.tickets, 2);
      expect(second.grantedMilestones, [7, 14]);
    });

    test('上限3枚を超える分は付与せずマイルストーンだけ記録する', () {
      final (state, granted) = StreakFreezeService.reconcile(
          const StreakFreezeState(tickets: 3), 21);
      expect(granted, 0);
      expect(state.tickets, 3);
      expect(state.grantedMilestones, [7, 14, 21]);
    });

    test('上限まで残り1枚なら1枚だけ付与', () {
      final (state, granted) = StreakFreezeService.reconcile(
          const StreakFreezeState(tickets: 2), 21);
      expect(granted, 1);
      expect(state.tickets, 3);
    });
  });

  group('consume', () {
    test('券不足は ArgumentError', () {
      expect(
        () => StreakFreezeService.consume(
          const StreakFreezeState(tickets: 1),
          missedDays: 2,
          previousStreak: 5,
          now: DateTime(2026, 10, 20),
        ),
        throwsArgumentError,
      );
    });

    test('休み0日は ArgumentError', () {
      expect(
        () => StreakFreezeService.consume(
          const StreakFreezeState(tickets: 1),
          missedDays: 0,
          previousStreak: 5,
          now: DateTime(2026, 10, 20),
        ),
        throwsArgumentError,
      );
    });

    test('券を減らし履歴に1件積む（入力非破壊）', () {
      final before = const StreakFreezeState(tickets: 2);
      final after = StreakFreezeService.consume(
        before,
        missedDays: 1,
        previousStreak: 12,
        now: DateTime(2026, 10, 20, 8),
        coveredDates: const ['2026-10-19'],
      );
      expect(after.tickets, 1);
      expect(after.history.length, 1);
      expect(after.history.single.keptStreak, 12);
      expect(after.history.single.coveredDates, ['2026-10-19']);
      expect(before.tickets, 2, reason: '入力は変更しない');
      expect(before.history, isEmpty);
    });
  });

  group('canCover / ticketsNeeded', () {
    test('1日休みは1枚で足りる', () {
      expect(StreakFreezeService.ticketsNeeded(1), 1);
      expect(
          StreakFreezeService.canCover(
              const StreakFreezeState(tickets: 1), 1),
          isTrue);
      expect(
          StreakFreezeService.canCover(
              const StreakFreezeState(tickets: 1), 2),
          isFalse);
    });

    test('休み0日は対象外', () {
      expect(StreakFreezeService.canCover(const StreakFreezeState(tickets: 3), 0),
          isFalse);
    });
  });

  group('restorePlayer', () {
    test('切断で1になった連続日数を previous+1 へ戻す', () {
      final broken = Player(
        streakDays: 1,
        longestStreak: 20,
        lastLoginDate: DateTime(2026, 10, 20, 8),
        coins: 100,
      );
      final restored = StreakFreezeService.restorePlayer(
        broken,
        previousStreak: 12,
        now: DateTime(2026, 10, 20, 9),
      );
      expect(restored.streakDays, 13);
      expect(restored.longestStreak, 20);
      expect(restored.lastLoginDate, DateTime(2026, 10, 20, 9));
      expect(restored.coins, 100, reason: '報酬は再計算しない');
      expect(broken.streakDays, 1, reason: '入力非破壊');
    });

    test('最長記録を超えるなら更新する', () {
      final broken = Player(streakDays: 1, longestStreak: 5);
      final restored = StreakFreezeService.restorePlayer(
        broken,
        previousStreak: 9,
        now: DateTime(2026, 10, 20),
      );
      expect(restored.streakDays, 10);
      expect(restored.longestStreak, 10);
    });
  });
}
