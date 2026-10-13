import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/guild/data/task_time_record_repository.dart';
import 'package:rpg_todo/features/guild/domain/task_time_record.dart';

/// 見積もり時間記録リポジトリ（改善提案 #131）の試練。
///
/// 実 Hive の openBox は試練内で呼ばない（zone 汚染防止）。
/// Hive 実装にはテスト用フェイク Box を注入して検証する。
class _FakeBox implements Box<String> {
  final Map<String, String> store = {};

  @override
  Iterable<String> get values => store.values;

  @override
  Iterable<dynamic> get keys => store.keys;

  @override
  int get length => store.length;

  @override
  Future<void> put(dynamic key, String value) async => store[key] = value;

  @override
  Future<int> clear() async {
    final n = store.length;
    store.clear();
    return n;
  }

  @override
  String? get(dynamic key, {String? defaultValue}) => store[key];

  @override
  bool get isOpen => true;

  @override
  Future<void> delete(dynamic key) async {
    store.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final base = DateTime(2026, 10, 14, 9);

  TaskTimeRecord rec(String id, DateTime at, {int est = 30, int act = 40}) =>
      TaskTimeRecord(
        taskId: id,
        title: '討伐$id',
        estimatedMinutes: est,
        actualMinutes: act,
        recordedAt: at,
      );

  group('InMemoryTaskTimeRecordRepository', () {
    test('save→loadAll 往復（recordedAt 降順）', () async {
      final repo = InMemoryTaskTimeRecordRepository();
      final r1 = rec('r1', base);
      final r2 = rec('r2', base.add(const Duration(minutes: 1)));
      await repo.save(r1);
      await repo.save(r2);
      final loaded = await repo.loadAll();
      expect(loaded, [r2, r1]); // 新しい順
    });

    test('同一 id は上書き', () async {
      final repo = InMemoryTaskTimeRecordRepository();
      await repo.save(rec('r1', base, act: 40));
      await repo.save(rec('r1', base, act: 55));
      final loaded = await repo.loadAll();
      expect(loaded.length, 1);
      expect(loaded.first.actualMinutes, 55);
    });

    test('delete で1件削除', () async {
      final repo = InMemoryTaskTimeRecordRepository();
      await repo.save(rec('r1', base));
      await repo.delete(rec('r1', base).id);
      expect(await repo.loadAll(), isEmpty);
    });

    test('clear で全消去', () async {
      final repo = InMemoryTaskTimeRecordRepository();
      await repo.save(rec('r1', base));
      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
    });

    test('同時刻は taskId 昇順', () async {
      final repo = InMemoryTaskTimeRecordRepository();
      await repo.save(rec('b', base));
      await repo.save(rec('a', base));
      final loaded = await repo.loadAll();
      expect(loaded.map((r) => r.taskId).toList(), ['a', 'b']);
    });

    test('500件上限で最古を削除', () async {
      final repo = InMemoryTaskTimeRecordRepository();
      for (var i = 0; i < 503; i++) {
        await repo.save(rec('r$i', base.add(Duration(minutes: i))));
      }
      final loaded = await repo.loadAll();
      expect(loaded.length, 500);
      expect(loaded.any((r) => r.taskId == 'r0'), isFalse);
      expect(loaded.any((r) => r.taskId == 'r2'), isFalse);
      expect(loaded.any((r) => r.taskId == 'r3'), isTrue);
    });
  });

  group('HiveTaskTimeRecordRepository（注入 Box）', () {
    test('save→loadAll 往復・破損行読み飛ばし', () async {
      final box = _FakeBox();
      final repo = HiveTaskTimeRecordRepository(box: box);
      final r1 = rec('r1', base, est: 30, act: 42);
      await repo.save(r1);
      await repo.save(rec('r2', base.add(const Duration(minutes: 1))));
      // 破損エントリを直接混入
      box.store['broken'] = '{not json';
      box.store['brokenType'] = jsonEncode({'taskId': 1});

      final loaded = await repo.loadAll();
      expect(loaded.length, 2);
      expect(loaded.firstWhere((r) => r.taskId == 'r1').actualMinutes, 42);
      // recordedAt 降順
      expect(loaded.first.taskId, 'r2');
    });

    test('同一 id は上書き', () async {
      final box = _FakeBox();
      final repo = HiveTaskTimeRecordRepository(box: box);
      await repo.save(rec('r1', base, act: 40));
      await repo.save(rec('r1', base, act: 55));
      final loaded = await repo.loadAll();
      expect(loaded.length, 1);
      expect(loaded.first.actualMinutes, 55);
    });

    test('delete で1件削除', () async {
      final box = _FakeBox();
      final repo = HiveTaskTimeRecordRepository(box: box);
      await repo.save(rec('r1', base));
      await repo.delete(rec('r1', base).id);
      expect(await repo.loadAll(), isEmpty);
    });

    test('clear で全消去', () async {
      final box = _FakeBox();
      final repo = HiveTaskTimeRecordRepository(box: box);
      await repo.save(rec('r1', base));
      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
      expect(box.store, isEmpty);
    });

    test('保存値は JSON 文字列である', () async {
      final box = _FakeBox();
      final repo = HiveTaskTimeRecordRepository(box: box);
      await repo.save(rec('r9', base));
      final raw = box.store[rec('r9', base).id]!;
      expect(jsonDecode(raw), isA<Map<String, dynamic>>());
      final back = TaskTimeRecord.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      expect(back.taskId, 'r9');
    });

    test('500件上限で最古を削除（破損エントリは候補外）', () async {
      final box = _FakeBox();
      final repo = HiveTaskTimeRecordRepository(box: box);
      for (var i = 0; i < 502; i++) {
        await repo.save(rec('r$i', base.add(Duration(minutes: i))));
      }
      box.store['broken'] = '{not json';
      final loaded = await repo.loadAll();
      // 'broken' は読み飛ばし対象 → 有効レコードは 500 件
      expect(loaded.length, 500);
      expect(loaded.any((r) => r.taskId == 'r0'), isFalse);
      expect(loaded.any((r) => r.taskId == 'r1'), isFalse);
      expect(loaded.any((r) => r.taskId == 'r2'), isTrue);
    });
  });

  group('抽象クラス', () {
    test('両実装とも TaskTimeRecordRepository を実装する', () {
      expect(
        HiveTaskTimeRecordRepository(box: _FakeBox()),
        isA<TaskTimeRecordRepository>(),
      );
      expect(
        InMemoryTaskTimeRecordRepository(),
        isA<TaskTimeRecordRepository>(),
      );
    });

    test('boxName の凍結値', () {
      expect(HiveTaskTimeRecordRepository.boxName, 'task_time_records');
    });
  });
}
