import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/data/quiet_hours_repository.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_service.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_settings.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_scheduler.dart';
import 'package:rpg_todo/features/reminder/infrastructure/reminder_scheduler.dart';

class _RecordingGuard implements QuietHoursGuard {
  _RecordingGuard(this.result);

  final DateTime? result;
  DateTime? seen;
  int calls = 0;

  @override
  Future<DateTime?> adjust(DateTime scheduled) async {
    calls++;
    seen = scheduled;
    return result;
  }
}

class _RecordingReminderScheduler extends NotificationServiceReminderScheduler {
  _RecordingReminderScheduler({super.guard});

  ReminderSettings? scheduled;
  DateTime? at;
  int cancelCount = 0;

  @override
  Future<void> scheduleAt(ReminderSettings s, DateTime at) async {
    scheduled = s;
    this.at = at;
  }

  @override
  Future<void> cancel() async => cancelCount++;
}

class _RecordingDeadlineScheduler
    extends NotificationServiceDeadlineReminderScheduler {
  _RecordingDeadlineScheduler({super.guard});

  DeadlineReminderSettings? scheduled;
  DateTime? at;
  int cancelCount = 0;

  @override
  Future<void> scheduleAt(
    DeadlineReminderSettings s,
    DateTime at, {
    required String title,
    required String body,
  }) async {
    scheduled = s;
    this.at = at;
  }

  @override
  Future<void> cancel() async => cancelCount++;
}

void main() {
  group('QuietHoursRepositoryGuard', () {
    test('repository 設定に従って繰り延べる', () async {
      final repo = InMemoryQuietHoursRepository(
        QuietHoursSettings.defaults().copyWith(enabled: true),
      );
      final guard = QuietHoursRepositoryGuard(repo);
      final adjusted = await guard.adjust(DateTime(2026, 10, 21, 23, 30));
      expect(adjusted, DateTime(2026, 10, 22, 7, 0));
    });

    test('disabled は素通し', () async {
      final guard = QuietHoursRepositoryGuard(InMemoryQuietHoursRepository());
      final scheduled = DateTime(2026, 10, 21, 23, 30);
      expect(await guard.adjust(scheduled), scheduled);
    });

    test('policy=skip は null', () async {
      final repo = InMemoryQuietHoursRepository(
        QuietHoursSettings.defaults().copyWith(
          enabled: true,
          policy: QuietHoursPolicy.skip,
        ),
      );
      final guard = QuietHoursRepositoryGuard(repo);
      expect(await guard.adjust(DateTime(2026, 10, 21, 23, 30)), isNull);
    });
  });

  group('ReminderScheduler の後方互換と guard 接続', () {
    test('guard が null なら従来通り scheduleAt に到達する', () async {
      final scheduler = _RecordingReminderScheduler();
      await scheduler.apply(ReminderSettings(enabled: true));
      expect(scheduler.scheduled, isNotNull);
      expect(scheduler.at, isNotNull);
      expect(scheduler.cancelCount, 0);
    });

    test('guard 未指定でも既定ガード（無効設定）で scheduleAt に到達する', () async {
      final scheduler = _RecordingReminderScheduler();
      await scheduler.apply(ReminderSettings(enabled: true));
      expect(scheduler.scheduled, isNotNull);
    });

    test('guard が null を返すと schedule しない', () async {
      final guard = _RecordingGuard(null);
      final scheduler = _RecordingReminderScheduler(guard: guard);
      await scheduler.apply(ReminderSettings(enabled: true));
      expect(guard.calls, 1);
      expect(scheduler.scheduled, isNull);
    });

    test('guard が繰り延べ時刻を返すとその時刻で schedule する', () async {
      final deferred = DateTime(2026, 10, 22, 7, 0);
      final guard = _RecordingGuard(deferred);
      final scheduler = _RecordingReminderScheduler(guard: guard);
      await scheduler.apply(ReminderSettings(enabled: true));
      expect(scheduler.scheduled, isNotNull);
      expect(scheduler.at, deferred);
    });

    test('無効設定は guard に関係なく cancel する', () async {
      final guard = _RecordingGuard(null);
      final scheduler = _RecordingReminderScheduler(guard: guard);
      await scheduler.apply(ReminderSettings(enabled: false));
      expect(scheduler.cancelCount, 1);
      expect(guard.calls, 0);
    });
  });

  group('DeadlineReminderScheduler の後方互換と guard 接続', () {
    const title = 't';
    const body = 'b';

    test('guard が null なら従来通り scheduleAt に到達する', () async {
      final scheduler = _RecordingDeadlineScheduler();
      await scheduler.apply(
        DeadlineReminderSettings(enabled: true),
        title: title,
        body: body,
      );
      expect(scheduler.scheduled, isNotNull);
      expect(scheduler.at, isNotNull);
    });

    test('guard が null を返すと schedule しない', () async {
      final guard = _RecordingGuard(null);
      final scheduler = _RecordingDeadlineScheduler(guard: guard);
      await scheduler.apply(
        DeadlineReminderSettings(enabled: true),
        title: title,
        body: body,
      );
      expect(guard.calls, 1);
      expect(scheduler.scheduled, isNull);
    });

    test('guard が繰り延べ時刻を返すとその時刻で schedule する', () async {
      final deferred = DateTime(2026, 10, 22, 7, 0);
      final guard = _RecordingGuard(deferred);
      final scheduler = _RecordingDeadlineScheduler(guard: guard);
      await scheduler.apply(
        DeadlineReminderSettings(enabled: true),
        title: title,
        body: body,
      );
      expect(scheduler.at, deferred);
    });
  });
}
