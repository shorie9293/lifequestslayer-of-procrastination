// 寄合所⋯オーバーフローメニューからカレンダー書き出し画面への配線試練。

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_keys.dart';
import 'package:rpg_todo/features/calendar_export/presentation/calendar_export_screen.dart';

import 'presentation/guild_screen_test.dart'
    show createViewModels, pumpGuildScreen;

void main() {
  testWidgets('⋯メニューに「カレンダー書き出し」があり、遷移できる', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
      tester,
      taskVM: vms.task,
      playerVM: vms.player,
      settingsVM: vms.settings,
    );

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.guildCalendarExportEntry), findsOneWidget);
    expect(find.text('カレンダー書き出し'), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.guildCalendarExportEntry));
    await tester.pumpAndSettle();

    expect(find.byKey(CalendarExportAppKeys.screen), findsOneWidget);
    expect(find.byType(CalendarExportScreen), findsOneWidget);
  });
}
