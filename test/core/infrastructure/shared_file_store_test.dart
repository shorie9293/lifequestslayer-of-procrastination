// 共有ストレージ抽象の試練。
//
// ここが緑でなければ「現世をまたぐ受け渡し」は実機で動かない。
// 実機（SAF）の 1 往復は別途。ここでは抽象の契約を固定する。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/shared_file_store.dart';

void main() {
  late Directory tempDir;
  late FileSharedFileStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('shared_store_');
    store = FileSharedFileStore(tempDir);
    SharedFileStore.reset();
  });

  tearDown(() {
    SharedFileStore.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('契約: ファイル名', () {
    test('5現世で共有するファイル名が固定されている', () {
      expect(SharedCrossAppFiles.rpgEnemyDefeatJson,
          'rpg_enemy_defeat_events.json');
      expect(SharedCrossAppFiles.rpgEnemyDefeatJsonl,
          'rpg_enemy_defeat_events.jsonl');
      expect(SharedCrossAppFiles.tsundokuRewardEvents,
          'tsundoku_reward_events.jsonl');
      expect(SharedCrossAppFiles.tsundokuBookEvents, 'tsundoku_book_events.json');
      expect(SharedCrossAppFiles.tsundokuBookCompleted,
          'tsundoku_book_completed.json');
      expect(SharedCrossAppFiles.electionRewardEvents,
          'election_reward_events.jsonl');
      expect(SharedCrossAppFiles.bookReviewRewardEvents,
          'book_review_reward_events.jsonl');
      expect(SharedCrossAppFiles.kozuchiQuest, 'kozuchi_quest.json');
    });
  });

  group('FileSharedFileStore', () {
    test('writeString → readString で往復する', () async {
      expect(await store.ensureDirectory(), isTrue);
      await store.writeString('a.json', '{"x":1}');
      expect(await store.readString('a.json'), '{"x":1}');
    });

    test('writeString は上書きする', () async {
      await store.writeString('a.json', 'first');
      await store.writeString('a.json', 'second');
      expect(await store.readString('a.json'), 'second');
    });

    test('appendLine は1行ずつ追記する', () async {
      await store.appendLine('b.jsonl', 'line1');
      await store.appendLine('b.jsonl', 'line2');
      expect(await store.readString('b.jsonl'), 'line1\nline2\n');
    });

    test('存在しないファイルの readString は null', () async {
      expect(await store.readString('none.json'), isNull);
    });

    test('delete は消せたら true・無ければ false', () async {
      await store.writeString('c.json', 'x');
      expect(await store.delete('c.json'), isTrue);
      expect(await store.delete('c.json'), isFalse);
    });

    test('exists と listFiles が実ファイルを反映する', () async {
      await store.writeString('d.json', 'x');
      expect(await store.exists('d.json'), isTrue);
      expect(await store.listFiles(), contains('d.json'));
    });

    test('親ディレクトリが無くても writeString が自動で作る', () async {
      final nested = FileSharedFileStore(
        Directory('${tempDir.path}/nested/deep'),
      );
      await nested.writeString('e.json', 'x');
      expect(await nested.readString('e.json'), 'x');
    });
  });

  group('失敗を握りつぶさない', () {
    test('書けない場所では SharedStorageException を投げる', () async {
      // ファイルをディレクトリとして扱わせ、必ず失敗させる
      final blocked = File('${tempDir.path}/blocked');
      await blocked.writeAsString('not a directory');
      final broken = FileSharedFileStore(Directory(blocked.path));

      await expectLater(
        broken.writeString('f.json', 'x'),
        throwsA(isA<SharedStorageException>()),
      );
    });

    test('例外は操作名とファイル名を保持する', () async {
      final blocked = File('${tempDir.path}/blocked2');
      await blocked.writeAsString('not a directory');
      final broken = FileSharedFileStore(Directory(blocked.path));

      try {
        await broken.writeString('g.json', 'x');
        fail('例外が出るはず');
      } on SharedStorageException catch (e) {
        expect(e.operation, 'write');
        expect(e.fileName, 'g.json');
        expect(e.cause, isNotNull);
      }
    });
  });

  group('SharedFileStore（全体で1つ）', () {
    test('configure した実装を instance が返す', () {
      SharedFileStore.configure(store);
      expect(SharedFileStore.instance, same(store));
      expect(SharedFileStore.isConfigured, isTrue);
    });

    test('未設定なら一時領域のファイル実装へフォールバックする', () {
      final instance = SharedFileStore.instance;
      expect(instance, isA<FileSharedFileStore>());
      expect(SharedFileStore.isConfigured, isFalse);
    });

    test('reset で未設定に戻る', () {
      SharedFileStore.configure(store);
      SharedFileStore.reset();
      expect(SharedFileStore.isConfigured, isFalse);
    });
  });
}
