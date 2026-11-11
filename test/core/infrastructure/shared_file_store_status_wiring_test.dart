// 共有ファイルストア → 連携状態の計装試練。
//
// 「送った／受け取った」が実際の書込・読取から自動で残ることを固定する。
// 記録は本処理を止めない（書込の成否は従来どおり戻り値・例外で判断する）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';
import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';

/// 記録は unawaited で走るため、反映を待つ小さな猶予。
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  late Directory tempDir;
  late FileSharedFileStore store;
  late CrossAppLinkStatusRecorder recorder;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shared_store_wiring_');
    store = FileSharedFileStore(tempDir);
    recorder = CrossAppLinkStatusRecorder(
      store: InMemoryCrossAppLinkStatusStore(),
      now: () => DateTime(2026, 11, 11, 9, 0),
    );
    CrossAppLinkStatusRecorder.reset(recorder);
  });

  tearDown(() {
    CrossAppLinkStatusRecorder.reset();
    SharedFileStore.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('送信の記録', () {
    test('writeString で最終送信が1件記録される', () async {
      await store.writeString('a.json', '{"x":1}');
      await settle();

      final sent = recorder.cached.lastSent;
      expect(sent, isNotNull);
      expect(sent!.ok, isTrue);
      expect(sent.count, 1);
      expect(sent.fileName, 'a.json');
      expect(sent.at, DateTime(2026, 11, 11, 9, 0));
    });

    test('appendLine で最終送信が1件記録される', () async {
      await store.appendLine('b.jsonl', 'line1');
      await settle();

      final sent = recorder.cached.lastSent!;
      expect(sent.ok, isTrue);
      expect(sent.count, 1);
      expect(sent.fileName, 'b.jsonl');
    });

    test('ensureDirectory で共有フォルダが設定済みになる', () async {
      expect(await store.ensureDirectory(), isTrue);
      await settle();

      expect(recorder.cached.sharedFolderReady, isTrue);
    });

    test('書込失敗は送信失敗（ok=false・理由あり）として残る', () async {
      final blocked = File('${tempDir.path}/blocked');
      await blocked.writeAsString('not a directory');
      final broken = FileSharedFileStore(Directory(blocked.path));

      await expectLater(
        broken.writeString('c.json', 'x'),
        throwsA(isA<SharedStorageException>()),
      );
      await settle();

      final sent = recorder.cached.lastSent!;
      expect(sent.ok, isFalse);
      expect(sent.fileName, 'c.json');
      expect(sent.error, isNotNull);
      expect(sent.error, isNotEmpty);
    });
  });

  group('受信の記録', () {
    test('readString で最終受信が行数ぶん記録される', () async {
      await store.writeString('d.jsonl', 'a\nb\nc\n');
      await store.readString('d.jsonl');
      await settle();

      final received = recorder.cached.lastReceived!;
      expect(received.ok, isTrue);
      expect(received.count, 3);
      expect(received.fileName, 'd.jsonl');
    });

    test('単一JSONの受信は1件', () async {
      await store.writeString('e.json', '{"x":1}');
      await store.readString('e.json');
      await settle();

      expect(recorder.cached.lastReceived!.count, 1);
    });

    test('存在しないファイルは受信を記録しない', () async {
      expect(await store.readString('none.json'), isNull);
      await settle();

      expect(recorder.cached.lastReceived, isNull);
      // 送信側も動いていない（読取だけでは送信を汚さない）
      expect(recorder.cached.lastSent, isNull);
    });

    test('送信と受信は別々の枠に残る', () async {
      await store.writeString('f.jsonl', 'a\nb\n');
      await store.readString('f.jsonl');
      await settle();

      expect(recorder.cached.lastSent!.count, 1);
      expect(recorder.cached.lastReceived!.count, 2);
    });
  });

  group('記録対象外の操作', () {
    test('exists / listFiles / delete は送受信を記録しない', () async {
      await store.writeString('g.json', 'x');
      await settle();

      final before = recorder.cached.lastSent;
      await store.exists('g.json');
      await store.listFiles();
      await store.delete('g.json');
      await settle();

      expect(recorder.cached.lastSent!.fileName, before!.fileName);
      expect(recorder.cached.lastSent!.count, before.count);
      expect(recorder.cached.lastReceived, isNull);
    });
  });

  group('状態の往復', () {
    test('書込→読取の記録は保存され、別の記録口から読める', () async {
      final shared = InMemoryCrossAppLinkStatusStore();
      CrossAppLinkStatusRecorder.reset(
        CrossAppLinkStatusRecorder(
          store: shared,
          now: () => DateTime(2026, 11, 11, 9, 0),
        ),
      );

      await store.writeString('h.jsonl', 'a\nb\n');
      await store.readString('h.jsonl');
      await settle();

      final reloaded = await CrossAppLinkStatusRecorder(store: shared).load();
      expect(reloaded.lastSent!.fileName, 'h.jsonl');
      expect(reloaded.lastReceived!.count, 2);
    });
  });
}
