// 寄合所 ⋯ →「クエスト管理」ハブへ入る共通操作（試練用）。
//
// 2026-11-28: 溢れメニューの13項目は管理ハブ1枚へ集約された。
// 各項目のキーは移設前と同一なので、メニューを開いていた箇所をこの関数へ
// 差し替えれば、以降の find/tap はそのまま通用する。

import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/core/testing/widget_keys.dart';

Future<void> openQuestManagement(WidgetTester tester) async {
  await tester.tap(find.byKey(AppKeys.guildOverflowMenu));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AppKeys.guildQuestManagementEntry));
  await tester.pumpAndSettle();
  expect(find.byKey(AppKeys.questManagementScreen), findsOneWidget,
      reason: 'クエスト管理ハブが開くこと');
}
