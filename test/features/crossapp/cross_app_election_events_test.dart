import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/crossapp/data/cross_app_reward_service.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_reward_event.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_collection.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';

/// election-game（選挙ゲーム）が書き出す election_reward_events.jsonl を
/// rpg-task が読み取り、報酬・称号へ変換できることを検める試練。
///
/// 凍結済み契約 v1:
///   event_type: election_completed | quiz_completed
///   election_completed.metadata: {wins, won, vote_share, scale, election_id}
///   quiz_completed.metadata:     {correct_count, total, passed}
void main() {
  const kLinkedUser = 'test1234';
  const kUserId = 'test1234-5678-90ab-cdef-1234567890ab';

  group('契約 v1: election イベント種別の登録', () {
    test('knownEventTypes に election_completed / quiz_completed が含まれる', () {
      expect(
          CrossAppRewardEvent.knownEventTypes, contains('election_completed'));
      expect(CrossAppRewardEvent.knownEventTypes, contains('quiz_completed'));
    });

    test('既存7種のイベントタイプは維持されている', () {
      for (final legacy in const [
        'book_completed',
        'reading_streak',
        'level_up',
        'xp_milestone',
        'trophy_written',
        'daily_mission_complete',
        'pages_milestone',
      ]) {
        expect(CrossAppRewardEvent.knownEventTypes, contains(legacy),
            reason: '$legacy が消えている');
      }
    });

    test('election_completed のコイン/EXP は 120/400', () {
      expect(kCrossAppCoinRewards['election_completed'], 120);
      expect(kCrossAppExpRewards['election_completed'], 400);
    });

    test('quiz_completed のコイン/EXP は 60/150', () {
      expect(kCrossAppCoinRewards['quiz_completed'], 60);
      expect(kCrossAppExpRewards['quiz_completed'], 150);
    });

    test('既存7種の報酬額は不変', () {
      expect(kCrossAppCoinRewards['book_completed'], 50);
      expect(kCrossAppCoinRewards['level_up'], 100);
      expect(kCrossAppExpRewards['level_up'], 500);
      expect(kCrossAppCoinRewards['pages_milestone'], 70);
      expect(kCrossAppExpRewards['pages_milestone'], 200);
    });
  });

  group('契約 v1: election 系称号の閾値', () {
    test('election_completed は wins=1 で初当選', () {
      final ids = getMatchingCrossAppTitles('election_completed', 1)
          .map((t) => t.id)
          .toList();
      expect(ids, contains('初当選'));
      expect(ids.length, 1);
    });

    test('election_completed は wins=3 で三選も付く', () {
      final ids = getMatchingCrossAppTitles('election_completed', 3)
          .map((t) => t.id)
          .toList();
      expect(ids, contains('初当選'));
      expect(ids, contains('三選'));
    });

    test('quiz_completed は correct_count=8 で八問正解、10 で満点', () {
      final ids8 = getMatchingCrossAppTitles('quiz_completed', 8)
          .map((t) => t.id)
          .toList();
      expect(ids8.length, 1);

      final ids10 = getMatchingCrossAppTitles('quiz_completed', 10)
          .map((t) => t.id)
          .toList();
      expect(ids10.length, 2);
    });

    test('閾値未満では election 系称号が付かない', () {
      expect(getMatchingCrossAppTitles('election_completed', 0), isEmpty);
      expect(getMatchingCrossAppTitles('quiz_completed', 7), isEmpty);
    });

    test('図鑑の条件ラベルが election/quiz でも意味を持つ', () {
      const electionEntry = CrossAppTitleEntry(
        definition: CrossAppTitleDefinition(
          id: '初当選',
          eventType: 'election_completed',
          threshold: 1,
        ),
        isEarned: false,
      );
      expect(electionEntry.eventTypeLabel, '当選回数');
      expect(electionEntry.conditionLabel, '当選 1回');

      const quizEntry = CrossAppTitleEntry(
        definition: CrossAppTitleDefinition(
          id: '八問正解の士',
          eventType: 'quiz_completed',
          threshold: 8,
        ),
        isEarned: false,
      );
      expect(quizEntry.eventTypeLabel, 'クイズ正解数');
      expect(quizEntry.conditionLabel, '正解 8問');
    });

    test('既存称号11種は件数・IDともに維持されている', () {
      for (final legacyId in const [
        '読書家の卵',
        '書庫の冒険者',
        '知の探究者',
        '千巻の賢者',
        '読書の継続者',
        '日々の読書人',
        '不滅の読書家',
        '知識の探求者',
        '知の航海者',
        'ページを征く者',
        '万頁の読破者',
      ]) {
        expect(kCrossAppTitles.map((t) => t.id), contains(legacyId));
      }
    });
  });

  group('FileCrossAppRewardService: election JSONL の読み取り', () {
    late Directory tempDir;
    late String tsundokuPath;
    late String electionPath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('crossapp_election_');
      tsundokuPath = '${tempDir.path}/tsundoku_reward_events.jsonl';
      electionPath = '${tempDir.path}/election_reward_events.jsonl';
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    String electionLine({
      required String eventId,
      String eventType = 'election_completed',
      Map<String, dynamic>? metadata,
    }) {
      return json.encode({
        'event_id': eventId,
        'event_type': eventType,
        'user_id': kUserId,
        'timestamp': '2026-10-20T09:00:00Z',
        'metadata': metadata ??
            {
              'wins': 1,
              'won': true,
              'vote_share': 62,
              'scale': 'city',
              'election_id': 'el-001',
            },
      });
    }

    FileCrossAppRewardService createService({
      String boxName = 'cross_app_rewards_election',
      List<String>? additionalFilePaths,
    }) {
      return FileCrossAppRewardService(
        filePath: tsundokuPath,
        hiveBoxName: boxName,
        additionalFilePaths: additionalFilePaths ?? [electionPath],
      );
    }

    test('既定の追加読み取り先に election の JSONL が含まれる', () {
      const service = FileCrossAppRewardService();
      expect(
        service.additionalFilePaths,
        contains(
            '/data/local/tmp/takamagahara_shared/election_reward_events.jsonl'),
      );
    });

    test('election ファイルの実バイト行が読み取られ報酬へ変換される', () async {
      File(electionPath)
          .writeAsStringSync('${electionLine(eventId: 'el-evt-001')}\n');

      final rewards =
          await createService().processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 120);
      expect(rewards[0].exp, 400);
      expect(rewards[0].titles, contains('初当選'));
    });

    test('quiz_completed は correct_count で称号判定される', () async {
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'quiz-001', eventType: 'quiz_completed', metadata: {
              'correct_count': 8,
              'total': 10,
              'passed': true,
            })}\n',
      );

      final rewards = await createService(boxName: 'cross_app_rewards_quiz')
          .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 60);
      expect(rewards[0].exp, 150);
      expect(rewards[0].titles.length, 1);
    });

    test('quiz_completed で correct_count 欠落時は 0 として扱う（称号なし）', () async {
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'quiz-002', eventType: 'quiz_completed', metadata: {
              'total': 10,
              'passed': false,
            })}\n',
      );

      final rewards =
          await createService(boxName: 'cross_app_rewards_quiz_missing')
              .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 60);
      expect(rewards[0].titles, isEmpty);
    });

    test('election_completed で wins 欠落時は 1 として扱う（初当選）', () async {
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'el-evt-002', metadata: {'won': true})}\n',
      );

      final rewards =
          await createService(boxName: 'cross_app_rewards_wins_missing')
              .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].titles, contains('初当選'));
    });

    test('未知のイベント型は報酬0（付与なし）', () async {
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'unknown-001', eventType: 'referendum_started')}\n',
      );

      final rewards = await createService(boxName: 'cross_app_rewards_unknown')
          .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards, isEmpty);
    });

    test('両ファイルのイベントが1回の走査で処理される', () async {
      File(tsundokuPath).writeAsStringSync(
        '${json.encode({
              'event_id': 'tsu-001',
              'event_type': 'book_completed',
              'timestamp': '2026-10-20T09:00:00Z',
              'user_id': kUserId,
              'metadata': {'count': 1},
            })}\n',
      );
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'el-evt-003')}\n',
      );

      final rewards =
          await createService(boxName: 'cross_app_rewards_both_files')
              .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 2);
      final coins = rewards.map((r) => r.coins).toList();
      expect(coins, containsAll(<int>[50, 120]));
    });

    test('両ファイルに同一 event_id があっても二重付与しない', () async {
      File(tsundokuPath).writeAsStringSync(
        '${electionLine(eventId: 'dup-001')}\n',
      );
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'dup-001')}\n',
      );

      final rewards =
          await createService(boxName: 'cross_app_rewards_dup_across')
              .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 120);
    });

    test('同一 event_id は2回目の走査で再付与されない（追加ファイル経由）', () async {
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'el-evt-004')}\n',
      );

      final service = createService(boxName: 'cross_app_rewards_idem_add');
      final first =
          await service.processPendingEvents(linkedUserId: kLinkedUser);
      final second =
          await service.processPendingEvents(linkedUserId: kLinkedUser);

      expect(first.length, 1);
      expect(second, isEmpty);
    });

    test('追加ファイルが存在しなくても既存ファイルの処理は継続する', () async {
      File(tsundokuPath).writeAsStringSync(
        '${json.encode({
              'event_id': 'tsu-002',
              'event_type': 'book_completed',
              'timestamp': '2026-10-20T09:00:00Z',
              'user_id': kUserId,
              'metadata': {'count': 1},
            })}\n',
      );
      // electionPath は作らない

      final rewards =
          await createService(boxName: 'cross_app_rewards_missing_add')
              .processPendingEvents(linkedUserId: kLinkedUser);

      expect(rewards.length, 1);
      expect(rewards[0].coins, 50);
    });

    test('後方互換: additionalFilePaths を明示しなければ election は読まない', () async {
      File(electionPath).writeAsStringSync(
        '${electionLine(eventId: 'el-evt-005')}\n',
      );

      final service = FileCrossAppRewardService(
        filePath: tsundokuPath,
        hiveBoxName: 'cross_app_rewards_legacy',
        additionalFilePaths: const [],
      );
      final rewards =
          await service.processPendingEvents(linkedUserId: kLinkedUser);
      expect(rewards, isEmpty);
    });
  });
}
