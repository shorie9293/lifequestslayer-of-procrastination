import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/features/guild/presentation/guild_screen.dart';
import 'package:rpg_todo/features/shared/viewmodels/game_view_model.dart';
import 'package:rpg_todo/features/player/viewmodels/player_view_model.dart';
import 'package:rpg_todo/features/guild/viewmodels/task_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/settings_view_model.dart';
import 'package:rpg_todo/features/shared/viewmodels/theme_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/shop_view_model.dart';
import 'package:rpg_todo/features/town/viewmodels/town_view_model.dart';
import 'package:rpg_todo/domain/models/task.dart';

import 'guild_screen_test.dart' show createViewModels;

/// 勤行テンプレート (#73) の配線合成探針:
/// 「GuildScreen AppBar 導線 → 定型画面 → 起票 → GameViewModel.addTask」
/// の合成が寄合所の一覧に反映されることを撃つ（眷属個別試練では届かない不変条件）。
void main() {
  testWidgets('寄合所 AppBar に定型導線が存在し、遷移できる', (tester) async {
    final vms = createViewModels();
    await _pump(tester, vms);
    // v1.5.23: 定型導線は⋯オーバーフローメニューに集約された
    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.taskTemplateEntry), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.taskTemplateEntry));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.taskTemplateScreen), findsOneWidget);
    expect(find.text('勤行の定型'), findsOneWidget);
  });

  testWidgets('定型画面→起票の合成が寄合所の一覧に反映される', (tester) async {
    final vms = createViewModels();
    await _pump(tester, vms);

    // v1.5.23: 定型導線は⋯オーバーフローメニューに集約された
    await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AppKeys.taskTemplateEntry));
    await tester.pumpAndSettle();

    // 定型を追加
    await tester.tap(find.byKey(AppKeys.taskTemplateCreateButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.taskTemplateNameField), '朝の定型');
    await tester.enterText(find.byKey(AppKeys.taskTemplateTitleField), '朝のあいさつ');
    await tester.tap(find.byKey(AppKeys.taskTemplateSaveButton));
    await tester.pumpAndSettle();

    // ワンタップ起票
    await tester.tap(find.byKey(AppKeys.taskTemplateCreateQuestButton));
    await tester.pumpAndSettle();

    expect(vms.task.guildTasks.any((t) => t.title == '朝のあいさつ'), isTrue,
        reason: '起票が寄合所の一覧に到達していること');
    final created =
        vms.task.guildTasks.firstWhere((t) => t.title == '朝のあいさつ');
    expect(created.status, TaskStatus.inGuild);
    expect(created.isCompleted, isFalse);
  });
}

Future<void> _pump(
  WidgetTester tester,
  ({TaskViewModel task, PlayerViewModel player, SettingsViewModel settings})
      vms,
) async {
  // GameViewModel.addTask → _save → TownViewModel.save が実 Hive を開くため
  // テスト用の一時ディレクトリへ初期化する（HiveError の防止）。
  Hive.init(Directory.systemTemp.createTempSync('rpg_task_wiring_hive').path);
  final gameVM = GameViewModel(
    playerVM: vms.player,
    taskVM: vms.task,
    shopVM: ShopViewModel(vms.player),
    settingsVM: vms.settings,
    themeVM: ThemeViewModel(vms.player),
    tv: TownViewModel(),
    autoLoad: false,
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskViewModel>.value(value: vms.task),
        ChangeNotifierProvider<PlayerViewModel>.value(value: vms.player),
        ChangeNotifierProvider<SettingsViewModel>.value(value: vms.settings),
        ChangeNotifierProvider<GameViewModel>.value(value: gameVM),
      ],
      child: const MaterialApp(home: GuildScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}
