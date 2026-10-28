import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_bootstrap.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';

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
}
