import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/services/habit_calendar_service.dart';

void main() {
  // 基準日: 2026-09-15（火）12:00
  final now = DateTime(2026, 9, 15, 12, 0);

  group('HabitCalendarService.buildMonth', () {
    test('活動ゼロでも月のグリッドは構築され、全部未活動', () {
      final cal = HabitCalendarService.compute(
        activityDates: const [],
        now: now,
      );
      expect(cal.month.year, 2026);
      expect(cal.month.month, 9);
      expect(cal.month.daysInMonth, 30);
      expect(cal.month.activeDays, 0);
      expect(cal.month.isEmpty, isTrue);
      expect(cal.isEmpty, isTrue);
      expect(cal.currentStreak, 0);
      expect(cal.longestStreak, 0);
      expect(cal.totalActiveDays, 0);
      // セル数は7の倍数。
      expect(cal.month.cells.length % 7, 0);
    });

    test('月初の曜日に合わせて先頭に空白が入る', () {
      final cal = HabitCalendarService.compute(
        activityDates: const [],
        now: now,
      );
      // 2026-09-01 は火曜 → 日曜始まりで先頭2つが空白。
      expect(cal.month.leadingBlanks, 2);
    });

    test('日別の活動件数を集計し、当日フラグを立てる', () {
      final cal = HabitCalendarService.compute(
        activityDates: [
          DateTime(2026, 9, 1, 8),
          DateTime(2026, 9, 1, 20), // 同日2件
          DateTime(2026, 9, 15, 9),
          DateTime(2026, 8, 31), // 別月は対象月に含めない
        ],
        now: now,
      );
      final day1 = cal.month.days.firstWhere((d) => d.date.day == 1);
      final day15 = cal.month.days.firstWhere((d) => d.date.day == 15);
      final day2 = cal.month.days.firstWhere((d) => d.date.day == 2);
      expect(day1.activityCount, 2);
      expect(day1.isActive, isTrue);
      expect(day15.isToday, isTrue);
      expect(day15.isActive, isTrue);
      expect(day2.isActive, isFalse);
      expect(cal.month.activeDays, 2);
      // 通算活動日は 9/1 と 9/15 に加え 8/31 も含む。
      expect(cal.totalActiveDays, 3);
    });

    test('経過日数を分母に達成率を出す（当月の途中でも不当に低くならない）', () {
      final cal = HabitCalendarService.compute(
        activityDates: [
          for (var d = 1; d <= 15; d++) DateTime(2026, 9, d),
        ],
        now: now,
      );
      expect(cal.month.elapsedDays, 15);
      expect(cal.month.activeDays, 15);
      expect(cal.month.completionRate, 1.0);
    });

    test('過去月は全経過日数を分母にする', () {
      final cal = HabitCalendarService.buildMonth(
        activityDates: [DateTime(2026, 8, 1)],
        year: 2026,
        month: 8,
        today: now,
      );
      expect(cal.month.elapsedDays, 31);
      expect(cal.month.activeDays, 1);
    });

    test('未来日付は統計から除外する', () {
      final cal = HabitCalendarService.compute(
        activityDates: [
          DateTime(2026, 9, 10),
          DateTime(2026, 9, 20), // 未来
        ],
        now: now,
      );
      expect(cal.totalActiveDays, 1);
      expect(cal.month.activeDays, 1);
    });

    test('month が範囲外なら ArgumentError', () {
      expect(
        () => HabitCalendarService.buildMonth(
          activityDates: const [],
          year: 2026,
          month: 13,
          today: now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('連続日数（ストリーク）', () {
    test('今日が活動日なら今日までの連続日数を数える', () {
      final cal = HabitCalendarService.compute(
        activityDates: [
          DateTime(2026, 9, 13),
          DateTime(2026, 9, 14),
          DateTime(2026, 9, 15),
        ],
        now: now,
      );
      expect(cal.currentStreak, 3);
      expect(cal.longestStreak, 3);
    });

    test('今日が未活動でも昨日まで連続していれば継続とみなす', () {
      final cal = HabitCalendarService.compute(
        activityDates: [
          DateTime(2026, 9, 13),
          DateTime(2026, 9, 14),
        ],
        now: now,
      );
      expect(cal.currentStreak, 2);
    });

    test('昨日も未活動なら現在ストリークは0', () {
      final cal = HabitCalendarService.compute(
        activityDates: [
          DateTime(2026, 9, 10),
          DateTime(2026, 9, 11),
        ],
        now: now,
      );
      expect(cal.currentStreak, 0);
    });

    test('最長ストリークは全期間の最大連続を返す', () {
      final cal = HabitCalendarService.compute(
        activityDates: [
          DateTime(2026, 8, 1), DateTime(2026, 8, 2), DateTime(2026, 8, 3),
          DateTime(2026, 8, 4), DateTime(2026, 8, 5),
          DateTime(2026, 9, 14), DateTime(2026, 9, 15),
        ],
        now: now,
      );
      expect(cal.longestStreak, 5);
      expect(cal.currentStreak, 2);
    });

    test('月・年を跨ぐ連続を正しく数える', () {
      final cal = HabitCalendarService.buildMonth(
        activityDates: [
          DateTime(2025, 12, 31),
          DateTime(2026, 1, 1),
        ],
        year: 2026,
        month: 1,
        today: DateTime(2026, 1, 1, 10),
      );
      expect(cal.currentStreak, 2);
      expect(cal.longestStreak, 2);
    });
  });
}
