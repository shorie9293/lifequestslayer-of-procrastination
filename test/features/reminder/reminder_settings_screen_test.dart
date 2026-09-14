import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/reminder/data/reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/reminder_scheduler.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';

class _FakeScheduler implements ReminderScheduler {
  ReminderSettings? applied;
  var cancelCount = 0;

  @override
  Future<void> apply(ReminderSettings s) async => applied = s;

  @override
  Future<void> cancel() async => cancelCount++;
}

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('初期表示: 既定設定のスイッチ・時刻・曜日チップが見える', (tester) async {
    final repo = InMemoryReminderRepository();
    await tester.pumpWidget(_wrap(
      ReminderSettingsScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderEnabledSwitch), findsOneWidget);
    expect(find.text('勤行リマインダー'), findsWidgets);
    expect(find.byKey(AppKeys.reminderSaveButton), findsOneWidget);
    // 既定は無効なので時刻・曜日UIは非表示
    expect(find.byKey(AppKeys.reminderTimePicker), findsNothing);
    expect(find.byKey(AppKeys.reminderWeekdayChip(1)), findsNothing);
  });

  testWidgets('有効化すると時刻・曜日UIが現れる', (tester) async {
    final repo = InMemoryReminderRepository();
    await tester.pumpWidget(_wrap(
      ReminderSettingsScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.reminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderTimePicker), findsOneWidget);
    expect(find.byKey(AppKeys.reminderWeekdayChip(1)), findsOneWidget);
    expect(find.byKey(AppKeys.reminderWeekdayChip(7)), findsOneWidget);
    // デフォルト weekdays は毎日 → 全チップ選択状態
    final chip1 =
        tester.widget<FilterChip>(find.byKey(AppKeys.reminderWeekdayChip(1)));
    expect(chip1.selected, isTrue);
    // プレビューに次回通知が出る
    expect(find.textContaining('次の通知: 毎日 06:30'), findsOneWidget);
  });

  testWidgets('無効化すると時刻・曜日UIが消え、プレビューは「通知は設定されていません」',
      (tester) async {
    final repo = InMemoryReminderRepository(
      ReminderSettings(enabled: true),
    );
    await tester.pumpWidget(_wrap(
      ReminderSettingsScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderTimePicker), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.reminderEnabledSwitch));
    await tester.pumpAndSettle();

    expect(find.byKey(AppKeys.reminderTimePicker), findsNothing);
    expect(find.text('通知は設定されていません'), findsOneWidget);
  });

  testWidgets('曜日チップのタップで選択が切り替わる', (tester) async {
    final repo = InMemoryReminderRepository(
      ReminderSettings(enabled: true, weekdays: [1, 2]),
    );
    await tester.pumpWidget(_wrap(
      ReminderSettingsScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.reminderWeekdayChip(2))); // 選択解除
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.reminderWeekdayChip(3))); // 選択
    await tester.pumpAndSettle();

    final chip2 =
        tester.widget<FilterChip>(find.byKey(AppKeys.reminderWeekdayChip(2)));
    final chip3 =
        tester.widget<FilterChip>(find.byKey(AppKeys.reminderWeekdayChip(3)));
    expect(chip2.selected, isFalse);
    expect(chip3.selected, isTrue);
  });

  testWidgets('保存で repository と scheduler が呼ばれ SnackBar が出る', (tester) async {
    final repo = InMemoryReminderRepository();
    final scheduler = _FakeScheduler();
    await tester.pumpWidget(_wrap(
      ReminderSettingsScreen(repository: repo, scheduler: scheduler),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.reminderEnabledSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.reminderWeekdayChip(7))); // 日曜を外す
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(AppKeys.reminderSaveButton));
    await tester.pumpAndSettle();

    final saved = await repo.load();
    expect(saved.enabled, isTrue);
    expect(saved.weekdays, [1, 2, 3, 4, 5, 6]);
    expect(scheduler.applied, saved);
    expect(find.text('勤行リマインダーを保存しました'), findsOneWidget);
  });

  testWidgets('読み込んだ設定が画面に反映される', (tester) async {
    final repo = InMemoryReminderRepository(
      ReminderSettings(enabled: true, hour: 9, minute: 5, weekdays: [6, 7]),
    );
    await tester.pumpWidget(_wrap(
      ReminderSettingsScreen(repository: repo),
    ));
    await tester.pumpAndSettle();

    expect(find.text('09:05'), findsOneWidget);
    final chip6 =
        tester.widget<FilterChip>(find.byKey(AppKeys.reminderWeekdayChip(6)));
    expect(chip6.selected, isTrue);
    final chip1 =
        tester.widget<FilterChip>(find.byKey(AppKeys.reminderWeekdayChip(1)));
    expect(chip1.selected, isFalse);
    // 土日ラベルのプレビュー
    expect(find.textContaining('土日 09:05'), findsOneWidget);
  });
}
