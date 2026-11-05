import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_gate.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_service.dart';
import 'package:rpg_todo/core/infrastructure/lock_recovery_service.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

void main() {
  late InMemoryAppLockRepository repo;
  late AppLockService appLock;
  var erased = 0;

  setUp(() async {
    repo = InMemoryAppLockRepository();
    appLock = AppLockService(repo);
    erased = 0;
    await appLock.enableWithPasscode('1234');
  });

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          repository: repo,
          recoveryService: LockRecoveryService(
            appLock,
            backupExporter: () async => 'backup.json',
            dataEraser: () async => erased++,
          ),
          unlockedBuilder: (context) => const Scaffold(
            body: Text('中身のUI'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('ロック中は回復導線が見える', (tester) async {
    await pumpGate(tester);

    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);
    expect(find.byKey(AppKeys.appLockForgotButton), findsOneWidget);
    expect(find.text('パスコードをお忘れですか？'), findsOneWidget);
    expect(find.text('現世はロックされています'), findsOneWidget);
    expect(find.text('解除'), findsOneWidget);
  });

  testWidgets('誤った確認語では解除されない', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    expect(find.byKey(AppKeys.appLockRecoveryConfirmField), findsOneWidget);

    await tester.enterText(
      find.byKey(AppKeys.appLockRecoveryConfirmField),
      'ちがう',
    );
    await tester.tap(find.byKey(AppKeys.appLockRecoveryConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('中身のUI'), findsNothing);
    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);
    expect(repo.isEnabled(), isTrue);
    expect(repo.getPasscodeHash(), isNotNull);
    expect(erased, 0);
  });

  testWidgets('正しい確認語で解除され子UIが出る', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppKeys.appLockRecoveryConfirmField),
      '初期化',
    );
    await tester.tap(find.byKey(AppKeys.appLockRecoveryConfirmButton));
    await tester.pumpAndSettle();

    expect(find.text('中身のUI'), findsOneWidget);
    expect(find.byKey(AppKeys.appLockGateScreen), findsNothing);
    expect(repo.isEnabled(), isFalse);
    expect(repo.getPasscodeHash(), isNull);
    expect(erased, 1);
  });

  testWidgets('回復結果をSnackBarで正直に表示する', (tester) async {
    await pumpGate(tester);

    await tester.tap(find.byKey(AppKeys.appLockForgotButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(AppKeys.appLockRecoveryConfirmField),
      '初期化',
    );
    await tester.tap(find.byKey(AppKeys.appLockRecoveryConfirmButton));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('バックアップを保存しました'), findsOneWidget);
    expect(find.textContaining('データを初期化しました'), findsOneWidget);
  });
}
