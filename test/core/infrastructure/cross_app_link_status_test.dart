// 現世間の受け渡し状態（純粋層）の試練。
//
// 表示文言と保存形式は同じ型から導く。壊れた保存値で落ちないことが本質。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/core/infrastructure/cross_app_link_status.dart';

void main() {
  group('CrossAppTransferRecord', () {
    test('toJson → tryFromJson で往復する', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12, 33),
        ok: true,
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
      );

      final restored = CrossAppTransferRecord.tryFromJson(record.toJson());

      expect(restored, isNotNull);
      expect(restored!.at, record.at);
      expect(restored.ok, isTrue);
      expect(restored.count, 3);
      expect(restored.fileName, 'tsundoku_reward_events.jsonl');
      expect(restored.error, isNull);
    });

    test('失敗理由も往復する', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 0),
        ok: false,
        count: 0,
        fileName: 'kozuchi_quest.json',
        error: 'SharedStorageException(write, kozuchi_quest.json): denied',
      );

      final restored = CrossAppTransferRecord.tryFromJson(record.toJson());

      expect(restored!.ok, isFalse);
      expect(restored.count, 0);
      expect(restored.error, contains('denied'));
    });

    test('tryFromJson は Map 以外・at 欠落・at 不正で null', () {
      expect(CrossAppTransferRecord.tryFromJson(null), isNull);
      expect(CrossAppTransferRecord.tryFromJson('not a map'), isNull);
      expect(CrossAppTransferRecord.tryFromJson(<Object?>[]), isNull);
      expect(CrossAppTransferRecord.tryFromJson(<String, Object?>{}), isNull);
      expect(
        CrossAppTransferRecord.tryFromJson(<String, Object?>{
          'at': 'not-a-date',
          'ok': true,
        }),
        isNull,
      );
      expect(
        CrossAppTransferRecord.tryFromJson(<String, Object?>{'at': 42}),
        isNull,
      );
    });

    test('tryFromJson は型違いを既定値に丸める（throw しない）', () {
      final restored = CrossAppTransferRecord.tryFromJson(<String, Object?>{
        'at': '2026-11-11T09:00:00.000',
        'ok': 'true',
        'count': 2.0,
        'file': 123,
        'error': <String>[],
      });

      expect(restored, isNotNull);
      expect(restored!.ok, isFalse);
      expect(restored.count, 2);
      expect(restored.fileName, isNull);
      expect(restored.error, isNull);
    });
  });

  group('CrossAppLinkSnapshot', () {
    test('encode → decode で往復する', () {
      final snapshot = CrossAppLinkSnapshot(
        lastSent: CrossAppTransferRecord(
          at: DateTime(2026, 11, 11, 9, 12),
          ok: true,
          count: 1,
          fileName: 'rpg_enemy_defeat_events.jsonl',
        ),
        lastReceived: CrossAppTransferRecord(
          at: DateTime(2026, 11, 11, 8, 0),
          ok: false,
          count: 0,
          error: 'boom',
        ),
        sharedFolderReady: true,
      );

      final restored = CrossAppLinkSnapshot.decode(snapshot.encode());

      expect(restored.sharedFolderReady, isTrue);
      expect(restored.lastSent!.fileName, 'rpg_enemy_defeat_events.jsonl');
      expect(restored.lastReceived!.ok, isFalse);
      expect(restored.lastReceived!.error, 'boom');
    });

    test('decode は壊れたJSONで empty を返す（throw しない）', () {
      expect(CrossAppLinkSnapshot.decode('{oops').lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('{oops').sharedFolderReady, isFalse);
      expect(CrossAppLinkSnapshot.decode('[1,2,3]').lastSent, isNull);
    });

    test('decode は null / 空文字で empty を返す', () {
      expect(CrossAppLinkSnapshot.decode(null).lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('').lastSent, isNull);
      expect(CrossAppLinkSnapshot.decode('   ').lastSent, isNull);
    });

    test('decode は型違いの入れ子を捨てて残りを読む', () {
      final raw = jsonEncode(<String, Object?>{
        'sharedFolderReady': 'yes',
        'lastSent': 'broken',
        'lastReceived': <String, Object?>{
          'at': '2026-11-11T09:00:00.000',
          'ok': true,
          'count': 5,
          'file': 'a.jsonl',
        },
      });

      final restored = CrossAppLinkSnapshot.decode(raw);

      expect(restored.sharedFolderReady, isFalse);
      expect(restored.lastSent, isNull);
      expect(restored.lastReceived!.count, 5);
    });

    test('copyWith は null 指定で既存を保持する', () {
      final snapshot = CrossAppLinkSnapshot(
        lastSent: CrossAppTransferRecord(
          at: DateTime(2026, 11, 11, 9),
          ok: true,
          count: 1,
        ),
        sharedFolderReady: true,
      );

      final copied = snapshot.copyWith(sharedFolderReady: false);

      expect(copied.lastSent!.count, 1);
      expect(copied.sharedFolderReady, isFalse);
    });
  });

  group('CrossAppLinkStatusText', () {
    test('未記録は「未記録」', () {
      expect(CrossAppLinkStatusText.time(null), '未記録');
      expect(CrossAppLinkStatusText.outcome(null), '未記録');
      expect(CrossAppLinkStatusText.row(null), '未記録');
    });

    test('時刻は 2026/11/11 09:05 形式（2桁ゼロ詰め）', () {
      expect(
        CrossAppLinkStatusText.time(DateTime(2026, 11, 11, 9, 5)),
        '2026/11/11 09:05',
      );
    });

    test('成否は「成功」「失敗」', () {
      final ok = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9),
        ok: true,
        count: 1,
      );
      final ng = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9),
        ok: false,
        count: 0,
        error: 'x',
      );

      expect(CrossAppLinkStatusText.outcome(ok), '成功');
      expect(CrossAppLinkStatusText.outcome(ng), '失敗');
    });

    test('行表示は 成否・時刻・件数・ファイル名 を並べる', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12),
        ok: true,
        count: 3,
        fileName: 'tsundoku_reward_events.jsonl',
      );

      expect(
        CrossAppLinkStatusText.row(record),
        '成功・2026/11/11 09:12・3件・tsundoku_reward_events.jsonl',
      );
    });

    test('ファイル名が無ければ行に含めない', () {
      final record = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9, 12),
        ok: false,
        count: 0,
      );

      expect(CrossAppLinkStatusText.row(record), '失敗・2026/11/11 09:12・0件');
    });

    test('フォルダ状態の文言', () {
      expect(CrossAppLinkStatusText.folder(true), '設定済み');
      expect(CrossAppLinkStatusText.folder(false), contains('未設定'));
    });

    test('失敗理由は成功時は空・長文は切り詰める', () {
      final ok = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9),
        ok: true,
        count: 1,
      );
      final long = CrossAppTransferRecord(
        at: DateTime(2026, 11, 11, 9),
        ok: false,
        count: 0,
        error: 'x' * 400,
      );

      expect(CrossAppLinkStatusText.detail(ok), isEmpty);
      expect(CrossAppLinkStatusText.detail(null), isEmpty);
      final detail = CrossAppLinkStatusText.detail(long);
      expect(detail.length, lessThanOrEqualTo(161));
      expect(detail.endsWith('…'), isTrue);
    });

    test('countLines は行数を数える（空・null は 0）', () {
      expect(CrossAppLinkStatusText.countLines(null), 0);
      expect(CrossAppLinkStatusText.countLines(''), 0);
      expect(CrossAppLinkStatusText.countLines('  \n '), 0);
      expect(CrossAppLinkStatusText.countLines('{"a":1}'), 1);
      expect(CrossAppLinkStatusText.countLines('a\nb\nc\n'), 3);
      expect(CrossAppLinkStatusText.countLines('a\r\nb'), 2);
    });
  });
}
