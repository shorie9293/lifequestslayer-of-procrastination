import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_status.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_sharer.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_app_keys.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_screen.dart';

class _FakeRestorer implements AutoBackupRestorer {
  final List<String> calls = [];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    calls.add(fileName);
    return const AutoBackupRestoreResult(
      ok: true,
      message: '復元しました',
      safetyFileName: null,
    );
  }
}

class _FakeSharer implements AutoBackupSharer {
  final List<String> calls = [];

  @override
  Future<void> share(String fileName, String json) async {
    calls.add(fileName);
  }
}

/// decode を通る最小の正当な控え。
String validBackupJson() => jsonEncode({
      'version': 2,
      'exportedAt': '2026-10-28T00:00:00.000Z',
      'player': Player().toJson(),
      'tasks': <dynamic>[],
      'boxes': <String, dynamic>{},
    });

void main() {
  late InMemoryAutoBackupStore store;
  var clock = DateTime(2026, 10, 29, 7, 12);

  setUp(() async {
    clock = DateTime(2026, 10, 27, 7, 12);
    store = InMemoryAutoBackupStore(now: () => clock);
    await store.write('auto_backup_20261027.json', validBackupJson());
    clock = DateTime(2026, 10, 28, 7, 12);
    await store.write('auto_backup_20261028.json', validBackupJson());
    clock = DateTime(2026, 10, 29, 7, 12);
    await store.write('auto_backup_20261029.json', validBackupJson());
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    AutoBackupRestorer? restorer,
    AutoBackupSharer? sharer,
    Future<void> Function()? onBackupNow,
    AutoBackupStatusStore? statusStore,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        sharer: sharer,
        onBackupNow: onBackupNow,
        statusStore: statusStore,
        now: () => clock,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('新しい順に並ぶ', (tester) async {
    await pumpScreen(tester);

    final newest = tester.getTopLeft(find.text('auto_backup_20261029.json')).dy;
    final middle = tester.getTopLeft(find.text('auto_backup_20261028.json')).dy;
    final oldest = tester.getTopLeft(find.text('auto_backup_20261027.json')).dy;

    expect(newest, lessThan(middle));
    expect(middle, lessThan(oldest));
    expect(find.textContaining('第1世代'), findsOneWidget);
  });

  testWidgets('0件は空状態文言', (tester) async {
    final empty = InMemoryAutoBackupStore(now: () => clock);
    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(store: empty, now: () => clock),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('バックアップはまだありません'), findsOneWidget);
  });

  testWidgets('壊れたJSONは復元ボタンを出さない', (tester) async {
    final mixed = InMemoryAutoBackupStore(now: () => clock);
    await mixed.write('auto_backup_20261028.json', validBackupJson());
    clock = DateTime(2026, 10, 29, 7, 12);
    await mixed.write('auto_backup_20261029.json', 'not json');

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: mixed,
        restorer: _FakeRestorer(),
        sharer: _FakeSharer(),
        now: () => clock,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 0番目（最新）は壊れているので復元不可、1番目は復元可能
    expect(find.byKey(AutoBackupKeys.restoreButton(0)), findsNothing);
    expect(find.byKey(AutoBackupKeys.restoreButton(1)), findsOneWidget);
  });

  testWidgets('版番号なしの控えは復元ボタンを出さない', (tester) async {
    final mixed = InMemoryAutoBackupStore(now: () => clock);
    await mixed.write('auto_backup_20261028.json', '{"ok":true}');
    clock = DateTime(2026, 10, 29, 7, 12);
    await mixed.write('auto_backup_20261029.json', validBackupJson());

    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: mixed,
        restorer: _FakeRestorer(),
        sharer: _FakeSharer(),
        now: () => clock,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 正当な控え（最新）だけ復元ボタンを出し、版番号なしは理由を出す。
    expect(find.byKey(AutoBackupKeys.restoreButton(0)), findsOneWidget);
    expect(find.byKey(AutoBackupKeys.restoreButton(1)), findsNothing);
    expect(
      find.byKey(AutoBackupKeys.restorabilityLabel(1)),
      findsOneWidget,
    );
    expect(find.text('版番号が無い控えです'), findsOneWidget);
  });

  testWidgets('復元は確認ダイアログOKで呼ばれる', (tester) async {
    final restorer = _FakeRestorer();
    await pumpScreen(tester, restorer: restorer);

    await tester.tap(find.byKey(AutoBackupKeys.restoreButton(0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
        findsOneWidget);
    expect(restorer.calls, isEmpty);

    await tester.tap(find.byKey(AutoBackupKeys.confirmRestoreButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(restorer.calls, ['auto_backup_20261029.json']);
  });

  testWidgets('確認ダイアログをキャンセルすると呼ばれない', (tester) async {
    final restorer = _FakeRestorer();
    await pumpScreen(tester, restorer: restorer);

    await tester.tap(find.byKey(AutoBackupKeys.restoreButton(0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(AutoBackupKeys.cancelRestoreButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(restorer.calls, isEmpty);
  });

  testWidgets('restorer・sharer 未注入なら導線を出さない', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(AutoBackupKeys.restoreButton(0)), findsNothing);
    expect(find.byKey(AutoBackupKeys.shareButton(0)), findsNothing);
  });

  testWidgets('sharer 注入時は共有ボタンを出し、押すと共有する', (tester) async {
    final sharer = _FakeSharer();
    await pumpScreen(tester, sharer: sharer);

    expect(find.byKey(AutoBackupKeys.restoreButton(0)), findsNothing);
    await tester.tap(find.byKey(AutoBackupKeys.shareButton(0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(sharer.calls, ['auto_backup_20261029.json']);
  });

  testWidgets('今すぐバックアップで実行し再読込する', (tester) async {
    var calls = 0;
    await pumpScreen(tester, onBackupNow: () async {
      calls++;
      clock = DateTime(2026, 10, 30, 7, 12);
      await store.write('auto_backup_20261030.json', '{"n":4}');
    });

    await tester.tap(find.byKey(AutoBackupKeys.backupNowButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(calls, 1);
    expect(find.text('auto_backup_20261030.json'), findsOneWidget);
  });

  group('失敗の可視化', () {
    testWidgets('statusStore 未注入なら状態表示を出さない（後方互換）', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(AutoBackupKeys.lastSuccess), findsNothing);
      expect(find.byKey(AutoBackupKeys.failureBanner), findsNothing);
    });

    testWidgets('成功済みなら最終成功の1行を出す', (tester) async {
      final statusStore = InMemoryAutoBackupStatusStore(
        AutoBackupStatus.initial.recordSuccess(DateTime(2026, 10, 29, 7, 12)),
      );
      await pumpScreen(tester, statusStore: statusStore);

      expect(find.byKey(AutoBackupKeys.lastSuccess), findsOneWidget);
      expect(find.textContaining('最終成功'), findsOneWidget);
      expect(find.byKey(AutoBackupKeys.failureBanner), findsNothing);
    });

    testWidgets('失敗時は理由つきバナーと最終成功を併記する', (tester) async {
      final statusStore = InMemoryAutoBackupStatusStore(
        AutoBackupStatus.initial
            .recordSuccess(DateTime(2026, 10, 27, 7, 12))
            .recordFailure(DateTime(2026, 10, 29, 7, 12), StateError('保存先が読めない')),
      );
      await pumpScreen(tester, statusStore: statusStore);

      expect(find.byKey(AutoBackupKeys.failureBanner), findsOneWidget);
      expect(find.textContaining('自動バックアップに失敗しています'), findsOneWidget);
      expect(find.textContaining('保存先が読めない'), findsOneWidget);
      // 最終成功は失敗後も保持される
      expect(find.byKey(AutoBackupKeys.lastSuccess), findsOneWidget);
    });

    testWidgets('未試行かつバックアップ0件なら空状態文言を出す', (tester) async {
      final emptyStore = InMemoryAutoBackupStore(now: () => clock);
      final statusStore = InMemoryAutoBackupStatusStore(AutoBackupStatus.initial);
      await tester.pumpWidget(MaterialApp(
        home: AutoBackupScreen(
          store: emptyStore,
          statusStore: statusStore,
          now: () => clock,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(AutoBackupKeys.empty), findsOneWidget);
      expect(find.byKey(AutoBackupKeys.failureBanner), findsNothing);
    });

    testWidgets('未試行だが失敗扱いなら空状態文言を出さない', (tester) async {
      final emptyStore = InMemoryAutoBackupStore(now: () => clock);
      final statusStore = InMemoryAutoBackupStatusStore(
        AutoBackupStatus.initial
            .recordFailure(DateTime(2026, 10, 29, 7, 12), StateError('初回から失敗')),
      );
      await tester.pumpWidget(MaterialApp(
        home: AutoBackupScreen(
          store: emptyStore,
          statusStore: statusStore,
          now: () => clock,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(AutoBackupKeys.empty), findsNothing);
      expect(find.byKey(AutoBackupKeys.failureBanner), findsOneWidget);
    });

    testWidgets('バナーの再試行ボタンで実行し状態が更新される', (tester) async {
      final statusStore = InMemoryAutoBackupStatusStore(
        AutoBackupStatus.initial
            .recordFailure(DateTime(2026, 10, 28, 7, 12), StateError('前回失敗')),
      );
      var calls = 0;
      await pumpScreen(tester, statusStore: statusStore, onBackupNow: () async {
        calls++;
        await statusStore.write(
          AutoBackupStatus.initial.recordSuccess(DateTime(2026, 10, 29, 7, 12)),
        );
      });

      expect(find.byKey(AutoBackupKeys.failureBanner), findsOneWidget);
      await tester.tap(find.byKey(AutoBackupKeys.retryButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(calls, 1);
      expect(find.byKey(AutoBackupKeys.failureBanner), findsNothing);
      expect(find.byKey(AutoBackupKeys.lastSuccess), findsOneWidget);
    });

    testWidgets('状態の読み出しが例外でも画面は壊れない', (tester) async {
      await pumpScreen(tester, statusStore: _ThrowingStatusStore());

      expect(find.byKey(AutoBackupKeys.list), findsOneWidget);
      expect(find.byKey(AutoBackupKeys.failureBanner), findsNothing);
      expect(find.text('auto_backup_20261029.json'), findsOneWidget);
    });
  });
}

class _ThrowingStatusStore implements AutoBackupStatusStore {
  @override
  Future<AutoBackupStatus?> read() async => throw StateError('読めない');

  @override
  Future<void> write(AutoBackupStatus status) async {}
}
