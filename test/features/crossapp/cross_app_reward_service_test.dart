import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:rpg_todo/features/crossapp/data/cross_app_reward_service.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_reward_event.dart';
import 'package:rpg_todo/features/crossapp/domain/cross_app_title_definition.dart';

void main() {
  group('CrossAppRewardEvent', () {
    test('有効なJSONから正しくパースされる', () {
      final jsonStr = json.encode({
        'event_id': '550e8400-e29b-41d4-a716-446655440000',
        'event_type': 'book_completed',
        'timestamp': '2026-06-07T10:30:00Z',
        'user_id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        'metadata': {'count': 5, 'book_title': 'ドメイン駆動設計'},
      });

      final event = CrossAppRewardEvent.parseLine(jsonStr);

      expect(event.eventId, '550e8400-e29b-41d4-a716-446655440000');
      expect(event.eventType, 'book_completed');
      expect(event.userId, 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      expect(event.metadata['count'], 5);
    });

    test('event_id 欠落で FormatException', () {
      final jsonStr = json.encode({
        'event_type': 'book_completed',
        'timestamp': '2026-06-07T10:30:00Z',
        'user_id': 'a1b2c3d4',
      });

      expect(
        () => CrossAppRewardEvent.parseLine(jsonStr),
        throwsA(isA<FormatException>()),
      );
    });

    test('event_type 欠落で FormatException', () {
      final jsonStr = json.encode({
        'event_id': '550e8400-e29b-41d4-a716-446655440000',
        'timestamp': '2026-06-07T10:30:00Z',
        'user_id': 'a1b2c3d4',
      });

      expect(
        () => CrossAppRewardEvent.parseLine(jsonStr),
        throwsA(isA<FormatException>()),
      );
    });

    test('timestamp 欠落で FormatException', () {
      final jsonStr = json.encode({
        'event_id': '550e8400-e29b-41d4-a716-446655440000',
        'event_type': 'book_completed',
        'user_id': 'a1b2c3d4',
      });

      expect(
        () => CrossAppRewardEvent.parseLine(jsonStr),
        throwsA(isA<FormatException>()),
      );
    });

    test('user_id 欠落で FormatException', () {
      final jsonStr = json.encode({
        'event_id': '550e8400-e29b-41d4-a716-446655440000',
        'event_type': 'book_completed',
        'timestamp': '2026-06-07T10:30:00Z',
      });

      expect(
        () => CrossAppRewardEvent.parseLine(jsonStr),
        throwsA(isA<FormatException>()),
      );
    });

    test('壊れたJSONで FormatException', () {
      expect(
        () => CrossAppRewardEvent.parseLine('{broken json!!!!'),
        throwsA(isA<FormatException>()),
      );
    });

    test('空行で FormatException', () {
      expect(
        () => CrossAppRewardEvent.parseLine(''),
        throwsA(isA<FormatException>()),
      );
    });

    test('空白行で FormatException', () {
      expect(
        () => CrossAppRewardEvent.parseLine('   '),
        throwsA(isA<FormatException>()),
      );
    });

    test('全既知イベントタイプをパースできる', () {
      for (final eventType in CrossAppRewardEvent.knownEventTypes) {
        final jsonStr = json.encode({
          'event_id': '550e8400-e29b-41d4-a716-446655440000',
          'event_type': eventType,
          'timestamp': '2026-06-07T10:30:00Z',
          'user_id': 'a1b2c3d4',
          'metadata': {},
        });

        final event = CrossAppRewardEvent.parseLine(jsonStr);
        expect(event.eventType, eventType);
      }
    });
  });

  group('CrossAppTitleDefinition', () {
    test('11のクロスアプリ称号が定義されている', () {
      expect(kCrossAppTitles.length, 11);
    });

    test('全称号のIDがユニークである', () {
      final ids = kCrossAppTitles.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('book_completed の称号マッチング', () {
      // count=1 → 読書家の卵 のみ
      final titles1 = getMatchingCrossAppTitles('book_completed', 1);
      expect(titles1.map((t) => t.id).toList(), ['読書家の卵']);

      // count=5 → 読書家の卵 + 書庫の冒険者
      final titles5 = getMatchingCrossAppTitles('book_completed', 5);
      final ids5 = titles5.map((t) => t.id).toList();
      expect(ids5.contains('読書家の卵'), true);
      expect(ids5.contains('書庫の冒険者'), true);

      // count=50 → 4つすべて
      final titles50 = getMatchingCrossAppTitles('book_completed', 50);
      expect(titles50.length, 4);
    });

    test('reading_streak の称号マッチング', () {
      final titles7 = getMatchingCrossAppTitles('reading_streak', 7);
      expect(titles7.map((t) => t.id).toList(), ['読書の継続者']);

      final titles100 = getMatchingCrossAppTitles('reading_streak', 100);
      expect(titles100.length, 3);
    });

    test('xp_milestone の称号マッチング', () {
      final titles1000 = getMatchingCrossAppTitles('xp_milestone', 1000);
      expect(titles1000.map((t) => t.id).toList(), ['知識の探求者']);

      final titles10000 = getMatchingCrossAppTitles('xp_milestone', 10000);
      expect(titles10000.length, 2);
    });

    test('pages_milestone の称号マッチング', () {
      final titles1000 = getMatchingCrossAppTitles('pages_milestone', 1000);
      expect(titles1000.map((t) => t.id).toList(), ['ページを征く者']);

      final titles10000 = getMatchingCrossAppTitles('pages_milestone', 10000);
      expect(titles10000.length, 2);
    });

    test('閾値未満では称号がマッチしない', () {
      final titles = getMatchingCrossAppTitles('book_completed', 0);
      expect(titles, isEmpty);
    });

    test('コイン報酬マッピングが全既知イベントタイプをカバー', () {
      for (final eventType in CrossAppRewardEvent.knownEventTypes) {
        expect(kCrossAppCoinRewards.containsKey(eventType), true,
            reason: '$eventType のコイン報酬が未定義');
      }
    });

    test('EXP報酬マッピングが全既知イベントタイプをカバー', () {
      for (final eventType in CrossAppRewardEvent.knownEventTypes) {
        expect(kCrossAppExpRewards.containsKey(eventType), true,
            reason: '$eventType のEXP報酬が未定義');
      }
    });
  });

  group('CrossAppReward', () {
    test('hasReward - 報酬なし', () {
      const reward = CrossAppReward();
      expect(reward.hasReward, false);
    });

    test('hasReward - コインのみ', () {
      const reward = CrossAppReward(coins: 100);
      expect(reward.hasReward, true);
    });

    test('hasReward - 称号のみ', () {
      const reward = CrossAppReward(titles: ['称号A']);
      expect(reward.hasReward, true);
    });

    test('merge - 複数報酬を統合', () {
      const a = CrossAppReward(coins: 50, exp: 100, titles: ['A']);
      const b = CrossAppReward(coins: 30, exp: 50, titles: ['B']);
      final merged = a.merge(b);
      expect(merged.coins, 80);
      expect(merged.exp, 150);
      expect(merged.titles, ['A', 'B']);
    });
  });

  group('FileCrossAppRewardService', () {
    late Directory tempDir;
    late String tempFilePath;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('crossapp_test_');
      tempFilePath = '${tempDir.path}/tsundoku_reward_events.jsonl';

      // Hive の初期化
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<FileCrossAppRewardService> createService() async {
      return FileCrossAppRewardService(
        filePath: tempFilePath,
        hiveBoxName: 'cross_app_rewards_test',
      );
    }

    test('ファイルが存在しない場合 空リストを返す', () async {
      final service = await createService();
      final rewards = await service.processPendingEvents(
        linkedUserId: 'test1234',
      );
      expect(rewards, isEmpty);
    });

    test('有効なJSONLから報酬を正しく処理', () async {
      final line = json.encode({
        'event_id': 'evt-001',
        'event_type': 'book_completed',
        'timestamp': '2026-06-07T10:30:00Z',
        'user_id': 'test1234-5678-90ab-cdef-1234567890ab',
        'metadata': {'count': 5, 'book_title': 'テスト本'},
      });
      await File(tempFilePath).writeAsString('$line\n');

      final service = await createService();
      final rewards = await service.processPendingEvents(
        linkedUserId: 'test1234',
      );

      expect(rewards.length, 1);
      expect(rewards[0].coins, 50); // book_completed = 50
      expect(rewards[0].exp, 200); // book_completed = 200
      // count=5 → 読書家の卵 + 書庫の冒険者
      expect(rewards[0].titles.length, 2);
      expect(rewards[0].titles.contains('読書家の卵'), true);
      expect(rewards[0].titles.contains('書庫の冒険者'), true);
    });

    test('同一 event_id は二度と処理されない（冪等性）', () async {
      final line = json.encode({
        'event_id': 'evt-001',
        'event_type': 'book_completed',
        'timestamp': '2026-06-07T10:30:00Z',
        'user_id': 'test1234-5678-90ab-cdef-1234567890ab',
        'metadata': {'count': 1},
      });
      await File(tempFilePath).writeAsString('$line\n');

      final service = await createService();

      // 1回目: 処理される
      final rewards1 = await service.processPendingEvents(
        linkedUserId: 'test1234',
      );
      expect(rewards1.length, 1);

      // 2回目: 既に処理済みなので空
      final rewards2 = await service.processPendingEvents(
        linkedUserId: 'test1234',
      );
      expect(rewards2, isEmpty);
    });

    test('linkedUserId が null の場合は何も処理しない', () async {
      final line = json.encode({
        'event_id': 'evt-001',
        'event_type': 'book_completed',
        'timestamp': '2026-06-07T10:30:00Z',
        'user_id': 'test1234-5678',
        'metadata': {'count': 1},
      });
      await File(tempFilePath).writeAsString('$line\n');

      final service = await createService();
      final rewards = await service.processPendingEvents(
        linkedUserId: null,
      );
      expect(rewards, isEmpty);
    });

    test('user_id がリンクIDとマッチしない場合はスキップ', () async {
      final line = json.encode({
        'event_id': 'evt-001',
        'event_type': 'book_completed',
        'timestamp': '2026-06-07T10:30:00Z',
        'user_id': 'other9999-5678-90ab-cdef-1234567890ab',
        'metadata': {'count': 1},
      });
      await File(tempFilePath).writeAsString('$line\n');

      final service = await createService();
      final rewards = await service.processPendingEvents(
        linkedUserId: 'test1234',
      );
      expect(rewards, isEmpty);
    });

    test('壊れた行はスキップされて処理が継続される', () async {
      final lines = [
        'invalid json!!!',
        json.encode({
          'event_id': 'evt-001',
          'event_type': 'book_completed',
          'timestamp': '2026-06-07T10:30:00Z',
          'user_id': 'test1234-5678',
          'metadata': {'count': 1},
        }),
      ];
      await File(tempFilePath).writeAsString('${lines.join('\n')}\n');

      final service = await createService();
      final rewards = await service.processPendingEvents(
        linkedUserId: 'test1234',
      );
      // 壊れた行はスキップされ、有効な行だけ処理される
      expect(rewards.length, 1);
    });

    test('複数イベント（同一ユーザー）が正しく処理される', () async {
      final lines = [
        json.encode({
          'event_id': 'evt-001',
          'event_type': 'book_completed',
          'timestamp': '2026-06-07T10:30:00Z',
          'user_id': 'test1234-5678',
          'metadata': {'count': 1},
        }),
        json.encode({
          'event_id': 'evt-002',
          'event_type': 'reading_streak',
          'timestamp': '2026-06-07T10:35:00Z',
          'user_id': 'test1234-5678',
          'metadata': {'streak_days': 7},
        }),
        json.encode({
          'event_id': 'evt-003',
          'event_type': 'daily_mission_complete',
          'timestamp': '2026-06-07T10:40:00Z',
          'user_id': 'test1234-5678',
          'metadata': {},
        }),
      ];
      await File(tempFilePath).writeAsString('${lines.join('\n')}\n');

      final service = await createService();
      final rewards = await service.processPendingEvents(
        linkedUserId: 'test1234',
      );
      expect(rewards.length, 3);

      // 1つ目: book_completed + 称号「読書家の卵」
      expect(rewards[0].coins, 50);
      expect(rewards[0].exp, 200);
      expect(rewards[0].titles.contains('読書家の卵'), true);

      // 2つ目: reading_streak + 称号（streak_days=7 → 読書の継続者）
      expect(rewards[1].coins, 30);
      expect(rewards[1].exp, 100);
      expect(rewards[1].titles.contains('読書の継続者'), true);

      // 3つ目: daily_mission_complete（称号なし）
      expect(rewards[2].coins, 40);
      expect(rewards[2].exp, 150);
      expect(rewards[2].titles, isEmpty);
    });

    test('イベントタイプごとの報酬金額が正しい', () async {
      final expectedCoins = {
        'book_completed': 50,
        'reading_streak': 30,
        'level_up': 100,
        'xp_milestone': 80,
        'trophy_written': 60,
        'daily_mission_complete': 40,
        'pages_milestone': 70,
      };

      final expectedExp = {
        'book_completed': 200,
        'reading_streak': 100,
        'level_up': 500,
        'xp_milestone': 300,
        'trophy_written': 250,
        'daily_mission_complete': 150,
        'pages_milestone': 200,
      };

      for (final eventType in CrossAppRewardEvent.knownEventTypes) {
        final idx = eventType.hashCode.abs();
        final lines = [
          json.encode({
            'event_id': 'evt-$idx',
            'event_type': eventType,
            'timestamp': '2026-06-07T10:30:00Z',
            'user_id': 'test1234-5678',
            'metadata': {},
          }),
        ];
        await File(tempFilePath).writeAsString('${lines.join('\n')}\n');

        // 新しいbox名で毎回異なるboxを使う
        final boxName = 'cross_app_test_$eventType';
        final service = FileCrossAppRewardService(
          filePath: tempFilePath,
          hiveBoxName: boxName,
        );

        final rewards = await service.processPendingEvents(
          linkedUserId: 'test1234',
        );
        expect(rewards.length, 1, reason: '$eventType が処理されなかった');
        expect(rewards[0].coins, expectedCoins[eventType],
            reason: '$eventType のコイン報酬が不一致');
        expect(rewards[0].exp, expectedExp[eventType],
            reason: '$eventType のEXP報酬が不一致');

        // テスト後に box を閉じる
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
        }
      }
    });
  });
}
