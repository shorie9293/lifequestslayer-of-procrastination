import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_todo/features/google_todo/data/google_todo_gateway.dart';
import 'package:rpg_todo/features/google_todo/domain/google_todo_status.dart';
import 'package:rpg_todo/features/google_todo/presentation/google_todo_keys.dart';
import 'package:rpg_todo/features/google_todo/presentation/google_todo_link_screen.dart';

/// 通信を持たないフェイク。呼ばれた回数も記録する。
class _FakeGateway implements GoogleTodoGateway {
  _FakeGateway({this.status = GoogleTodoStatus.notLinked, this.failStatus});

  GoogleTodoStatus status;
  String? failStatus;

  int statusCalls = 0;
  int startCalls = 0;
  int syncCalls = 0;
  int unlinkCalls = 0;

  @override
  Future<GoogleTodoStatus> fetchStatus() async {
    statusCalls++;
    if (failStatus != null) {
      throw GoogleTodoException(failStatus!, statusCode: 500);
    }
    return status;
  }

  @override
  Future<String> startLink() async {
    startCalls++;
    return 'https://accounts.google.com/o/oauth2/v2/auth?state=test';
  }

  @override
  Future<List<GoogleTodoList>> fetchLists() async => const <GoogleTodoList>[
        GoogleTodoList(id: '@default', title: 'マイタスク'),
        GoogleTodoList(id: 'list-2', title: '仕事'),
      ];

  @override
  Future<void> selectList({required String id, String? title}) async {
    status = GoogleTodoStatus(
      linked: true,
      email: status.email,
      listId: id,
      listTitle: title,
    );
  }

  @override
  Future<void> unlink() async {
    unlinkCalls++;
    status = GoogleTodoStatus.notLinked;
  }

  @override
  Future<GoogleTodoSyncResult> sync() async {
    syncCalls++;
    return const GoogleTodoSyncResult(pulled: 1, pushed: 2);
  }
}

GoogleTodoStatus _linkedStatus() => GoogleTodoStatus(
      linked: true,
      email: 'horie.shunta@gmail.com',
      listId: '@default',
      listTitle: 'マイタスク',
      lastOkAt: DateTime.utc(2026, 11, 20, 1, 0),
      pulled: 2,
      pushed: 1,
    );

void main() {
  testWidgets('未連携なら説明と連携ボタンを出す', (tester) async {
    final gateway = _FakeGateway();
    await tester.pumpWidget(MaterialApp(
      home: GoogleTodoLinkScreen(
        gateway: gateway,
        clock: () => DateTime.utc(2026, 11, 20, 1, 5),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(GoogleTodoKeys.notLinkedExplain), findsOneWidget);
    expect(find.byKey(GoogleTodoKeys.linkButton), findsOneWidget);
    expect(find.byKey(GoogleTodoKeys.syncButton), findsNothing);
    expect(gateway.statusCalls, 1);
  });

  testWidgets('連携ボタンで同意URLをブラウザに渡す', (tester) async {
    final gateway = _FakeGateway();
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
      home: GoogleTodoLinkScreen(
        gateway: gateway,
        launchUrl: (uri) async {
          opened = uri;
          return true;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(GoogleTodoKeys.linkButton));
    await tester.pumpAndSettle();

    expect(gateway.startCalls, 1);
    expect(opened, isNotNull);
    expect(opened!.host, 'accounts.google.com');
  });

  testWidgets('連携済みならアカウント・リスト・同期状態を出す', (tester) async {
    final gateway = _FakeGateway(status: _linkedStatus());
    await tester.pumpWidget(MaterialApp(
      home: GoogleTodoLinkScreen(
        gateway: gateway,
        clock: () => DateTime.utc(2026, 11, 20, 1, 3),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(GoogleTodoKeys.accountLabel), findsOneWidget);
    expect(find.text('horie.shunta@gmail.com'), findsOneWidget);
    expect(find.text('マイタスク'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(GoogleTodoKeys.syncStateLabel)).data,
      '3分前に同期・取得2/送信1',
    );
  });

  testWidgets('今すぐ同期で同期が走り、完了を通知する', (tester) async {
    final gateway = _FakeGateway(status: _linkedStatus());
    await tester.pumpWidget(MaterialApp(
      home: GoogleTodoLinkScreen(
        gateway: gateway,
        clock: () => DateTime.utc(2026, 11, 20, 1, 3),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(GoogleTodoKeys.syncButton));
    await tester.pumpAndSettle();

    expect(gateway.syncCalls, 1);
    expect(find.textContaining('同期しました'), findsOneWidget);
    expect(gateway.statusCalls, 2);
  });

  testWidgets('取得失敗なら再試行できる', (tester) async {
    final gateway = _FakeGateway(failStatus: '取得できません');
    await tester.pumpWidget(MaterialApp(
      home: GoogleTodoLinkScreen(gateway: gateway),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(GoogleTodoKeys.errorState), findsOneWidget);

    gateway.failStatus = null;
    await tester.tap(find.byKey(GoogleTodoKeys.retryInlineButton));
    await tester.pumpAndSettle();

    expect(find.byKey(GoogleTodoKeys.notLinkedExplain), findsOneWidget);
  });

  testWidgets('解除は確認ダイアログを経て実行される', (tester) async {
    final gateway = _FakeGateway(status: _linkedStatus());
    await tester.pumpWidget(MaterialApp(
      home: GoogleTodoLinkScreen(gateway: gateway),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(GoogleTodoKeys.unlinkButton));
    await tester.pumpAndSettle();
    expect(find.byKey(GoogleTodoKeys.unlinkConfirm), findsOneWidget);

    await tester.tap(find.text('解除する'));
    await tester.pumpAndSettle();

    expect(gateway.unlinkCalls, 1);
    expect(find.byKey(GoogleTodoKeys.notLinkedExplain), findsOneWidget);
  });
}
