import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/reminder/data/deadline_reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_service.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_coordinator.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_scheduler.dart';

class _FakeScheduler implements DeadlineReminderScheduler {
  DeadlineReminderSettings? appliedSettings;
  String? appliedTitle;
  String? appliedBody;
  int applyCount = 0;
  int cancelCount = 0;

  @override
  Future<void> apply(
    DeadlineReminderSettings s, {
    required String title,
    required String body,
  }) async {
    appliedSettings = s;
    appliedTitle = title;
    appliedBody = body;
    applyCount++;
  }

  @override
  Future<void> cancel() async => cancelCount++;
}

Task _task(String id, String title, DateTime? deadline) =>
    Task(id: id, title: title, deadline: deadline);

void main() {
  final now = DateTime(2026, 10, 18, 9, 0);
  const service = DeadlineReminderService();

  test('設定が無効なら解除して canceledDisabled を返す', () async {
    final scheduler = _FakeScheduler();
    final coordinator = DeadlineReminderCoordinator(
      repository: InMemoryDeadlineReminderRepository(),
      scheduler: scheduler,
      taskLoader: () async => [
        _task('a', '薬草集め', DateTime(2026, 10, 18, 23, 0)),
      ],
      clock: () => now,
    );

    expect(await coordinator.run(), DeadlineReminderOutcome.canceledDisabled);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.applyCount, 0);
  });

  test('有効でも対象0件なら解除して canceledEmpty を返す', () async {
    final scheduler = _FakeScheduler();
    final coordinator = DeadlineReminderCoordinator(
      repository: InMemoryDeadlineReminderRepository(
        DeadlineReminderSettings(enabled: true, withinDays: 3),
      ),
      scheduler: scheduler,
      taskLoader: () async => [
        _task('far', '遠い締切', DateTime(2026, 12, 1, 23, 0)),
      ],
      clock: () => now,
    );

    expect(await coordinator.run(), DeadlineReminderOutcome.canceledEmpty);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.applyCount, 0);
  });

  test('有効かつ対象ありなら本文を組んでスケジュールする（純粋サービスと一致）',
      () async {
    final scheduler = _FakeScheduler();
    final tasks = [
      _task('a', '薬草集め', DateTime(2026, 10, 18, 23, 0)),
      _task('b', '洞窟探索', DateTime(2026, 10, 19, 12, 0)),
    ];
    final settings = DeadlineReminderSettings(
      enabled: true,
      hour: 7,
      minute: 30,
      withinDays: 3,
    );
    final coordinator = DeadlineReminderCoordinator(
      repository: InMemoryDeadlineReminderRepository(settings),
      scheduler: scheduler,
      taskLoader: () async => tasks,
      clock: () => now,
    );

    expect(await coordinator.run(), DeadlineReminderOutcome.scheduled);
    final expected = service.buildBody(
      service.selectUpcoming(tasks, now, withinDays: settings.withinDays),
      now,
    );
    expect(scheduler.appliedBody, expected);
    expect(scheduler.appliedTitle, '⏳ 締切の刻（2件）');
    expect(scheduler.appliedSettings, settings);
    expect(scheduler.cancelCount, 0);
  });

  test('対象が設定の withinDays に従う（1日なら翌日は含まれない）', () async {
    final scheduler = _FakeScheduler();
    final tasks = [
      _task('a', '本日', DateTime(2026, 10, 18, 23, 0)),
      _task('b', '明日', DateTime(2026, 10, 19, 12, 0)),
    ];
    final coordinator = DeadlineReminderCoordinator(
      repository: InMemoryDeadlineReminderRepository(
        DeadlineReminderSettings(enabled: true, withinDays: 1),
      ),
      scheduler: scheduler,
      taskLoader: () async => tasks,
      clock: () => now,
    );

    expect(await coordinator.run(), DeadlineReminderOutcome.scheduled);
    expect(scheduler.appliedBody, '本日締切: 本日');
    expect(scheduler.appliedBody, isNot(contains('明日')));
  });
}
