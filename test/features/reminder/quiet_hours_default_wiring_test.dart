import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/reminder/data/quiet_hours_repository.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_service.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_settings.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_scheduler.dart';
import 'package:rpg_todo/features/reminder/infrastructure/hive_quiet_hours_repository.dart';
import 'package:rpg_todo/features/reminder/infrastructure/quiet_hours_guard_wiring.dart';
import 'package:rpg_todo/features/reminder/infrastructure/reminder_scheduler.dart';

/// 送出だけを観測する実装（guard は基底の既定結線をそのまま使う）。
class _RecordingReminderScheduler extends NotificationServiceReminderScheduler {
  _RecordingReminderScheduler({super.guard, super.clock});

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
  _RecordingDeadlineScheduler({super.clock});

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

class _FixedGuard implements QuietHoursGuard {
  _FixedGuard(this.result);

  final DateTime? result;
  int calls = 0;

  @override
  Future<DateTime?> adjust(DateTime scheduled) async {
    calls++;
    return result;
  }
}

/// 静穏時間内に必ず入る時刻（22:00-07:00 の 23:30）。
final DateTime _quietNow = DateTime(2026, 10, 21, 23, 30);

/// 22:00-07:00 の有効な静穏時間設定。
QuietHoursSettings _quiet(QuietHoursPolicy policy) =>
    QuietHoursSettings.defaults().copyWith(
      enabled: true,
      startHour: 22,
      startMinute: 0,
      endHour: 7,
      endMinute: 0,
      policy: policy,
    );

void main() {
  group('既定結線: ガード未指定でも静穏時間が効く（リポジトリ差し替え経路）', () {
    tearDown(QuietHoursGuardWiring.reset);

    void wire(QuietHoursRepository repo) {
      QuietHoursGuardWiring.repositoryFactory = () => repo;
    }

    test('policy=skip: 静穏時間内の時刻は schedule されない', () async {
      wire(InMemoryQuietHoursRepository(_quiet(QuietHoursPolicy.skip)));
      final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

      expect(scheduler.scheduled, isNull);
      expect(scheduler.at, isNull);
      expect(scheduler.cancelCount, 0);
    });

    test('policy=defer: 翌朝 07:00 で schedule される', () async {
      wire(InMemoryQuietHoursRepository(_quiet(QuietHoursPolicy.defer)));
      final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

      expect(scheduler.scheduled, isNotNull);
      expect(scheduler.at, DateTime(2026, 10, 23, 7, 0));
    });

    test('enabled=false: 従来通り設定時刻で schedule される', () async {
      wire(InMemoryQuietHoursRepository());
      final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

      expect(scheduler.scheduled, isNotNull);
      expect(scheduler.at, DateTime(2026, 10, 22, 23, 0));
    });

    test('enabled=true でも静穏時間外なら素通し', () async {
      wire(InMemoryQuietHoursRepository(_quiet(QuietHoursPolicy.skip)));
      final noon = DateTime(2026, 10, 21, 12, 0);
      final scheduler = _RecordingReminderScheduler(clock: () => noon);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 14, minute: 0));

      expect(scheduler.at, DateTime(2026, 10, 21, 14, 0));
    });

    test('リポジトリの設定は毎回読まれる（設定変更が即反映）', () async {
      final repo = InMemoryQuietHoursRepository(_quiet(QuietHoursPolicy.skip));
      wire(repo);
      final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));
      expect(scheduler.scheduled, isNull);

      await repo.save(QuietHoursSettings.defaults());
      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));
      expect(scheduler.at, DateTime(2026, 10, 22, 23, 0));
    });

    test('締切リマインドも既定結線で defer する', () async {
      wire(InMemoryQuietHoursRepository(_quiet(QuietHoursPolicy.defer)));
      final scheduler = _RecordingDeadlineScheduler(clock: () => _quietNow);

      await scheduler.apply(
        DeadlineReminderSettings(enabled: true, hour: 23),
        title: 't',
        body: 'b',
      );

      expect(scheduler.at, DateTime(2026, 10, 23, 7, 0));
    });

    test('締切リマインドも既定結線で skip する', () async {
      wire(InMemoryQuietHoursRepository(_quiet(QuietHoursPolicy.skip)));
      final scheduler = _RecordingDeadlineScheduler(clock: () => _quietNow);

      await scheduler.apply(
        DeadlineReminderSettings(enabled: true, hour: 23),
        title: 't',
        body: 'b',
      );

      expect(scheduler.scheduled, isNull);
    });

    test('guard を明示すれば差し替えシームより優先される', () async {
      final repo = InMemoryQuietHoursRepository(_quiet(QuietHoursPolicy.skip));
      wire(repo);
      final deferred = DateTime(2026, 10, 25, 9, 0);
      final guard = _FixedGuard(deferred);
      final scheduler = _RecordingReminderScheduler(
        clock: () => _quietNow,
        guard: guard,
      );

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

      expect(guard.calls, 1);
      expect(scheduler.at, deferred);
      expect(repo.loadCount, 0);
    });
  });

  // この group は Hive.init より前に走る（宣言順）。
  test('Hive 未初期化でも既定経路は例外を投げず従来通り送出する', () async {
    expect(Hive.isBoxOpen(HiveQuietHoursRepository.boxName), isFalse);
    QuietHoursGuardWiring.reset();
    final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

    await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

    expect(scheduler.at, DateTime(2026, 10, 22, 23, 0));
  });

  test('Hive 未初期化でも既定ガードの adjust は settle する（ハングしない）', () async {
    QuietHoursGuardWiring.reset();
    final guard = QuietHoursGuardWiring.create();
    final scheduled = DateTime(2026, 10, 21, 23, 30);

    expect(
      await guard.adjust(scheduled).timeout(const Duration(seconds: 5)),
      scheduled,
    );
  });

  group('本番 Hive 経路: 保存した静穏時間設定が既定コンストラクタで効く', () {
    late Directory dir;

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('quiet_hours_default_wiring');
      Hive.init(dir.path);
    });

    tearDownAll(() async {
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    setUp(() async {
      QuietHoursGuardWiring.reset();
      // 各試練を既定（無効）から始める。
      await HiveQuietHoursRepository().save(QuietHoursSettings.defaults());
    });

    test('policy=skip: Hive に保存した 22:00-07:00 で schedule されない', () async {
      await HiveQuietHoursRepository().save(_quiet(QuietHoursPolicy.skip));
      final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

      expect(scheduler.scheduled, isNull);
    });

    test('policy=defer: Hive の設定で翌朝 07:00 に繰り延べられる', () async {
      await HiveQuietHoursRepository().save(_quiet(QuietHoursPolicy.defer));
      final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

      expect(scheduler.at, DateTime(2026, 10, 23, 7, 0));
    });

    test('enabled=false: Hive が既定なら従来通り設定時刻', () async {
      final scheduler = _RecordingReminderScheduler(clock: () => _quietNow);

      await scheduler.apply(ReminderSettings(enabled: true, hour: 23, minute: 0));

      expect(scheduler.at, DateTime(2026, 10, 22, 23, 0));
    });
  });
}
