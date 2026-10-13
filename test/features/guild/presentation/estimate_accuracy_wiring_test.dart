// 寄合所オーバーフローメニュー → 見積もり精度レポートの配線試練（改善提案 #131）。
//
// - ⋯メニューに EstimateAccuracyKeys.guildEntry が存在すること
// - タップで EstimateAccuracyScreen へ遷移すること
// - 既存の項目（勤行の定型・一括登録・習慣カレンダー・リマインダー）が残ること

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_keys.dart';
import 'package:rpg_todo/features/guild/presentation/estimate_accuracy_screen.dart';

import 'guild_screen_test.dart' show createViewModels, pumpGuildScreen;

void main() {
  testWidgets('⋯メニューに見積もり精度レポートの項目がある', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();

    expect(find.byKey(EstimateAccuracyKeys.guildEntry), findsOneWidget);
    expect(find.text('見積もり精度レポート'), findsOneWidget);

    // 既存項目が削られていないこと
    expect(find.byKey(AppKeys.guildOverflowTaskTemplate), findsOneWidget);
    expect(find.byKey(AppKeys.guildOverflowBulkCreate), findsOneWidget);
    expect(find.byKey(AppKeys.guildOverflowHabitCalendar), findsOneWidget);
    expect(find.byKey(AppKeys.guildOverflowReminder), findsOneWidget);
  });

  testWidgets('見積もり精度レポートをタップすると画面へ遷移する', (tester) async {
    final vms = createViewModels();
    await pumpGuildScreen(
        tester, taskVM: vms.task, playerVM: vms.player, settingsVM: vms.settings);

    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(EstimateAccuracyKeys.guildEntry));
    await tester.pumpAndSettle();

    expect(find.byType(EstimateAccuracyScreen), findsOneWidget);
    expect(find.byKey(EstimateAccuracyKeys.screen), findsOneWidget);
    expect(find.text('見積もり精度レポート'), findsOneWidget);
  });
}
