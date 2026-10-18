import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/task.dart';
import 'package:rpg_todo/features/reminder/data/deadline_reminder_repository.dart';
import 'package:rpg_todo/features/reminder/data/reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_service.dart';
import 'package:rpg_todo/features/reminder/domain/deadline_reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/deadline_reminder_scheduler.dart';
import 'package:rpg_todo/features/reminder/presentation/deadline_reminder_settings_screen.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';

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

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  final now = DateTime(2026, 10, 18, 9, 0);
  const service = DeadlineReminderService();
  final tasks = [
    _task('a', '薬草集め', DateTime(2026, 10, 18, 23, 0)),
    _task('b', '洞窟探索', DateTime(2026, 10, 19, 12, 0)),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    required InMemoryDeadlineReminderRepository repo,
    required _FakeScheduler scheduler,
    List<Task>? tasksOverride,
  }) async {
    await tester.pumpWidget(_wrap(DeadlineReminderSettingsScreen(
      repository: repo,
      scheduler: scheduler,
      tasksOverride: tasksOverride ?? tasks,
      now: now,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('初期表示: スイッチ・プレビュー・保存ボタンが見え、時刻/範囲UIは非表示',
      (tester) async {
    await pumpScreen(
      tester,
      repo: InMemoryDeadlineReminderRepository(),
      scheduler: _FakeScheduler(),
    );

    expect(find.byKey(AppKeys.deadlineReminderEnabledSwitch), findsOneWidget);
    expect(find.byKey(AppKeys.deadlineReminderPreview), findsOneWidget);
    expect(find.byKey(AppKeys.deadlineReminderSaveButton), findsOneWidget);
    expect(find.byKey(AppKeys.deadlineReminderTimePicker), findsNothing);
    expect(find.byKey(AppKeys.deadlineReminderWithinChip(3)), findsNothing);
    // 既定(3日以内)のプレビューはサービス出力そのもの。
    expect(
      tester.widget<Text>(find.byKey(AppKeys.deadlineReminderPreview)).data,
      service.previewLabel(
        service.selectUpcoming(tasks, now, withinDays: 3),
        now,
      ),
    );
  });

  testWidgets('有効化すると時刻・対象範囲のUIが現れる', (tester) async {
    await pumpScreen(
      tester,
      repo: InMemoryDeadlineReminderRepository(),
      scheduler: _FakeScheduler(),
    );

    await tester.tap(find.byKey(AppKeys.deadlineReminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.deadlineReminderTimePicker), findsOneWidget);
    expect(find.byKey(AppKeys.deadlineReminderWithinChip(1)), findsOneWidget);
    expect(find.byKey(AppKeys.deadlineReminderWithinChip(3)), findsOneWidget);
    expect(find.byKey(AppKeys.deadlineReminderWithinChip(7)), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
  });

  testWidgets('対象範囲を「当日のみ」にするとプレビュー件数が減る', (tester) async {
    await pumpScreen(
      tester,
      repo: InMemoryDeadlineReminderRepository(
        DeadlineReminderSettings(enabled: true, withinDays: 3),
      ),
      scheduler: _FakeScheduler(),
    );

    expect(
      tester.widget<Text>(find.byKey(AppKeys.deadlineReminderPreview)).data,
      contains('対象 2件'),
    );

    await tester.tap(find.byKey(AppKeys.deadlineReminderWithinChip(1)));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(AppKeys.deadlineReminderPreview)).data,
      contains('対象 1件'),
    );
  });

  testWidgets('保存: リポジトリへ永続化し、スケジューラへサービス組み立ての本文を渡す',
      (tester) async {
    final repo = InMemoryDeadlineReminderRepository();
    final scheduler = _FakeScheduler();
    await pumpScreen(tester, repo: repo, scheduler: scheduler);

    await tester.tap(find.byKey(AppKeys.deadlineReminderEnabledSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.deadlineReminderSaveButton));
    await tester.pumpAndSettle();

    // 永続化に到達している（state 更新だけで終わっていない）。
    final saved = await repo.load();
    expect(saved.enabled, isTrue);
    expect(saved.updatedAt, isNotNull);

    // 本文は画面の独自集計ではなく純粋サービス出力と一致する。
    final expectedBody = service.buildBody(
      service.selectUpcoming(tasks, now, withinDays: saved.withinDays),
      now,
    );
    expect(scheduler.appliedBody, expectedBody);
    expect(scheduler.appliedTitle, '⏳ 締切の刻（2件）');
    expect(scheduler.appliedSettings?.hour, saved.hour);
    expect(scheduler.appliedSettings?.withinDays, saved.withinDays);
    expect(find.textContaining('保存しました'), findsOneWidget);
  });

  testWidgets('無効で保存: スケジューラは解除され、保存値も無効', (tester) async {
    final repo = InMemoryDeadlineReminderRepository(
      DeadlineReminderSettings(enabled: true),
    );
    final scheduler = _FakeScheduler();
    await pumpScreen(tester, repo: repo, scheduler: scheduler);

    await tester.tap(find.byKey(AppKeys.deadlineReminderEnabledSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.deadlineReminderSaveButton));
    await tester.pumpAndSettle();

    expect((await repo.load()).enabled, isFalse);
    expect(scheduler.cancelCount, 1);
    expect(scheduler.applyCount, 0);
    expect(find.textContaining('停止しました'), findsOneWidget);
  });

  testWidgets('有効でも対象0件なら解除し、その旨を提示する', (tester) async {
    final repo = InMemoryDeadlineReminderRepository(
      DeadlineReminderSettings(enabled: true),
    );
    final scheduler = _FakeScheduler();
    await pumpScreen(
      tester,
      repo: repo,
      scheduler: scheduler,
      tasksOverride: const [],
    );

    await tester.tap(find.byKey(AppKeys.deadlineReminderSaveButton));
    await tester.pumpAndSettle();

    expect(scheduler.cancelCount, 1);
    expect(scheduler.applyCount, 0);
    expect(find.textContaining('解除されました'), findsOneWidget);
  });

  testWidgets('勤行リマインダー画面の導線から本画面へ遷移する', (tester) async {
    final fakeDeadlineScheduler = _FakeScheduler();
    await tester.pumpWidget(_wrap(ReminderSettingsScreen(
      repository: InMemoryReminderRepository(),
      deadlineScreenBuilder: (_) => DeadlineReminderSettingsScreen(
        repository: InMemoryDeadlineReminderRepository(),
        scheduler: fakeDeadlineScheduler,
        tasksOverride: const [],
        now: now,
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.deadlineReminderEntry), findsOneWidget);
    await tester.tap(find.byKey(AppKeys.deadlineReminderEntry));
    await tester.pumpAndSettle();

    expect(
      find.byKey(AppKeys.deadlineReminderSettingsScreen),
      findsOneWidget,
    );
    expect(
      find.byKey(AppKeys.deadlineReminderEnabledSwitch),
      findsOneWidget,
    );
  });
}
