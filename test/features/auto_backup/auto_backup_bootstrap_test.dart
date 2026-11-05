import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_bootstrap.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_status_store.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_status.dart';

void main() {
  test('buildJson が例外でも外へ投げない', () async {
    final store = InMemoryAutoBackupStore();
    expect(
      () => scheduleAutoBackup(
        buildJson: () async => throw StateError('壊れた'),
        store: store,
      ),
      returnsNormally,
    );
    await pumpEventQueue();
    expect(await store.list(), isEmpty);
  });

  test('UI をブロックしない（即座に戻る）', () async {
    final store = InMemoryAutoBackupStore();
    final gate = Completer<String>();
    final stopwatch = Stopwatch()..start();
    scheduleAutoBackup(buildJson: () => gate.future, store: store);
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(100));
    expect(await store.list(), isEmpty); // まだ書き込み前
    gate.complete('{"version":2}');
    await pumpEventQueue();
    expect((await store.list()).length, 1);
  });

  test('正常時は自動バックアップを1件書き込む', () async {
    final store = InMemoryAutoBackupStore();
    scheduleAutoBackup(buildJson: () async => '{"version":2}', store: store);
    await pumpEventQueue();
    final entries = await store.list();
    expect(entries.length, 1);
    expect(entries.first.fileName, startsWith('auto_backup_'));
    expect(entries.first.fileName, endsWith('.json'));
  });

  test('成功を状態ストアへ記録する', () async {
    final store = InMemoryAutoBackupStore();
    final statusStore = InMemoryAutoBackupStatusStore();
    scheduleAutoBackup(
      buildJson: () async => '{"version":2}',
      store: store,
      statusStore: statusStore,
    );
    await pumpEventQueue();

    final status = await statusStore.read();
    expect(status, isNotNull);
    expect(status!.hasFailed, isFalse);
    expect(status.lastSuccessAt, isNotNull);
  });

  test('失敗を状態ストアへ理由つきで記録する', () async {
    final store = InMemoryAutoBackupStore();
    final statusStore = InMemoryAutoBackupStatusStore();
    scheduleAutoBackup(
      buildJson: () async => throw StateError('壊れた'),
      store: store,
      statusStore: statusStore,
    );
    await pumpEventQueue();

    final status = await statusStore.read();
    expect(status, isNotNull);
    expect(status!.hasFailed, isTrue);
    expect(status.consecutiveFailures, 1);
    expect(status.lastError, contains('壊れた'));
    expect(await store.list(), isEmpty);
  });

  test('状態ストアが壊れていても自動バックアップ本体は走る', () async {
    final store = InMemoryAutoBackupStore();
    scheduleAutoBackup(
      buildJson: () async => '{"version":2}',
      store: store,
      statusStore: _ThrowingStatusStore(),
    );
    await pumpEventQueue();

    expect((await store.list()).length, 1);
  });
}

/// 読み書きが必ず失敗する状態ストア。
class _ThrowingStatusStore implements AutoBackupStatusStore {
  @override
  Future<AutoBackupStatus?> read() async => throw StateError('読めない');

  @override
  Future<void> write(AutoBackupStatus status) async =>
      throw StateError('書けない');
}
