// 記録口（CrossAppLinkStatusRecorder）の試練。
//
// 契約:
// - 記録の失敗で本処理を止めない（throw しない）
// - 同時記録で取りこぼさない（直列化）
// - 初回記録の前に前回保存値を消さない
import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';

void main() {
  late InMemoryCrossAppLinkStatusStore store;
  late CrossAppLinkStatusRecorder recorder;

  setUp(() {
    store = InMemoryCrossAppLinkStatusStore();
    recorder = CrossAppLinkStatusRecorder(
      store: store,
      now: () => DateTime(2026, 11, 11, 9, 0),
    );
  });

  group('記録の基本', () {
    test('recordSent は最終送信を成功で記録する', () async {
      await recorder.recordSent(count: 1, fileName: 'a.jsonl');

      final sent = recorder.cached.lastSent!;
      expect(sent.ok, isTrue);
      expect(sent.count, 1);
      expect(sent.fileName, 'a.jsonl');
      expect(sent.at, DateTime(2026, 11, 11, 9, 0));
      expect(store.saveCount, 1);
    });

    test('recordSendFailure は失敗と理由を記録する', () async {
      await recorder.recordSendFailure(
        StateError('disk full'),
        fileName: 'b.jsonl',
      );

      final sent = recorder.cached.lastSent!;
      expect(sent.ok, isFalse);
      expect(sent.count, 0);
      expect(sent.error, contains('disk full'));
    });

    test('recordReceived は最終受信だけを更新する', () async {
      await recorder.recordSent(count: 1, fileName: 'a.jsonl');
      await recorder.recordReceived(count: 4, fileName: 'b.jsonl');

      expect(recorder.cached.lastSent!.fileName, 'a.jsonl');
      expect(recorder.cached.lastReceived!.count, 4);
      expect(recorder.cached.lastReceived!.ok, isTrue);
    });

    test('recordFolderReady はフォルダ状態だけを更新する', () async {
      await recorder.recordSent(count: 1, fileName: 'a.jsonl');
      await recorder.recordFolderReady(true);

      expect(recorder.cached.sharedFolderReady, isTrue);
      expect(recorder.cached.lastSent!.fileName, 'a.jsonl');
    });

    test('既定の件数は送受信とも1件・失敗は0件', () async {
      await recorder.recordSent(fileName: 'a.jsonl');
      expect(recorder.cached.lastSent!.count, 1);

      await recorder.recordReceived(fileName: 'a.jsonl');
      expect(recorder.cached.lastReceived!.count, 1);

      await recorder.recordSendFailure(StateError('x'));
      expect(recorder.cached.lastSent!.count, 0);
    });
  });

  group('失敗を本処理へ漏らさない', () {
    test('保存が throw しても recordSent は throw しない', () async {
      store.throwOnSave = true;

      await expectLater(
        recorder.recordSent(count: 1, fileName: 'a.jsonl'),
        completes,
      );
      // メモリ側の状態は残る（画面が古い値を出さない）
      expect(recorder.cached.lastSent!.fileName, 'a.jsonl');
    });

    test('保存が throw しても recordFolderReady は throw しない', () async {
      store.throwOnSave = true;
      await expectLater(recorder.recordFolderReady(true), completes);
      expect(recorder.cached.sharedFolderReady, isTrue);
    });

    test('load が throw しても空で継続する', () async {
      final broken = _ThrowingLoadStore();
      final r = CrossAppLinkStatusRecorder(store: broken);

      final snapshot = await r.load();

      expect(snapshot.lastSent, isNull);
      await expectLater(r.recordSent(count: 1), completes);
      expect(r.cached.lastSent, isNotNull);
    });
  });

  group('直列化・永続の保持', () {
    test('並行10件でも取りこぼさない', () async {
      await Future.wait([
        for (var i = 0; i < 10; i++)
          recorder.recordSent(count: i + 1, fileName: 'f$i.jsonl'),
      ]);

      // 最後に書かれたものが勝つが、保存は10回すべて走る
      expect(store.saveCount, 10);
      expect(recorder.cached.lastSent!.count, 10);
      expect(recorder.cached.lastSent!.fileName, 'f9.jsonl');
    });

    test('load 前でも前回保存値を消さない', () async {
      final previous = CrossAppLinkSnapshot(
        lastReceived: CrossAppTransferRecord(
          at: DateTime(2026, 11, 10, 21, 30),
          ok: true,
          count: 7,
          fileName: 'yesterday.jsonl',
        ),
        sharedFolderReady: true,
      );
      final seeded = InMemoryCrossAppLinkStatusStore(previous);
      final r = CrossAppLinkStatusRecorder(
        store: seeded,
        now: () => DateTime(2026, 11, 11, 9, 0),
      );

      // load() を明示的に呼ばずに記録する
      await r.recordSent(count: 1, fileName: 'today.jsonl');

      expect(r.cached.lastReceived!.fileName, 'yesterday.jsonl');
      expect(r.cached.lastReceived!.count, 7);
      expect(r.cached.sharedFolderReady, isTrue);
      // 保存された内容にも前回分が残っている
      final persisted = await seeded.load();
      expect(persisted.lastReceived!.fileName, 'yesterday.jsonl');
      expect(persisted.lastSent!.fileName, 'today.jsonl');
    });

    test('reset で instance を差し替えられる', () async {
      CrossAppLinkStatusRecorder.reset(recorder);
      expect(CrossAppLinkStatusRecorder.instance, same(recorder));

      CrossAppLinkStatusRecorder.reset();
      expect(CrossAppLinkStatusRecorder.instance, isNot(same(recorder)));
    });
  });
}

class _ThrowingLoadStore implements ICrossAppLinkStatusStore {
  @override
  Future<CrossAppLinkSnapshot> load() async => throw StateError('load failed');

  @override
  Future<void> save(CrossAppLinkSnapshot snapshot) async =>
      throw StateError('save failed');
}
