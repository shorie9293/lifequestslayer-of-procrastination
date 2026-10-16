import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_gate.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_settings_screen.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// 親探針: 「設定画面 → リポジトリ → ゲート」の合成不変条件を撃つ。
/// 子の試練は各層を個別にしか撃たないため、state だけ更新して永続化を忘れる型をここで検出する。
void main() {
  testWidgets('親探針: 設定画面の有効化がリポジトリへ到達し、新規ゲートがロックする', (tester) async {
    final repo = InMemoryAppLockRepository();
    await tester.pumpWidget(
      MaterialApp(home: AppLockSettingsScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.enterText(
      find.byKey(AppKeys.appLockConfirmPasscodeField),
      '1234',
    );
    await tester.tap(find.byKey(AppKeys.appLockEnableButton));
    await tester.pumpAndSettle();
    expect(repo.isEnabled(), isTrue, reason: '設定画面が永続化へ到達していない');
    expect(repo.verifyPasscode('1234'), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          repository: repo,
          unlockedBuilder: (_) => const Text('SECRET'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SECRET'), findsNothing, reason: '有効化したのにゲートが素通りしている');

    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '9999');
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pumpAndSettle();
    expect(find.text('SECRET'), findsNothing, reason: '誤コードで解除されてしまった');

    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pumpAndSettle();
    expect(find.text('SECRET'), findsOneWidget, reason: '正コードで解除できない');
  });

  testWidgets('親探針: 未設定ならゲートは素通りする', (tester) async {
    final repo = InMemoryAppLockRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          repository: repo,
          unlockedBuilder: (_) => const Text('SECRET'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('SECRET'), findsOneWidget);
  });
}
