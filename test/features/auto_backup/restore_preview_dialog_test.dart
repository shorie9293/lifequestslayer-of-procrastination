import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/testing/widget_keys.dart';
import 'package:rpg_todo/domain/models/player.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_restorer.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_app_keys.dart';
import 'package:rpg_todo/features/auto_backup/presentation/auto_backup_screen.dart';
import 'package:rpg_todo/features/temple/data/backup_storage.dart';

class _FakeRestorer implements AutoBackupRestorer {
  final List<String> calls = [];

  @override
  Future<AutoBackupRestoreResult> restore(String fileName) async {
    calls.add(fileName);
    return const AutoBackupRestoreResult(ok: true, message: '復元しました');
  }
}

class _ThrowingStorage implements BackupStorage {
  @override
  Future<Map<String, Map<String, dynamic>>> capture() async {
    throw StateError('読めない');
  }

  @override
  Future<void> restore(Map<String, Map<String, dynamic>> boxes) async {}
}

String previewBackupJson({int overwriteCount = 1}) => jsonEncode({
      'version': 2,
      'exportedAt': '2026-11-11T00:00:00.000Z',
      'player': Player().toJson(),
      'tasks': <dynamic>[],
      'boxes': <String, dynamic>{
        'battle_records': {
          'a': 1,
          'b': 2,
          'c': 3,
          for (var i = 0; i < overwriteCount; i++) 'k$i': i,
        },
        'settingsBox': {'fontSizeScale': 1.0},
        // 許可リスト外（復元されない）
        'unknown_box': {'z': 9},
      },
    });

Map<String, Map<String, dynamic>> currentBoxes({int overwriteCount = 1}) => {
      'battle_records': {
        'a': 1,
        'b': 9,
        'x': 0,
        for (var i = 0; i < overwriteCount; i++) 'k$i': -1,
      },
      'settingsBox': {'fontSizeScale': 1.0},
    };

void main() {
  late InMemoryAutoBackupStore store;
  final clock = DateTime(2026, 11, 11, 7, 12);

  setUp(() async {
    store = InMemoryAutoBackupStore(now: () => clock);
    await store.write('auto_backup_20261111.json', previewBackupJson());
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    AutoBackupRestorer? restorer,
    BackupStorage? storage,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: AutoBackupScreen(
        store: store,
        restorer: restorer,
        backupStorage: storage,
        now: () => clock,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(AutoBackupKeys.restoreButton(0)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('復元確認に件数の内訳と上書きキー抜粋が出る', (tester) async {
    final restorer = _FakeRestorer();
    await pumpScreen(
      tester,
      restorer: restorer,
      storage: InMemoryBackupStorage(currentBoxes()),
    );

    await openDialog(tester);

    expect(find.text('復元の確認'), findsOneWidget);
    expect(
      find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
      findsOneWidget,
    );
    expect(find.byKey(AppKeys.restorePreviewSummary), findsOneWidget);
    expect(find.text('新規 1件 / 上書き 2件 / 変更なし 2件 / 削除 1件'), findsOneWidget);
    expect(find.byKey(AppKeys.restorePreviewSamples), findsOneWidget);
    expect(find.textContaining('上書きされるキー:'), findsOneWidget);
    expect(find.textContaining('battle_records/b'), findsOneWidget);

    await tester.tap(find.byKey(AutoBackupKeys.confirmRestoreButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(restorer.calls, ['auto_backup_20261111.json']);
  });

  testWidgets('キャンセルすると復元しない（既存導線の不変）', (tester) async {
    final restorer = _FakeRestorer();
    await pumpScreen(
      tester,
      restorer: restorer,
      storage: InMemoryBackupStorage(currentBoxes()),
    );

    await openDialog(tester);
    await tester.tap(find.byKey(AutoBackupKeys.cancelRestoreButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(restorer.calls, isEmpty);
  });

  testWidgets('狭幅(360x640)でも内訳が overflow しない', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpScreen(
      tester,
      restorer: _FakeRestorer(),
      storage: InMemoryBackupStorage(currentBoxes(overwriteCount: 12)),
    );

    await openDialog(tester);

    expect(find.byKey(AppKeys.restorePreviewSummary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('プレビュー取得失敗時は従来表示のまま復元できる', (tester) async {
    final restorer = _FakeRestorer();
    await pumpScreen(tester, restorer: restorer, storage: _ThrowingStorage());

    await openDialog(tester);

    expect(find.byKey(AppKeys.restorePreviewSummary), findsNothing);
    expect(
      find.text('このバックアップから復元しますか？現在のデータは先に自動バックアップされます'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(AutoBackupKeys.confirmRestoreButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(restorer.calls, ['auto_backup_20261111.json']);
  });

  testWidgets('backupStorage 未注入なら従来表示のみ（後方互換）', (tester) async {
    await pumpScreen(tester, restorer: _FakeRestorer());

    await openDialog(tester);

    expect(find.byKey(AppKeys.restorePreviewSummary), findsNothing);
    expect(find.text('キャンセル'), findsOneWidget);
    expect(find.text('復元する'), findsOneWidget);
  });
}
