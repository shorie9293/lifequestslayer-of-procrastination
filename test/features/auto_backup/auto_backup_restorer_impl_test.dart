import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_restorer_impl.dart';
import 'package:rpg_todo/features/auto_backup/data/auto_backup_store.dart';
import 'package:rpg_todo/features/auto_backup/domain/auto_backup_policy.dart';

/// 操作順序を記録する試練用ストア。
class _RecordingStore implements AutoBackupStore {
  _RecordingStore(this.files);

  final Map<String, String?> files;
  final List<String> ops = [];

  @override
  Future<List<AutoBackupEntry>> list() async {
    ops.add('list');
    return files.entries
        .map((e) => AutoBackupEntry(
              fileName: e.key,
              createdAt: DateTime(2026, 10, 29),
            ))
        .toList();
  }

  @override
  Future<String?> read(String fileName) async {
    ops.add('read:$fileName');
    return files[fileName];
  }

  @override
  Future<void> write(String fileName, String json) async {
    ops.add('write:$fileName');
    files[fileName] = json;
  }

  @override
  Future<void> delete(String fileName) async {
    ops.add('delete:$fileName');
    files.remove(fileName);
  }
}

void main() {
  final now = DateTime(2026, 10, 29, 7, 12);

  test('復元前に本日分の safety スナップショットを write する', () async {
    final store = _RecordingStore({
      'auto_backup_20261028.json': '{"old":true}',
    });
    final applied = <String>[];

    final restorer = AutoBackupRestorerImpl(
      store: store,
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (json) async {
        store.ops.add('apply');
        applied.add(json);
      },
      now: () => now,
    );

    final result = await restorer.restore('auto_backup_20261028.json');

    expect(result.ok, isTrue);
    expect(result.safetyFileName, 'auto_backup_20261029.json');
    expect(applied, ['{"old":true}']);
    expect(store.files['auto_backup_20261029.json'], '{"current":true}');
    // 読み込み → 安全確保 → 適用 の順序
    expect(store.ops, [
      'read:auto_backup_20261028.json',
      'write:auto_backup_20261029.json',
      'apply',
    ]);
  });

  test('不正JSONは apply せず ok:false', () async {
    final store = _RecordingStore({
      'auto_backup_20261028.json': 'not json',
    });
    final applied = <String>[];

    final restorer = AutoBackupRestorerImpl(
      store: store,
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (json) async => applied.add(json),
      now: () => now,
    );

    final result = await restorer.restore('auto_backup_20261028.json');

    expect(result.ok, isFalse);
    expect(result.message, isNotNull);
    expect(applied, isEmpty);
    expect(store.files.containsKey('auto_backup_20261029.json'), isFalse);
  });

  test('存在しないファイルは ok:false', () async {
    final store = _RecordingStore({});
    final restorer = AutoBackupRestorerImpl(
      store: store,
      buildCurrentJson: () async => '{}',
      applyBackup: (_) async {},
      now: () => now,
    );

    final result = await restorer.restore('auto_backup_20261028.json');
    expect(result.ok, isFalse);
  });

  test('apply の例外を握って ok:false（投げない）', () async {
    final store = _RecordingStore({
      'auto_backup_20261028.json': '{"old":true}',
    });
    final restorer = AutoBackupRestorerImpl(
      store: store,
      buildCurrentJson: () async => '{"current":true}',
      applyBackup: (_) async => throw StateError('壊れた'),
      now: () => now,
    );

    final result = await restorer.restore('auto_backup_20261028.json');
    expect(result.ok, isFalse);
    expect(result.message, contains('壊れた'));
    // safety は apply 前に書かれている
    expect(store.files['auto_backup_20261029.json'], '{"current":true}');
  });

  test('buildCurrentJson の例外も握る', () async {
    final store = _RecordingStore({
      'auto_backup_20261028.json': '{"old":true}',
    });
    final restorer = AutoBackupRestorerImpl(
      store: store,
      buildCurrentJson: () async => throw StateError('作れない'),
      applyBackup: (_) async {},
      now: () => now,
    );

    final result = await restorer.restore('auto_backup_20261028.json');
    expect(result.ok, isFalse);
  });
}
