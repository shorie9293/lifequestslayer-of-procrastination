// 親探針: 子は「個別の記録」しか撃たないため、
// 往復・再起動を跨ぐ永続・並行・失敗の連鎖・空ファイルの件数を親が独立に撃つ。
//
// これらが緑でなければ「連携状況」は実機で嘘をつく。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status_store.dart';
import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';

void main() {
  late Directory tempDir;
  late InMemoryCrossAppLinkStatusStore statusStore;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('crossapp_probe_');
    statusStore = InMemoryCrossAppLinkStatusStore();
    CrossAppLinkStatusRecorder.reset(
      CrossAppLinkStatusRecorder(
        store: statusStore,
        now: () => DateTime(2026, 11, 11, 9, 12),
      ),
    );
  });

  tearDown(() {
    CrossAppLinkStatusRecorder.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// 記録は投げっぱなしで走るため、条件が満たされるまで待ってから読む。
  Future<CrossAppLinkSnapshot> waitFor(
    bool Function(CrossAppLinkSnapshot) predicate,
  ) async {
    for (var i = 0; i < 200; i++) {
      final snapshot = await CrossAppLinkStatusRecorder.instance.load();
      if (predicate(snapshot)) return snapshot;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return CrossAppLinkStatusRecorder.instance.load();
  }

  test('探針1: 2現世の往復 — 送信記録と受信記録が同じ共有フォルダで対になり、受信件数=行数', () async {
    final sender = FileSharedFileStore(tempDir); // tsundoku のつもり
    final receiver = FileSharedFileStore(tempDir); // rpg のつもり

    await sender.ensureDirectory();
    for (var i = 0; i < 3; i++) {
      await sender.appendLine(
        SharedCrossAppFiles.tsundokuRewardEvents,
        '{"i":$i}',
      );
    }

    final afterSend = await waitFor((s) => s.lastSent?.ok == true);
    expect(afterSend.lastSent?.ok, isTrue);
    expect(
      afterSend.lastSent?.fileName,
      SharedCrossAppFiles.tsundokuRewardEvents,
    );

    final content =
        await receiver.readString(SharedCrossAppFiles.tsundokuRewardEvents);
    expect(content, isNotNull);

    final afterReceive = await waitFor((s) => s.lastReceived != null);
    expect(afterReceive.lastReceived?.ok, isTrue);
    expect(
      afterReceive.lastReceived?.count,
      3,
      reason: '受信件数は読んだ行数と一致せよ（3行を1件と数める）',
    );
    expect(
      afterReceive.lastReceived?.fileName,
      SharedCrossAppFiles.tsundokuRewardEvents,
    );
  });

  test('探針2: 再起動を跨いでも「最後の送信」が残る（表示は成否・時刻・件数・名前）', () async {
    final store = FileSharedFileStore(tempDir);
    await store.writeString(SharedCrossAppFiles.kozuchiQuest, '{"quest":1}');
    await waitFor((s) => s.lastSent?.ok == true);

    // アプリ再起動を模す: 同じ保存先で新しい記録口を作る。
    final restarted = CrossAppLinkStatusRecorder(
      store: statusStore,
      now: () => DateTime(2026, 11, 11, 10, 30),
    );
    final snapshot = await restarted.load();

    expect(snapshot.lastSent?.ok, isTrue);
    expect(snapshot.lastSent?.fileName, SharedCrossAppFiles.kozuchiQuest);
    expect(
      CrossAppLinkStatusText.row(snapshot.lastSent),
      '成功・2026/11/11 09:12・1件・kozuchi_quest.json',
    );
  });

  test('探針3: 並行10件の送信で記録が失われない・例外が漏れない', () async {
    final recorder = CrossAppLinkStatusRecorder.instance;
    await Future.wait<void>([
      for (var i = 0; i < 10; i++)
        recorder.recordSent(count: i + 1, fileName: 'f$i.json'),
    ]);
    final snapshot = await recorder.load();
    expect(snapshot.lastSent?.ok, isTrue);
    expect(statusStore.saveCount, greaterThan(0));
    expect(snapshot.lastSent?.count, inInclusiveRange(1, 10));
  });

  test('探針4: 書けないフォルダでは送信失敗として理由付きで残る（無音にしない）', () async {
    final blocker = File('${tempDir.path}/blocked')
      ..writeAsStringSync('not a directory');
    final broken = FileSharedFileStore(Directory(blocker.path));

    expect(await broken.ensureDirectory(), isFalse);
    await expectLater(
      broken.writeString('a.json', '{}'),
      throwsA(isA<SharedStorageException>()),
    );

    final snapshot = await waitFor((s) => s.lastSent != null);
    expect(snapshot.lastSent?.ok, isFalse);
    expect(CrossAppLinkStatusText.outcome(snapshot.lastSent), '失敗');
    expect(CrossAppLinkStatusText.detail(snapshot.lastSent), isNotEmpty);
    expect(snapshot.sharedFolderReady, isFalse);
  });

  test('探針5: 空ファイルは「0件の受信」であり、1件と数えない', () async {
    final store = FileSharedFileStore(tempDir);
    await store.writeString(SharedCrossAppFiles.tsundokuBookEvents, '');
    await waitFor((s) => s.lastSent?.ok == true);

    await store.readString(SharedCrossAppFiles.tsundokuBookEvents);
    final snapshot = await waitFor((s) => s.lastReceived != null);
    expect(snapshot.lastReceived?.count, 0);
    expect(CrossAppLinkStatusText.row(snapshot.lastReceived), contains('0件'));
  });
}
