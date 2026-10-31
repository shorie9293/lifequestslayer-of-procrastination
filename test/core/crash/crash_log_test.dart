import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/crash/crash_log_entry.dart';
import 'package:rpg_todo/core/crash/crash_log_repository.dart';
import 'package:rpg_todo/core/crash/crash_log_service.dart';

CrashLogEntry _entry(int i, {DateTime? at}) => CrashLogEntry(
      timestamp:
          at ?? DateTime(2026, 11, 1, 12, 0, 0).add(Duration(seconds: i)),
      kind: 'uncaught',
      message: 'error $i',
      stackTop: '#0 frame',
    );

void main() {
  group('CrashLogEntry', () {
    test('message は先頭200字に切り詰められる', () {
      final entry = CrashLogEntry(
        timestamp: DateTime(2026, 11, 1),
        kind: 'uncaught',
        message: 'あ' * 500,
      );
      expect(entry.message.length, CrashLogEntry.maxMessageLength);
      expect(entry.message, 'あ' * 200);
    });

    test('stack は先頭10フレーム（10行）に切り詰められる', () {
      final stack = List.generate(40, (i) => '#$i frame').join('\n');
      final entry = CrashLogEntry(
        timestamp: DateTime(2026, 11, 1),
        kind: 'uncaught',
        message: 'boom',
        stackTop: stack,
      );
      final lines = entry.stackTop!.split('\n');
      expect(lines.length, CrashLogEntry.maxStackFrames);
      expect(lines.first, '#0 frame');
      expect(lines.last, '#9 frame');
    });

    test('toJson / fromJson で往復でき、値等価である', () {
      final entry = _entry(1);
      final restored = CrashLogEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>,
      );
      expect(restored, entry);
      expect(restored.hashCode, entry.hashCode);
    });

    test('fromJson は破損時に null（tryParse）を返す', () {
      expect(CrashLogEntry.tryParse({'kind': 'x'}), isNull);
      expect(
          CrashLogEntry.tryParse({'ts': 'not-a-date', 'kind': 'x', 'msg': 'y'}),
          isNull);
      expect(() => CrashLogEntry.fromJson({'ts': 1, 'kind': 2, 'msg': 3}),
          throwsA(isA<FormatException>()));
    });
  });

  group('クラッシュ記録の追記', () {
    test('record で JSONL が1行増える（InMemory 件数）', () async {
      final repo = InMemoryCrashLogRepository();
      final logger = CrashLogger(repository: repo);

      logger.record(StateError('落ちた'), StackTrace.current, kind: 'zone');
      // 投げっぱなし API のため、マイクロタスクを1回回して反映を待つ。
      await Future<void>.delayed(Duration.zero);

      final entries = await repo.loadAll();
      expect(entries.length, 1);
      expect(entries.single.kind, 'zone');
      expect(entries.single.message, contains('落ちた'));
    });

    test('記録失敗しても record は例外を漏らさない', () async {
      final logger = CrashLogger(repository: _ThrowingRepository());
      expect(
        () => logger.record(Exception('x'), StackTrace.current),
        returnsNormally,
      );
      await Future<void>.delayed(Duration.zero);
    });

    test('51件目で最古が落ちて50件になる', () async {
      final repo = InMemoryCrashLogRepository();
      final logger = CrashLogger(repository: repo);
      for (var i = 0; i < 51; i++) {
        logger.record(Exception('e$i'), null);
      }
      await Future<void>.delayed(Duration.zero);

      final entries = await repo.loadAll();
      expect(entries.length, kCrashLogMaxEntries);
      expect(entries.first.message, contains('e1'));
      expect(entries.last.message, contains('e50'));
    });

    test('clear で全消去できる', () async {
      final repo = InMemoryCrashLogRepository();
      await repo.append(_entry(1));
      await repo.clear();
      expect(await repo.loadAll(), isEmpty);
    });
  });

  group('FileCrashLogRepository', () {
    late Directory dir;
    late FileCrashLogRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('crash_log_test');
      repo = FileCrashLogRepository(directoryProvider: () async => dir);
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('1行1JSONで追記され、壊れた行は読み飛ばす', () async {
      await repo.append(_entry(1));
      await repo.append(_entry(2));

      final file = File('${dir.path}/crash_log.jsonl');
      final lines = const LineSplitter().convert(await file.readAsString());
      expect(lines.where((l) => l.trim().isNotEmpty).length, 2);

      // 壊れた行を差し込む
      await file.writeAsString(
        '${await file.readAsString()}\n{not json}\n\n'
        '{"ts":"bad","kind":"x","msg":"y"}\n',
      );

      final entries = await repo.loadAll();
      expect(entries.length, 2);
      expect(entries.first.message, 'error 1');
      expect(entries.last.message, 'error 2');
    });

    test('ファイルが無ければ空リストを返す', () async {
      expect(await repo.loadAll(), isEmpty);
    });

    test('50件を超えると古い行から落ちる', () async {
      for (var i = 0; i < 55; i++) {
        await repo.append(_entry(i));
      }
      final entries = await repo.loadAll();
      expect(entries.length, kCrashLogMaxEntries);
      expect(entries.first.message, 'error 5');
      expect(entries.last.message, 'error 54');
    });

    test('保存先が使えなくても例外を漏らさない', () async {
      final broken = FileCrashLogRepository(
        directoryProvider: () async =>
            throw const FileSystemException('no dir'),
      );
      expect(await broken.loadAll(), isEmpty);
      await expectLater(broken.append(_entry(1)), completes);
      await expectLater(broken.clear(), completes);
    });
  });

  group('summarize / recent', () {
    test('2件なら「前回の異常終了 2件（最終 HH:mm）」を返す', () {
      final now = DateTime(2026, 11, 1, 18, 0);
      final entries = [
        _entry(1, at: DateTime(2026, 11, 1, 9, 5)),
        _entry(2, at: DateTime(2026, 11, 1, 9, 42)),
      ];
      expect(
        summarize(entries, now: () => now),
        '前回の異常終了 2件（最終 09:42）',
      );
    });

    test('0件なら null', () {
      expect(summarize(const []), isNull);
    });

    test('別日なら日付を添える', () {
      final now = DateTime(2026, 11, 2, 8, 0);
      final entries = [_entry(1, at: DateTime(2026, 11, 1, 22, 7))];
      expect(
        summarize(entries, now: () => now),
        '前回の異常終了 1件（最終 11/1 22:07）',
      );
    });

    test('recent は新しい順に limit 件だけ返す', () {
      final entries = [_entry(1), _entry(2), _entry(3)];
      final r = recent(entries, limit: 2);
      expect(r.length, 2);
      expect(r.first.message, 'error 3');
      expect(r.last.message, 'error 2');
      expect(recent(entries, limit: 0), isEmpty);
    });
  });
}

class _ThrowingRepository implements CrashLogRepository {
  @override
  Future<void> append(CrashLogEntry entry) async => throw StateError('保存できない');

  @override
  Future<void> clear() async => throw StateError('消せない');

  @override
  Future<List<CrashLogEntry>> loadAll() async => throw StateError('読めない');
}
