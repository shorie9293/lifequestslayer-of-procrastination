// アカウント削除画面（2段階確認）の試練。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rpg_todo/features/account_deletion/domain/account_deletion_service.dart';
import 'package:rpg_todo/features/account_deletion/presentation/account_deletion_app_keys.dart';
import 'package:rpg_todo/features/account_deletion/presentation/account_deletion_screen.dart';

void main() {
  late int clearCalls;
  late int signOutCalls;
  late bool clearThrows;

  AccountDeletionService buildService() => AccountDeletionService(
        clearLocalData: () async {
          clearCalls++;
          if (clearThrows) throw StateError('clear failed');
        },
        signOut: () async {
          signOutCalls++;
        },
      );

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    clearCalls = 0;
    signOutCalls = 0;
    clearThrows = false;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool hasActiveSession = true,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionScreen(
          service: buildService(),
          hasActiveSession: hasActiveSession,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(AccountDeletionAppKeys.deleteButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> confirmWith(WidgetTester tester, String text) async {
    await tester.enterText(
      find.byKey(AccountDeletionAppKeys.confirmField),
      text,
    );
    await tester.tap(find.byKey(AccountDeletionAppKeys.confirmButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('画面に削除対象の列挙と注意書きが出る', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(AccountDeletionAppKeys.screen), findsOneWidget);
    expect(find.textContaining('冒険者'), findsWidgets);
    expect(find.textContaining('取り消せません'), findsWidgets);
    expect(find.byKey(AccountDeletionAppKeys.successMessage), findsNothing);
  });

  testWidgets('確認ダイアログを開いただけでは実行しない', (tester) async {
    await pumpScreen(tester);
    await openDialog(tester);

    expect(find.byKey(AccountDeletionAppKeys.confirmField), findsOneWidget);
    expect(clearCalls, 0);
    expect(signOutCalls, 0);
  });

  testWidgets('誤入力では実行せずエラー文言を出す', (tester) async {
    await pumpScreen(tester);
    await openDialog(tester);
    await confirmWith(tester, '削除する');

    expect(clearCalls, 0);
    expect(signOutCalls, 0);
    expect(find.byKey(AccountDeletionAppKeys.errorMessage), findsOneWidget);
    expect(find.byKey(AccountDeletionAppKeys.successMessage), findsNothing);
  });

  testWidgets('正しい確認文字で1回だけ実行される', (tester) async {
    await pumpScreen(tester);
    await openDialog(tester);
    await confirmWith(tester, '削除');

    expect(clearCalls, 1);
    expect(signOutCalls, 1);

    // 成功時の遅延 pop タイマーを消化する。
    await tester.pump(const Duration(seconds: 1));
    expect(clearCalls, 1);
  });

  testWidgets('成功で成功文言が出る（エラー文言は出ない）', (tester) async {
    await pumpScreen(tester);
    await openDialog(tester);
    await confirmWith(tester, ' 削除 ');

    expect(find.byKey(AccountDeletionAppKeys.successMessage), findsOneWidget);
    expect(find.byKey(AccountDeletionAppKeys.errorMessage), findsNothing);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('失敗結果では成功文言を出さずエラー文言を出す', (tester) async {
    clearThrows = true;
    await pumpScreen(tester);
    await openDialog(tester);
    await confirmWith(tester, '削除');

    expect(find.byKey(AccountDeletionAppKeys.successMessage), findsNothing);
    expect(find.byKey(AccountDeletionAppKeys.errorMessage), findsOneWidget);
    expect(signOutCalls, 0);
  });

  testWidgets('セッションが無ければ削除ボタンは無効で実行しない', (tester) async {
    await pumpScreen(tester, hasActiveSession: false);

    final button = tester.widget<FilledButton>(
      find.byKey(AccountDeletionAppKeys.deleteButton),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(AccountDeletionAppKeys.deleteButton));
    await tester.pump();
    expect(find.byKey(AccountDeletionAppKeys.confirmField), findsNothing);
    expect(clearCalls, 0);
    expect(signOutCalls, 0);
  });

  testWidgets('「やめる」でダイアログを閉じ、実行しない', (tester) async {
    await pumpScreen(tester);
    await openDialog(tester);
    await tester.tap(find.byKey(AccountDeletionAppKeys.cancelButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(AccountDeletionAppKeys.confirmField), findsNothing);
    expect(clearCalls, 0);
    expect(signOutCalls, 0);
  });
}
