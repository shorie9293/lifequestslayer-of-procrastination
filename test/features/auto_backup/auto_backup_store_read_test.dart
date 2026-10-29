import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';

void main() {
  group('FileAutoBackupStore.read', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('auto_backup_read_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('write → read で往復する', () async {
      final store = FileAutoBackupStore(directoryResolver: () async => tmp);
      await store.write('auto_backup_20261029.json', '{"a":1}');
      expect(await store.read('auto_backup_20261029.json'), '{"a":1}');
    });

    test('存在しないファイルは null', () async {
      final store = FileAutoBackupStore(directoryResolver: () async => tmp);
      expect(await store.read('auto_backup_20260101.json'), isNull);
    });

    test('InMemoryAutoBackupStore も read できる', () async {
      final store = InMemoryAutoBackupStore(now: () => DateTime(2026, 10, 29));
      await store.write('auto_backup_20261029.json', '{"b":2}');
      expect(await store.read('auto_backup_20261029.json'), '{"b":2}');
      expect(await store.read('missing.json'), isNull);
    });
  });
}
