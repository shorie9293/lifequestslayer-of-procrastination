import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_service.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_settings.dart';

void main() {
  group('isWithinQuietHours', () {
    // 22:00-07:00 の日跨ぎ区間
    const start = 22 * 60;
    const end = 7 * 60;

    test('境界: 21:59 は静穏時間外', () {
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 21, 21, 59), start, end),
        isFalse,
      );
    });

    test('境界: 22:00 は静穏時間内', () {
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 21, 22, 0), start, end),
        isTrue,
      );
    });

    test('境界: 03:00 は静穏時間内', () {
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 22, 3, 0), start, end),
        isTrue,
      );
    });

    test('境界: 06:59 は静穏時間内', () {
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 22, 6, 59), start, end),
        isTrue,
      );
    });

    test('境界: 07:00 は静穏時間外', () {
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 22, 7, 0), start, end),
        isFalse,
      );
    });

    test('start == end は常に false（抑止なし）', () {
      final t = DateTime(2026, 10, 21, 23, 0);
      expect(QuietHoursService.isWithinQuietHours(t, 600, 600), isFalse);
      expect(QuietHoursService.isWithinQuietHours(t, 0, 0), isFalse);
    });

    test('通常区間: 13:00-15:00', () {
      const s = 13 * 60;
      const e = 15 * 60;
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 21, 12, 59), s, e),
        isFalse,
      );
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 21, 13, 0), s, e),
        isTrue,
      );
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 21, 15, 0), s, e),
        isFalse,
      );
      expect(
        QuietHoursService.isWithinQuietHours(
            DateTime(2026, 10, 21, 23, 0), s, e),
        isFalse,
      );
    });
  });

  group('deferUntil', () {
    const start = 22 * 60;
    const end = 7 * 60;

    test('静穏時間外は now をそのまま返す', () {
      final now = DateTime(2026, 10, 21, 12, 0);
      expect(QuietHoursService.deferUntil(now, start, end), now);
    });

    test('静穏時間内で終了時刻が当日中なら当日の終了時刻', () {
      final now = DateTime(2026, 10, 22, 3, 0);
      final result = QuietHoursService.deferUntil(now, start, end);
      expect(result, DateTime(2026, 10, 22, 7, 0));
    });

    test('静穏時間内で終了時刻が過ぎていれば翌日の終了時刻', () {
      final now = DateTime(2026, 10, 21, 23, 0);
      final result = QuietHoursService.deferUntil(now, start, end);
      expect(result, DateTime(2026, 10, 22, 7, 0));
    });

    test('秒以下は 0 に切り捨てる', () {
      final now = DateTime(2026, 10, 22, 3, 0, 42, 123);
      final result = QuietHoursService.deferUntil(now, start, end);
      expect(result.second, 0);
      expect(result.millisecond, 0);
      expect(result.microsecond, 0);
    });
  });

  group('resolveDelivery', () {
    final enabled = QuietHoursSettings.defaults().copyWith(enabled: true);

    test('disabled は素通し', () {
      final scheduled = DateTime(2026, 10, 21, 23, 0);
      expect(
        QuietHoursService.resolveDelivery(
            QuietHoursSettings.defaults(), scheduled),
        scheduled,
      );
    });

    test('静穏時間外は素通し', () {
      final scheduled = DateTime(2026, 10, 21, 12, 0);
      expect(
        QuietHoursService.resolveDelivery(enabled, scheduled),
        scheduled,
      );
    });

    test('defer は翌朝へ繰り延べ', () {
      final scheduled = DateTime(2026, 10, 21, 23, 0);
      expect(
        QuietHoursService.resolveDelivery(enabled, scheduled),
        DateTime(2026, 10, 22, 7, 0),
      );
    });

    test('skip は null（送出しない）', () {
      final scheduled = DateTime(2026, 10, 21, 23, 0);
      expect(
        QuietHoursService.resolveDelivery(
          enabled.copyWith(policy: QuietHoursPolicy.skip),
          scheduled,
        ),
        isNull,
      );
    });

    test('skip でも静穏時間外は素通し', () {
      final scheduled = DateTime(2026, 10, 21, 12, 0);
      expect(
        QuietHoursService.resolveDelivery(
          enabled.copyWith(policy: QuietHoursPolicy.skip),
          scheduled,
        ),
        scheduled,
      );
    });
  });

  test('formatMinutes は HH:mm でゼロ埋め', () {
    expect(QuietHoursService.formatMinutes(0), '00:00');
    expect(QuietHoursService.formatMinutes(7 * 60), '07:00');
    expect(QuietHoursService.formatMinutes(22 * 60), '22:00');
    expect(QuietHoursService.formatMinutes(23 * 60 + 59), '23:59');
  });
}
