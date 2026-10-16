import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_gate.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_service.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

void main() {
  late InMemoryAppLockRepository repo;

  setUp(() {
    repo = InMemoryAppLockRepository();
  });

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          repository: repo,
          unlockedBuilder: (context) => const Scaffold(
            key: ValueKey('unlocked-child'),
            body: Text('中身のUI'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('無効時は子が表示される（素通り）', (tester) async {
    await pumpGate(tester);
    expect(find.text('中身のUI'), findsOneWidget);
    expect(find.byKey(AppKeys.appLockGateScreen), findsNothing);
  });

  testWidgets('有効時は子が隠れ、誤コードでエラー・正コードで解除', (tester) async {
    await AppLockService(repo).enableWithPasscode('1234');
    await pumpGate(tester);

    // 子は隠れ、ロック画面が出る
    expect(find.text('中身のUI'), findsNothing);
    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);

    // 誤コード → エラー文言
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '9999');
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('パスコードが正しくありません'), findsOneWidget);
    expect(find.text('中身のUI'), findsNothing);

    // 正コード → 解除
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('中身のUI'), findsOneWidget);
  });

  testWidgets('repository未注入かつHive未初期化でもfail-openで素通り', (tester) async {
    // Hive未初期化でもゲート生成が失敗しない（isEnabled は box未openなら false）
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          unlockedBuilder: (context) => const Text('中身のUI'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('中身のUI'), findsOneWidget);
  });
}
