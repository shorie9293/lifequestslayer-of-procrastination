import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/domain/models/practice_log.dart';
import 'package:rpg_todo/features/habits/data/practice_log_repository.dart';

void main() {
  late PracticeLogRepository repo;

  setUpAll(() async {
    final testDir = Directory(
        '${Directory.systemTemp.path}/practice_log_repo_${DateTime.now().millisecondsSinceEpoch}');
    if (!testDir.existsSync()) {
      testDir.createSync(recursive: true);
    }
    Hive.init(testDir.path);
  });

  setUp(() async {
    repo = PracticeLogRepository();
    await repo.clearAll();
  });

  tearDown(() async {
    await repo.close();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('record は当日のログを新規作成する', () async {
    final entry = await repo.record(at: DateTime(2026, 9, 15, 8));
    expect(entry.id, '2026-09-15');
    expect(entry.count, 1);

    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.first.date, DateTime(2026, 9, 15));
    expect(await repo.getCount(), 1);
  });

  test('同日に複数回 record すると回数が加算されレコードは1件のまま', () async {
    await repo.record(at: DateTime(2026, 9, 15, 8));
    await repo.record(at: DateTime(2026, 9, 15, 20));
    final entry = await repo.record(at: DateTime(2026, 9, 15, 22), amount: 2);

    expect(entry.count, 4);
    expect(await repo.getCount(), 1);
    final all = await repo.getAll();
    expect(all.single.count, 4);
  });

  test('getAll は日付昇順で返す', () async {
    await repo.record(at: DateTime(2026, 9, 20));
    await repo.record(at: DateTime(2026, 9, 1));
    await repo.record(at: DateTime(2026, 9, 10));
    final all = await repo.getAll();
    expect(all.map((l) => l.id).toList(),
        ['2026-09-01', '2026-09-10', '2026-09-20']);
  });

  test('破損レコードは読み飛ばし、健全な履歴を守る', () async {
    await repo.record(at: DateTime(2026, 9, 10));
    final box = await Hive.openBox<String>(PracticeLogRepository.boxName);
    await box.put('broken-1', 'not-json');
    await box.put('broken-2', '{"date":"2026-09-11"}');
    await box.put('broken-3',
        '{"date":"2026-09-11","count":0,"updatedAt":"2026-09-11"}');

    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.single.id, '2026-09-10');
  });

  test('record はリポジトリ再生成後も永続値を読み、加算を継続する', () async {
    await repo.record(at: DateTime(2026, 9, 15));
    final other = PracticeLogRepository();
    final entry = await other.record(at: DateTime(2026, 9, 15));
    expect(entry.count, 2);
    await other.close();
    expect((await repo.getAll()).single.count, 2);
  });

  test('clearAll は全ログを削除する', () async {
    await repo.record(at: DateTime(2026, 9, 15));
    await repo.clearAll();
    expect(await repo.getAll(), isEmpty);
    expect(await repo.getCount(), 0);
  });

  test('保存形式は jsonEncode された PracticeLog である', () async {
    await repo.record(at: DateTime(2026, 9, 15), amount: 3);
    final box = await Hive.openBox<String>(PracticeLogRepository.boxName);
    final raw = box.get(PracticeLog.keyOf(DateTime(2026, 9, 15)));
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as Map<String, dynamic>;
    final restored = PracticeLog.fromJson(decoded);
    expect(restored.count, 3);
    expect(restored.id, '2026-09-15');
  });
}
