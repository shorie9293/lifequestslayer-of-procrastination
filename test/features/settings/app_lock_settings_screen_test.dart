import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_settings_screen.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

void main() {
  late InMemoryAppLockRepository repo;

  setUp(() {
    repo = InMemoryAppLockRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AppLockSettingsScreen(repository: repo)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('有効化: 不一致だとエラー文言・有効にならない', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
        find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.enterText(
        find.byKey(AppKeys.appLockConfirmPasscodeField), '5678');
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(AppKeys.appLockErrorText), findsOneWidget);
    expect(find.text('確認用と一致しません'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);
  });

  testWidgets('有効化: 桁不足・非数字はエラー文言', (tester) async {
    await pumpScreen(tester);
    // 3桁
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '123');
    await tester.enterText(
        find.byKey(AppKeys.appLockConfirmPasscodeField), '123');
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(AppKeys.appLockErrorText), findsOneWidget);
    expect(find.text('4桁の数字を入力せよ'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);

    // 非数字（maxLengthで制御されるが念のため4桁の英字）
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '12a4');
    await tester.enterText(
        find.byKey(AppKeys.appLockConfirmPasscodeField), '12a4');
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('4桁の数字を入力せよ'), findsOneWidget);
    expect(repo.isEnabled(), isFalse);
  });

  testWidgets('有効化: 一致する4桁で有効化され、無効化できる', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.enterText(
        find.byKey(AppKeys.appLockConfirmPasscodeField), '1234');
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(repo.isEnabled(), isTrue);
    expect(repo.verifyPasscode('1234'), isTrue);
    expect(find.byKey(AppKeys.appLockDisableButton), findsOneWidget);

    await tester.tap(find.byKey(AppKeys.appLockDisableButton));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.isEnabled(), isFalse);
    expect(repo.getPasscodeHash(), isNull);
  });
}
