import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_schedule_service.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';

void main() {
  const service = ReminderScheduleService();

  ReminderSettings settings({
    bool enabled = true,
    int hour = 6,
    int minute = 30,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
  }) =>
      ReminderSettings(
        enabled: enabled,
        hour: hour,
        minute: minute,
        weekdays: weekdays,
      );

  group('nextOccurrence', () {
    test('当日の通知時刻より前なら今日の時刻', () {
      // 2026-09-15 は火曜(2)
      final now = DateTime(2026, 9, 15, 5, 0);
      final next = service.nextOccurrence(settings(), now);
      expect(next, DateTime(2026, 9, 15, 6, 30));
    });

    test('通知時刻ちょうどなら今日の時刻', () {
      final now = DateTime(2026, 9, 15, 6, 30);
      expect(
        service.nextOccurrence(settings(), now),
        DateTime(2026, 9, 15, 6, 30),
      );
    });

    test('当日の通知時刻より後なら翌日の時刻', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      expect(
        service.nextOccurrence(settings(), now),
        DateTime(2026, 9, 16, 6, 30),
      );
    });

    test('曜日跨ぎ: 火曜の夜 → 毎日は水曜', () {
      final now = DateTime(2026, 9, 15, 23, 0);
      expect(
        service.nextOccurrence(settings(), now),
        DateTime(2026, 9, 16, 6, 30),
      );
    });

    test('曜日限定: 月水金のみ、火曜朝は水曜になる', () {
      final s = settings(weekdays: [1, 3, 5]);
      final now = DateTime(2026, 9, 15, 12, 0); // 火曜
      expect(
        service.nextOccurrence(s, now),
        DateTime(2026, 9, 16, 6, 30),
      );
    });

    test('週跨ぎ: 金曜の夜 → 月曜になる', () {
      final s = settings(weekdays: [1]); // 月のみ
      final now = DateTime(2026, 9, 18, 12, 0); // 金曜
      expect(
        service.nextOccurrence(s, now),
        DateTime(2026, 9, 21, 6, 30),
      );
    });

    test('disabled なら null', () {
      final now = DateTime(2026, 9, 15, 5, 0);
      expect(
        service.nextOccurrence(settings(enabled: false), now),
        isNull,
      );
    });

    test('weekdays 空なら null', () {
      final now = DateTime(2026, 9, 15, 5, 0);
      expect(
        service.nextOccurrence(settings(weekdays: []), now),
        isNull,
      );
    });
  });

  group('occursOn / isSameDay', () {
    test('occursOn は対象曜日のみ true', () {
      final s = settings(weekdays: [1, 3]);
      expect(service.occursOn(s, DateTime(2026, 9, 14)), isTrue); // 月
      expect(service.occursOn(s, DateTime(2026, 9, 15)), isFalse); // 火
    });

    test('isSameDay', () {
      expect(
        service.isSameDay(DateTime(2026, 9, 15, 6), DateTime(2026, 9, 15, 23)),
        isTrue,
      );
      expect(
        service.isSameDay(DateTime(2026, 9, 15), DateTime(2026, 9, 16)),
        isFalse,
      );
    });
  });

  group('isReminderDue', () {
    test('対象曜日で時刻到来なら true', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      expect(service.isReminderDue(settings(), now), isTrue);
    });

    test('時刻前なら false', () {
      final now = DateTime(2026, 9, 15, 5, 0);
      expect(service.isReminderDue(settings(), now), isFalse);
    });

    test('対象外曜日なら false', () {
      final now = DateTime(2026, 9, 15, 7, 0); // 火曜
      expect(
        service.isReminderDue(settings(weekdays: [1]), now),
        isFalse,
      );
    });

    test('disabled なら false', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      expect(
        service.isReminderDue(settings(enabled: false), now),
        isFalse,
      );
    });
  });

  group('shouldNotify', () {
    test('未完了なら true', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      expect(
        service.shouldNotify(
          settings: settings(),
          now: now,
        ),
        isTrue,
      );
    });

    test('本日完了済みなら false', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      expect(
        service.shouldNotify(
          settings: settings(),
          now: now,
          lastCompletedAt: DateTime(2026, 9, 15, 6, 45),
        ),
        isFalse,
      );
    });

    test('前日完了なら true', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      expect(
        service.shouldNotify(
          settings: settings(),
          now: now,
          lastCompletedAt: DateTime(2026, 9, 14, 20, 0),
        ),
        isTrue,
      );
    });
  });

  group('weekdayLabel', () {
    test('空 → なし', () {
      expect(service.weekdayLabel([]), 'なし');
    });

    test('7件 → 毎日', () {
      expect(service.weekdayLabel([1, 2, 3, 4, 5, 6, 7]), '毎日');
    });

    test('1..5 → 平日', () {
      expect(service.weekdayLabel([1, 2, 3, 4, 5]), '平日');
    });

    test('6,7 → 土日', () {
      expect(service.weekdayLabel([6, 7]), '土日');
    });

    test('その他 → 月・水・金 形式', () {
      expect(service.weekdayLabel([1, 3, 5]), '月・水・金');
      expect(service.weekdayLabel([2]), '火');
      expect(service.weekdayLabel([7, 1]), '月・日');
    });
  });

  group('timeLabel', () {
    test('ゼロ埋め', () {
      expect(service.timeLabel(6, 30), '06:30');
      expect(service.timeLabel(0, 0), '00:00');
      expect(service.timeLabel(23, 59), '23:59');
    });
  });

  group('upcomingOccurrences', () {
    test('毎日は連続日を count 件返す', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      final list = service.upcomingOccurrences(settings(), now, 3);
      expect(list, [
        DateTime(2026, 9, 16, 6, 30),
        DateTime(2026, 9, 17, 6, 30),
        DateTime(2026, 9, 18, 6, 30),
      ]);
    });

    test('曜日限定は該当曜日のみ', () {
      final now = DateTime(2026, 9, 15, 7, 0); // 火曜
      final list = service.upcomingOccurrences(
        settings(weekdays: [1, 3]),
        now,
        2,
      );
      expect(list, [
        DateTime(2026, 9, 16, 6, 30), // 水
        DateTime(2026, 9, 21, 6, 30), // 月
      ]);
    });

    test('現在時刻より後のみ返す', () {
      final now = DateTime(2026, 9, 15, 6, 0); // 通知前
      final list = service.upcomingOccurrences(settings(), now, 1);
      expect(list.first, DateTime(2026, 9, 15, 6, 30));
    });

    test('count < 1 は ArgumentError', () {
      final now = DateTime(2026, 9, 15, 7, 0);
      expect(
        () => service.upcomingOccurrences(settings(), now, 0),
        throwsArgumentError,
      );
      expect(
        () => service.upcomingOccurrences(settings(), now, -1),
        throwsArgumentError,
      );
    });
  });
}
