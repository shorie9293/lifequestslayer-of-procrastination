import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_gate.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_repository.dart';
import 'package:rpg_todo/core/infrastructure/app_lock_service.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';

/// 背景復帰時の再施錠をライフサイクル実測で撃つ。
void main() {
  late InMemoryAppLockRepository repo;
  late DateTime now;

  setUp(() {
    now = DateTime(2026, 1, 1, 9, 0, 0);
    repo = InMemoryAppLockRepository();
  });

  DateTime fakeNow() => now;

  Future<void> pumpGate(
    WidgetTester tester, {
    Duration? graceOverride,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          repository: repo,
          now: fakeNow,
          graceOverride: graceOverride,
          unlockedBuilder: (context) => const Scaffold(
            key: ValueKey('unlocked-child'),
            body: Text('中身のUI'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> unlockWithCorrectCode(WidgetTester tester) async {
    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// 背景化して [away] 経過後に復帰する。
  Future<void> goBackgroundAndResume(
    WidgetTester tester, {
    Duration away = Duration.zero,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(away);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }

  testWidgets('背景復帰で再施錠される（猶予0）', (tester) async {
    await AppLockService(repo).enableWithPasscode('1234');
    await pumpGate(tester);
    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);

    await unlockWithCorrectCode(tester);
    expect(find.text('中身のUI'), findsOneWidget);

    await goBackgroundAndResume(tester, away: const Duration(minutes: 30));

    expect(find.text('中身のUI'), findsNothing, reason: '復帰時に再施錠されていない');
    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);
    // 入力欄はクリアされている
    final field = tester.widget<TextField>(
      find.byKey(AppKeys.appLockPasscodeField),
    );
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('graceOverride 5分なら猶予内の復帰は再施錠されない', (tester) async {
    await AppLockService(repo).enableWithPasscode('1234');
    await pumpGate(tester, graceOverride: const Duration(minutes: 5));
    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);

    await unlockWithCorrectCode(tester);
    expect(find.text('中身のUI'), findsOneWidget);

    await goBackgroundAndResume(tester, away: const Duration(minutes: 1));
    expect(find.text('中身のUI'), findsOneWidget, reason: '猶予内なのに再施錠された');

    // 猶予を超えて再度背景化→復帰すると再施錠される
    await goBackgroundAndResume(tester, away: const Duration(minutes: 10));
    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);
  });

  testWidgets('ロック無効時はライフサイクルで一切変わらない', (tester) async {
    await pumpGate(tester);
    expect(find.text('中身のUI'), findsOneWidget);

    await goBackgroundAndResume(tester, away: const Duration(minutes: 30));

    expect(find.text('中身のUI'), findsOneWidget);
    expect(find.byKey(AppKeys.appLockGateScreen), findsNothing);
  });

  testWidgets('ロックアウト中は解除ボタンが押せない', (tester) async {
    await AppLockService(repo).enableWithPasscode('1234');
    await repo.setFailedAttempts(5);
    await repo.setLockedUntil(now.add(const Duration(seconds: 30)));

    await pumpGate(tester);
    expect(find.byKey(AppKeys.appLockGateScreen), findsOneWidget);
    expect(find.textContaining('残り'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(AppKeys.appLockUnlockButton),
    );
    expect(button.onPressed, isNull, reason: 'ロックアウト中なのに解除ボタンが有効');

    await tester.enterText(find.byKey(AppKeys.appLockPasscodeField), '1234');
    await tester.tap(find.byKey(AppKeys.appLockUnlockButton));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('中身のUI'), findsNothing);

    // ロックアウトが明けたら解除できる（再ビルドで残り時間が 0 になる）
    now = now.add(const Duration(seconds: 31));
    await pumpGate(tester);
    expect(find.textContaining('残り'), findsNothing);
    await unlockWithCorrectCode(tester);
    expect(find.text('中身のUI'), findsOneWidget);
  });
}
