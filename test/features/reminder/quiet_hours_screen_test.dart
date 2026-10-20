import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/reminder/data/quiet_hours_repository.dart';
import 'package:rpg_todo/features/reminder/data/reminder_repository.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours.dart';
import 'package:rpg_todo/features/reminder/domain/quiet_hours_settings.dart';
import 'package:rpg_todo/features/reminder/domain/reminder_settings.dart';
import 'package:rpg_todo/features/reminder/infrastructure/reminder_scheduler.dart';
import 'package:rpg_todo/features/reminder/presentation/quiet_hours_app_keys.dart';
import 'package:rpg_todo/features/reminder/presentation/quiet_hours_settings_screen.dart';
import 'package:rpg_todo/features/reminder/presentation/reminder_settings_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

class _NoopScheduler implements ReminderScheduler {
  @override
  Future<void> apply(ReminderSettings s) async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  testWidgets('初期表示: 無効・既定プレビュー・保存ボタン', (tester) async {
    final repo = InMemoryQuietHoursRepository();
    await tester.pumpWidget(_wrap(QuietHoursSettingsScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byKey(QuietHoursAppKeys.screen), findsOneWidget);
    expect(find.byKey(QuietHoursAppKeys.toggle), findsOneWidget);
    expect(find.byKey(QuietHoursAppKeys.saveButton), findsOneWidget);
    expect(find.byKey(QuietHoursAppKeys.preview), findsOneWidget);
    expect(find.text('静穏時間は無効です'), findsOneWidget);
    // 無効時は時刻・方針UIは非表示
    expect(find.byKey(QuietHoursAppKeys.startHour), findsNothing);
    expect(find.byKey(QuietHoursAppKeys.endHour), findsNothing);
  });

  testWidgets('有効化で時刻選択と方針ラジオが現れ、既定プレビューが出る', (tester) async {
    final repo = InMemoryQuietHoursRepository();
    await tester.pumpWidget(_wrap(QuietHoursSettingsScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QuietHoursAppKeys.toggle));
    await tester.pumpAndSettle();

    expect(find.byKey(QuietHoursAppKeys.startHour), findsOneWidget);
    expect(find.byKey(QuietHoursAppKeys.startMinute), findsOneWidget);
    expect(find.byKey(QuietHoursAppKeys.endHour), findsOneWidget);
    expect(find.byKey(QuietHoursAppKeys.endMinute), findsOneWidget);
    expect(
      find.byKey(QuietHoursAppKeys.policyRadio(QuietHoursPolicy.defer)),
      findsOneWidget,
    );
    expect(
      find.byKey(QuietHoursAppKeys.policyRadio(QuietHoursPolicy.skip)),
      findsOneWidget,
    );
    expect(
      find.text('22:00〜07:00 の通知は翌朝 07:00 に繰り延べます'),
      findsOneWidget,
    );
  });

  testWidgets('開始時刻と方針を変えて保存すると repository と onSaved に届く', (tester) async {
    final repo = InMemoryQuietHoursRepository();
    QuietHoursSettings? saved;
    await tester.pumpWidget(_wrap(QuietHoursSettingsScreen(
      repository: repo,
      onSaved: (s) => saved = s,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QuietHoursAppKeys.toggle));
    await tester.pumpAndSettle();

    // 開始時 (22) → 21
    await tester.tap(find.byKey(QuietHoursAppKeys.startHour));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21時').last);
    await tester.pumpAndSettle();

    // 方針: skip
    await tester.tap(
      find.byKey(QuietHoursAppKeys.policyRadio(QuietHoursPolicy.skip)),
    );
    await tester.pumpAndSettle();

    expect(find.text('21:00〜07:00 の通知は行いません'), findsOneWidget);

    await tester.tap(find.byKey(QuietHoursAppKeys.saveButton));
    await tester.pumpAndSettle();

    final stored = await repo.load();
    expect(stored.enabled, isTrue);
    expect(stored.startHour, 21);
    expect(stored.policy, QuietHoursPolicy.skip);
    expect(stored, saved);
    expect(find.text('静穏時間を保存しました'), findsOneWidget);
  });

  testWidgets('保存後に repository から再読込され表示が維持される', (tester) async {
    final repo = InMemoryQuietHoursRepository();
    await tester.pumpWidget(_wrap(QuietHoursSettingsScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QuietHoursAppKeys.toggle));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QuietHoursAppKeys.endHour));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8時').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QuietHoursAppKeys.saveButton));
    await tester.pumpAndSettle();

    expect(repo.loadCount, greaterThanOrEqualTo(2));
    expect(find.text('22:00〜08:00 の通知は翌朝 08:00 に繰り延べます'), findsOneWidget);
  });

  testWidgets('勤行リマインダー画面: builder 未指定なら導線を出さない（後方互換）', (tester) async {
    await tester.pumpWidget(_wrap(MaterialApp(
      home: ReminderSettingsScreen(
        repository: InMemoryReminderRepository(),
        scheduler: _NoopScheduler(),
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(QuietHoursAppKeys.entry), findsNothing);
  });

  testWidgets('勤行リマインダー画面: builder 指定で静穏時間画面へ遷移する', (tester) async {
    await tester.pumpWidget(_wrap(MaterialApp(
      home: ReminderSettingsScreen(
        repository: InMemoryReminderRepository(),
        scheduler: _NoopScheduler(),
        quietHoursScreenBuilder: (_) => QuietHoursSettingsScreen(
          repository: InMemoryQuietHoursRepository(),
        ),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(QuietHoursAppKeys.entry));
    await tester.pumpAndSettle();

    expect(find.byKey(QuietHoursAppKeys.screen), findsOneWidget);
  });

  testWidgets('注入した now で静穏時間内/外の状態が出る', (tester) async {
    final repo = InMemoryQuietHoursRepository(
      QuietHoursSettings.defaults().copyWith(enabled: true),
    );
    await tester.pumpWidget(_wrap(QuietHoursSettingsScreen(
      repository: repo,
      now: DateTime(2026, 10, 21, 23, 0),
    )));
    await tester.pumpAndSettle();
    expect(find.text('ただいま静穏時間内です'), findsOneWidget);

    await tester.pumpWidget(_wrap(QuietHoursSettingsScreen(
      repository: repo,
      now: DateTime(2026, 10, 21, 12, 0),
    )));
    await tester.pumpAndSettle();
    expect(find.text('ただいま静穏時間外です'), findsOneWidget);
  });

  testWidgets('保存済み設定が画面に反映される', (tester) async {
    final repo = InMemoryQuietHoursRepository(
      QuietHoursSettings(
        enabled: true,
        startHour: 23,
        startMinute: 30,
        endHour: 6,
        endMinute: 15,
        policy: QuietHoursPolicy.skip,
      ),
    );
    await tester.pumpWidget(_wrap(QuietHoursSettingsScreen(repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('23:30〜06:15 の通知は行いません'), findsOneWidget);
    final skipTile = tester.widget<RadioListTile<QuietHoursPolicy>>(
      find.byKey(QuietHoursAppKeys.policyRadio(QuietHoursPolicy.skip)),
    );
    expect(skipTile.value, QuietHoursPolicy.skip);
    expect(skipTile.groupValue, QuietHoursPolicy.skip);
  });
}
