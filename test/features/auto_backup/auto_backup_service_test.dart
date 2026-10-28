import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_service.dart';

void main() {
  late DateTime clock;
  late InMemoryAutoBackupStore store;

  setUp(() {
    clock = DateTime(2026, 10, 29, 9, 0);
    store = InMemoryAutoBackupStore(now: () => clock);
  });

  AutoBackupService buildService() => AutoBackupService(
        store: store,
        now: () => clock,
      );

  Future<String> buildJsonOk() async => '{"version":2}';

  test('初回は実行して書き込む', () async {
    final result = await buildService().run(buildJsonOk);
    expect(result.ran, isTrue);
    expect(result.fileName, 'auto_backup_20261029.json');
    expect(result.error, isNull);
    final entries = await store.list();
    expect(entries.length, 1);
    expect(entries.first.fileName, 'auto_backup_20261029.json');
    expect(await store.read('auto_backup_20261029.json'), '{"version":2}');
  });

  test('24時間未満はスキップして書き込まない', () async {
    await buildService().run(buildJsonOk);
    clock = clock.add(const Duration(hours: 23, minutes: 59));
    final result = await buildService().run(buildJsonOk);
    expect(result.ran, isFalse);
    expect(result.fileName, isNull);
    expect((await store.list()).length, 1);
  });

  test('ちょうど24時間で再び書き込む', () async {
    await buildService().run(buildJsonOk);
    clock = clock.add(const Duration(hours: 24));
    final result = await buildService().run(buildJsonOk);
    expect(result.ran, isTrue);
    expect(result.fileName, 'auto_backup_20261030.json');
    expect((await store.list()).length, 2);
  });

  test('4件目で最古が消え、世代は3件で回転する', () async {
    for (var i = 0; i < 4; i++) {
      final result = await buildService().run(buildJsonOk);
      expect(result.ran, isTrue);
      if (i == 3) {
        expect(result.pruned, ['auto_backup_20261029.json']);
      }
      clock = clock.add(const Duration(days: 1));
    }
    final names = (await store.list()).map((e) => e.fileName).toList()..sort();
    expect(names, [
      'auto_backup_20261030.json',
      'auto_backup_20261031.json',
      'auto_backup_20261101.json',
    ]);
  });

  test('buildJson の例外を握って ran:false + error を返す', () async {
    final result = await buildService().run(() async => throw StateError('壊れた'));
    expect(result.ran, isFalse);
    expect(result.error, isNotNull);
    expect(result.pruned, isEmpty);
    expect(await store.list(), isEmpty);
  });

  test('store.list の例外も握る（アプリを壊さない）', () async {
    final service = AutoBackupService(
      store: _ThrowingStore(),
      now: () => clock,
    );
    final result = await service.run(buildJsonOk);
    expect(result.ran, isFalse);
    expect(result.error, isNotNull);
  });

  test('同日2回実行しても1件のまま（冪等）', () async {
    await buildService().run(buildJsonOk);
    clock = clock.add(const Duration(hours: 1)); // 24h 未満 → スキップ
    final second = await buildService().run(buildJsonOk);
    expect(second.ran, isFalse);

    // 強制的に同日再実行したい場合は間隔0のポリシーで上書きを確認する
    final forced = AutoBackupService(
      store: store,
      policy: const AutoBackupPolicy(interval: Duration.zero),
      now: () => clock,
    );
    final third = await forced.run(buildJsonOk);
    expect(third.ran, isTrue);
    expect(third.fileName, 'auto_backup_20261029.json');
    expect((await store.list()).length, 1);
  });

  test('手動ファイルは prune で消さない', () async {
    await store.write('manual_backup.json', '{"manual":true}');
    await store.write('auto_backup_20261027.json', '{"old":1}');
    clock = DateTime(2026, 10, 29, 9, 0);
    for (var i = 0; i < 4; i++) {
      await buildService().run(buildJsonOk);
      clock = clock.add(const Duration(days: 1));
    }
    final names = (await store.list()).map((e) => e.fileName).toList();
    expect(names, contains('manual_backup.json'));
    expect(await store.read('manual_backup.json'), '{"manual":true}');
  });

  group('FileAutoBackupStore', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('auto_backup_store_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<FileAutoBackupStore> buildFileStore() async =>
        FileAutoBackupStore(directoryResolver: () async => tmp);

    test('auto_backups/ 配下へ書き込み、一覧に自動ファイルのみ載せる', () async {
      final fileStore = await buildFileStore();
      await fileStore.write('auto_backup_20261029.json', '{"a":1}');
      await fileStore.write('manual_backup.json', '{"m":1}');

      final entries = await fileStore.list();
      expect(entries.map((e) => e.fileName).toList(), ['auto_backup_20261029.json']);
      expect(entries.first.createdAt, DateTime(2026, 10, 29));

      final written = File('${tmp.path}/auto_backups/auto_backup_20261029.json');
      expect(await written.readAsString(), '{"a":1}');
    });

    test('delete は対象を消し、無いファイルでも例外を投げない', () async {
      final fileStore = await buildFileStore();
      await fileStore.write('auto_backup_20261029.json', '{}');
      await fileStore.delete('auto_backup_20261029.json');
      await fileStore.delete('auto_backup_20261029.json');
      expect(await fileStore.list(), isEmpty);
    });

    test('ファイル名から日付を復元できない場合は modified を使う', () async {
      final fileStore = await buildFileStore();
      final dir = Directory('${tmp.path}/auto_backups');
      await dir.create(recursive: true);
      final weird = File('${dir.path}/auto_backup_unknown.json');
      await weird.writeAsString('{}');

      final entries = await fileStore.list();
      expect(entries.length, 1);
      final modified = await weird.lastModified();
      expect(
        entries.first.createdAt.difference(modified).inSeconds.abs(),
        lessThan(5),
      );
    });
  });
}

class _ThrowingStore implements AutoBackupStore {
  @override
  Future<List<AutoBackupEntry>> list() async => throw StateError('読めない');

  @override
  Future<void> write(String fileName, String json) async {}

  @override
  Future<void> delete(String fileName) async {}
}
