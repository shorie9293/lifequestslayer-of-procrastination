// 敵討伐イベントの純粋関数試練（契約 v1）。
//
// DateTime.now を内部で呼ばない純粋関数として、ランク正規化・スキーマ生成・
// 1行JSONエンコード・UTC ISO8601整形を検証する。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rpg_todo/features/crossapp/domain/enemy_defeat_event.dart';

void main() {
  group('normalizeQuestRank', () {
    test('S/A/B はそのまま通る', () {
      expect(normalizeQuestRank('S'), 'S');
      expect(normalizeQuestRank('A'), 'A');
      expect(normalizeQuestRank('B'), 'B');
    });

    test('小文字は大文字に正規化される', () {
      expect(normalizeQuestRank('s'), 'S');
      expect(normalizeQuestRank('a'), 'A');
      expect(normalizeQuestRank('b'), 'B');
    });

    test('前後の空白は trim される', () {
      expect(normalizeQuestRank('  a '), 'A');
      expect(normalizeQuestRank('\tS\n'), 'S');
    });

    test('未知のランクは B に落ちる', () {
      expect(normalizeQuestRank('C'), 'B');
      expect(normalizeQuestRank('SS'), 'B');
      expect(normalizeQuestRank('1'), 'B');
    });

    test('空文字は B に落ちる', () {
      expect(normalizeQuestRank(''), 'B');
      expect(normalizeQuestRank('   '), 'B');
    });
  });

  group('buildEnemyDefeatEvent', () {
    test('契約スキーマのキーを固定順で持つ', () {
      final event = buildEnemyDefeatEvent(
        taskTitle: 'スライム討伐',
        questRank: 'a',
        baseExp: 300,
        timestamp: '2026-08-24T00:00:00.000Z',
      );

      expect(event.keys.toList(),
          ['event', 'taskTitle', 'questRank', 'baseExp', 'timestamp']);
      expect(event['event'], 'enemy_defeated');
      expect(event['taskTitle'], 'スライム討伐');
      expect(event['questRank'], 'A');
      expect(event['baseExp'], 300);
      expect(event['timestamp'], '2026-08-24T00:00:00.000Z');
    });

    test('未知ランクは B に正規化される', () {
      final event = buildEnemyDefeatEvent(
        taskTitle: '謎の敵',
        questRank: 'Z',
        baseExp: 10,
        timestamp: '2026-08-24T00:00:00.000Z',
      );
      expect(event['questRank'], 'B');
    });

    test('baseExp の負値は 0 にクランプされる', () {
      final event = buildEnemyDefeatEvent(
        taskTitle: '呪いの敵',
        questRank: 'S',
        baseExp: -50,
        timestamp: '2026-08-24T00:00:00.000Z',
      );
      expect(event['baseExp'], 0);
    });

    test('baseExp の 0 はそのまま 0', () {
      final event = buildEnemyDefeatEvent(
        taskTitle: '無価値の敵',
        questRank: 'B',
        baseExp: 0,
        timestamp: '2026-08-24T00:00:00.000Z',
      );
      expect(event['baseExp'], 0);
    });
  });

  group('encodeEventLine', () {
    test('改行を含まないコンパクト1行JSONを返す', () {
      final line = encodeEventLine(buildEnemyDefeatEvent(
        taskTitle: '改行\n入りタイトル',
        questRank: 'B',
        baseExp: 100,
        timestamp: '2026-08-24T00:00:00.000Z',
      ));

      expect(line.contains('\n'), isFalse);
      expect(line.contains('\r'), isFalse);
      final decoded = jsonDecode(line) as Map<String, dynamic>;
      expect(decoded['event'], 'enemy_defeated');
      // タイトル内の改行はJSONエスケープされ、値としては保持される
      expect(decoded['taskTitle'], '改行\n入りタイトル');
    });

    test('前後に空白を含まない', () {
      final line = encodeEventLine(buildEnemyDefeatEvent(
        taskTitle: 'x',
        questRank: 'B',
        baseExp: 1,
        timestamp: '2026-08-24T00:00:00.000Z',
      ));
      expect(line, equals(line.trim()));
    });
  });

  group('formatTimestamp', () {
    test('UTC の ISO8601 文字列に整形する', () {
      final ts = formatTimestamp(DateTime.utc(2026, 8, 24, 1, 2, 3));
      expect(ts, '2026-08-24T01:02:03.000Z');
      expect(DateTime.parse(ts).isUtc, isTrue);
    });

    test('ローカル時刻は UTC に変換される', () {
      final local = DateTime(2026, 8, 24, 10, 30);
      final ts = formatTimestamp(local);
      expect(ts.endsWith('Z'), isTrue);
      expect(DateTime.parse(ts), local.toUtc());
    });
  });
}
