// 連携状況画面の試練。
//
// 空でも壊れず「未記録」を出し、記録があれば 成否・時刻・件数・ファイル名 を出し、
// 失敗時は理由まで出す（黙って消さない）。
//
// 注意: 記録口は testWidgets の fake async ゾーン内で作る（setUp で作ると
// 直列化用の Future が外側ゾーンに属し、await が永久に返らない）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';
import 'package:rpg_todo/features/settings/presentation/cross_app_link_status_screen.dart';

void main() {
  CrossAppLinkStatusRecorder makeRecorder() => CrossAppLinkStatusRecorder(
        store: InMemoryCrossAppLinkStatusStore(),
        now: () => DateTime(2026, 11, 11, 9, 12),
      );

  Future<void> pump(
    WidgetTester tester,
    CrossAppLinkStatusRecorder recorder,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(home: CrossAppLinkStatusScreen(recorder: recorder)),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('空状態では3行とも「未記録」を出す', (tester) async {
    await pump(tester, makeRecorder());

    expect(find.text('連携状況'), findsOneWidget);
    expect(find.byKey(CrossAppLinkStatusScreen.folderKey), findsOneWidget);
    expect(find.byKey(CrossAppLinkStatusScreen.sentKey), findsOneWidget);
    expect(find.byKey(CrossAppLinkStatusScreen.receivedKey), findsOneWidget);
    expect(find.text('未記録'), findsNWidgets(2));
    expect(find.text(CrossAppLinkStatusText.folder(false)), findsOneWidget);
  });

  testWidgets('記録があれば 成否・時刻・件数・ファイル名 を出す', (tester) async {
    final recorder = makeRecorder();
    await recorder.recordSent(
      count: 3,
      fileName: 'tsundoku_reward_events.jsonl',
    );
    await recorder.recordReceived(count: 2, fileName: 'kozuchi_quest.json');
    await recorder.recordFolderReady(true);

    await pump(tester, recorder);

    expect(
      find.text('成功・2026/11/11 09:12・3件・tsundoku_reward_events.jsonl'),
      findsOneWidget,
    );
    expect(
      find.text('成功・2026/11/11 09:12・2件・kozuchi_quest.json'),
      findsOneWidget,
    );
    expect(find.text(CrossAppLinkStatusText.folder(true)), findsOneWidget);
    expect(find.text('未記録'), findsNothing);
  });

  testWidgets('失敗は理由まで表示する', (tester) async {
    final recorder = makeRecorder();
    await recorder.recordSendFailure(
      StateError('disk full at shared folder'),
      fileName: 'rpg_enemy_defeat_events.jsonl',
    );

    await pump(tester, recorder);

    expect(find.textContaining('失敗'), findsOneWidget);
    expect(find.textContaining('disk full at shared folder'), findsOneWidget);
  });

  testWidgets('refresh キーを押すと最新の記録を読み直す', (tester) async {
    final recorder = makeRecorder();
    await pump(tester, recorder);
    expect(find.text('未記録'), findsNWidgets(2));

    await recorder.recordSent(count: 5, fileName: 'fresh.jsonl');
    await tester.tap(find.byKey(CrossAppLinkStatusScreen.refreshKey));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('成功・2026/11/11 09:12・5件・fresh.jsonl'),
      findsOneWidget,
    );
  });

  testWidgets('画面のKeyは重複しない', (tester) async {
    final recorder = makeRecorder();
    await recorder.recordSent(count: 1, fileName: 'a.jsonl');
    await pump(tester, recorder);

    expect(find.byKey(CrossAppLinkStatusScreen.sentKey), findsOneWidget);
    expect(find.byKey(CrossAppLinkStatusScreen.receivedKey), findsOneWidget);
    expect(find.byKey(CrossAppLinkStatusScreen.refreshKey), findsOneWidget);
  });
}
