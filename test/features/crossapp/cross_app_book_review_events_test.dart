import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/crossapp/data/cross_app_reward_service.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';

/// book-review-app が書き出す book_review_reward_events.jsonl を
/// rpg-task が読み取り、報酬・称号へ変換できることを検める試練。
///
/// 契約 v1（book-review-app）:
///   event_type: book_completed
///   book_completed.metadata: {count}
///
/// 現行仕様の脆さも同時に固定する（metadata.count が int 以外だと行が捨てられる）。
void main() {
  const kLinkedUser = 'brv12345';
  const kUserId = 'brv12345-6789-0abc-def1-234567890abc';

  group('FileCrossAppRewardService: book-review JSONL の読み取り', () {
    late Directory tempDir;
    late String tsundokuPath;
    late String bookReviewPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('crossapp_book_review_');
      tsundokuPath = '${tempDir.path}/tsundoku_reward_events.jsonl';
      bookReviewPath = '${tempDir.path}/book_review_reward_events.jsonl';
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    String bookReviewLine({
      required String eventId,
      String eventType = 'book_completed',
      String userId = kUserId,
      Map<String, dynamic>? metadata,
    }) {
      return json.encode({
        'event_id': eventId,
        'event_type': eventType,
        'user_id': userId,
        'timestamp': '2026-10-20T09:00:00Z',
        'metadata': metadata ?? {'count': 3},
      });
    }

    FileCrossAppRewardService createService({
      required String boxName,
      List<String>? additionalFilePaths,
    }) {
      return FileCrossAppRewardService(
        filePath: tsundokuPath,
        hiveBoxName: boxName,
        additionalFilePaths: additionalFilePaths ?? [bookReviewPath],
      );
    }

    test('既定の追加読み取り先に book-review の JSONL が含まれる', () {
      const service = FileCrossAppRewardService();
      expect(
        service.additionalFilePaths,
        contains(FileCrossAppRewardService.kDefaultBookReviewEventsPath),
      );
      expect(
        service.additionalFilePaths,
        contains('/data/local/tmp/takamagahara_shared/'
            'book_review_reward_events.jsonl'),
      );
    });

    test('既定の追加読み取り先に election の JSONL も維持されている', () {
      const service = FileCrossAppRewardService();
      expect(
        service.additionalFilePaths,
        contains(FileCrossAppRewardService.kDefaultElectionEventsPath),
      );
    });

    test('book ファイルの実バイト行が読み取られ報酬へ変換される', () async {
      File(bookReviewPath)
          .writeAsStringSync('${bookReviewLine(eventId: 'brv-evt-001')}\n');

      final rewards = await createService(boxName: 'cross_app_rewards_brv')
          .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 50);
      expect(rewards[0].exp, 200);
      // metadata.count = 3 により threshold 1 の称号のみ付与される
      expect(rewards[0].titles, contains('読書家の卵'));
      expect(rewards[0].titles, isNot(contains('書庫の冒険者')));
      expect(rewards[0].titles.length, 1);
    });

    test('metadata.count が閾値に届けば上位称号も付く', () async {
      File(bookReviewPath).writeAsStringSync(
        '${bookReviewLine(eventId: 'brv-evt-002', metadata: {'count': 5})}\n',
      );

      final rewards = await createService(boxName: 'cross_app_rewards_brv_5')
          .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].titles, containsAll(<String>['読書家の卵', '書庫の冒険者']));
    });

    test('user_id が不一致の行は無視される', () async {
      File(bookReviewPath).writeAsStringSync(
        '${bookReviewLine(eventId: 'brv-evt-003', userId: 'other999-xxxx')}\n'
        '${bookReviewLine(eventId: 'brv-evt-004')}\n',
      );

      final rewards = await createService(boxName: 'cross_app_rewards_brv_user')
          .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 50);
    });

    test('metadata.count が double の行は捨てられる（現行仕様の回帰固定）', () async {
      // 契約の脆さを可視化する試練: _computeReward は `as int?` で読むため
      // double を渡すと TypeError となり、行ごとスキップされる。
      File(bookReviewPath).writeAsStringSync(
        '${bookReviewLine(eventId: 'brv-evt-005', metadata: {'count': 2.0})}\n',
      );

      final rewards =
          await createService(boxName: 'cross_app_rewards_brv_double')
              .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards, isEmpty);
    });

    test('int の count=2 は読める（double との非対称性の証拠）', () async {
      File(bookReviewPath).writeAsStringSync(
        '${bookReviewLine(eventId: 'brv-evt-006', metadata: {'count': 2})}\n',
      );

      final rewards =
          await createService(boxName: 'cross_app_rewards_brv_int')
              .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 50);
      expect(rewards[0].titles, contains('読書家の卵'));
    });

    test('book ファイルの同一 event_id は再付与されない', () async {
      File(bookReviewPath)
          .writeAsStringSync('${bookReviewLine(eventId: 'brv-evt-007')}\n');

      final service = createService(boxName: 'cross_app_rewards_brv_idem');
      final first = await service.processPendingEvents(
          linkedUserId: kLinkedUser);
      final second = await service.processPendingEvents(
          linkedUserId: kLinkedUser);

      expect(first.length, 1);
      expect(second, isEmpty);
    });

    test('book の閾値は book_completed の称号定義に紐づく', () {
      final ids = getMatchingCrossAppTitles('book_completed', 3)
          .map((t) => t.id)
          .toList();
      expect(ids, contains('読書家の卵'));
      expect(ids, isNot(contains('書庫の冒険者')));
    });
  });
}
